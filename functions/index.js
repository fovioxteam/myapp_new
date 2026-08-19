// functions/index.js

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const algoliasearch = require('algoliasearch');
const { defineSecret } = require('firebase-functions/params');

// 🔥 Определяем секрет для Algolia API ключа
const ALGOLIA_ADMIN_KEY_SECRET = defineSecret('ALGOLIA_ADMIN_KEY');

admin.initializeApp();
const db = admin.firestore();

// ============================================
// 🔐 ALGOLIA
// ============================================

const ALGOLIA_APP_ID = "NRFCQ941L8";
let algoliaClient = null;
let postsIndex = null;
let usersIndex = null;

function initAlgolia(adminKey) {
  if (!adminKey) {
    console.log('⚠️ ALGOLIA_ADMIN_KEY not provided');
    return { postsIndex: null, usersIndex: null };
  }
  
  if (algoliaClient) return { postsIndex, usersIndex };
  
  try {
    algoliaClient = algoliasearch(ALGOLIA_APP_ID, adminKey);
    postsIndex = algoliaClient.initIndex("posts");
    usersIndex = algoliaClient.initIndex("users");
    console.log('✅ Algolia client initialized');
  } catch (e) {
    console.error('❌ Algolia init error:', e);
  }
  
  return { postsIndex, usersIndex };
}

// ============================================
// 🔥 HELPER: ПАКЕТНОЕ УДАЛЕНИЕ
// ============================================
async function deleteCollectionInBatches(collectionRef, batchSize = 400) {
  let totalDeleted = 0;
  
  while (true) {
    const snapshot = await collectionRef.limit(batchSize).get();
    if (snapshot.empty) break;
    
    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    totalDeleted += snapshot.size;
    console.log(`   Deleted ${totalDeleted} so far...`);
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  
  return totalDeleted;
}

async function deleteQueryInBatches(query, batchSize = 400) {
  let totalDeleted = 0;
  
  while (true) {
    const snapshot = await query.limit(batchSize).get();
    if (snapshot.empty) break;
    
    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    totalDeleted += snapshot.size;
    console.log(`   Deleted ${totalDeleted} so far...`);
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  
  return totalDeleted;
}

// ============================================
// 🔥 HELPER: ОТПРАВКА PUSH УВЕДОМЛЕНИЯ
// ============================================
async function sendPushNotificationHelper(token, title, body, route, entityId, senderId, senderName, extraData = {}) {
  if (!token) return false;
  
  const deepLink = `foviox://${route}/${entityId}`;
  
  const message = {
    token: token,
    notification: { 
      title: title, 
      body: body 
    },
    data: {
      type: route === 'post' ? 'like' : (route === 'profile' ? 'follow' : 'message'),
      route: route,
      entityId: entityId,
      senderId: senderId || '',
      senderName: senderName || 'User',
      deepLink: deepLink,
      ...extraData,
    },
    android: {
      priority: 'high',
      ttl: 0,
      notification: {
        priority: 'max',
        sound: 'default',
        channelId: 'social_notifications',
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      },
    },
    apns: {
      headers: { 'apns-priority': '10' },
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
        },
      },
    },
  };
  
  try {
    await admin.messaging().send(message);
    console.log(`✅ Push sent to ${token.substring(0, 10)}... for route: ${route}`);
    return true;
  } catch (error) {
    console.error(`❌ Push send error:`, error);
    return false;
  }
}

// ============================================
// 🔥 MARK CHAT AS READ
// ============================================
exports.markChatAsRead = functions
  .runWith({ enforceAppCheck: false })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
    }

    const userId = context.auth.uid;
    const { chatId } = data;
    
    if (!chatId) {
      throw new functions.https.HttpsError('invalid-argument', 'chatId is required');
    }

    console.log(`📖 [CF] markChatAsRead: chatId=${chatId}, userId=${userId}`);

    try {
      const chatRef = db.collection('chats').doc(chatId);
      const chatDoc = await chatRef.get();
      
      if (!chatDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Chat not found');
      }
      
      const chatData = chatDoc.data();
      const participants = chatData.participants || [];
      
      if (!participants.includes(userId)) {
        throw new functions.https.HttpsError('permission-denied', 'User is not a participant');
      }
      
      await chatRef.update({
        [`unreadCount.${userId}`]: 0,
        [`lastRead.${userId}`]: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      const messagesSnapshot = await chatRef
        .collection('messages')
        .where('senderId', '!=', userId)
        .get();
      
      const batch = db.batch();
      
      for (const doc of messagesSnapshot.docs) {
        const messageData = doc.data();
        if (messageData.read !== true) {
          batch.update(doc.ref, {
            'read': true,
            'readAt': admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }
      
      const notificationsSnapshot = await db.collection('notifications')
        .where('userId', '==', userId)
        .where('chatId', '==', chatId)
        .where('isRead', '==', false)
        .get();
      
      for (const doc of notificationsSnapshot.docs) {
        batch.update(doc.ref, { isRead: true });
      }
      
      await batch.commit();
      
      console.log(`✅ [CF] Chat ${chatId} marked as read for user ${userId}`);
      
      return { 
        success: true, 
        message: 'Chat marked as read',
      };
      
    } catch (error) {
      console.error(`❌ [CF] Error marking chat as read: ${error}`);
      throw new functions.https.HttpsError('internal', error.message);
    }
  });

// ============================================
// 🔥 MARK MESSAGE AS READ
// ============================================
exports.markMessageAsRead = functions
  .runWith({ enforceAppCheck: false })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
    }
    
    const userId = context.auth.uid;
    const { chatId, messageId } = data;
    
    if (!chatId || !messageId) {
      throw new functions.https.HttpsError('invalid-argument', 'chatId and messageId are required');
    }
    
    console.log(`📖 [CF] markMessageAsRead: chatId=${chatId}, messageId=${messageId}, userId=${userId}`);
    
    try {
      const chatRef = db.collection('chats').doc(chatId);
      const messageRef = chatRef.collection('messages').doc(messageId);
      
      const messageDoc = await messageRef.get();
      if (!messageDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Message not found');
      }
      
      const messageData = messageDoc.data();
      if (messageData.senderId === userId) {
        console.log(`⏭️ [CF] User marked own message as read, skipping`);
        return { success: true, message: 'Own message' };
      }
      
      await messageRef.update({
        'read': true,
        'readAt': admin.firestore.FieldValue.serverTimestamp(),
      });
      
      const allMessagesSnapshot = await chatRef
        .collection('messages')
        .where('senderId', '!=', userId)
        .get();
      
      let remainingUnread = 0;
      for (const doc of allMessagesSnapshot.docs) {
        if (doc.data().read !== true) {
          remainingUnread++;
        }
      }
      
      if (remainingUnread === 0) {
        await chatRef.update({
          [`unreadCount.${userId}`]: 0,
          [`lastRead.${userId}`]: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else {
        const currentUnread = (await chatRef.get()).data()?.unreadCount?.[userId] || 0;
        await chatRef.update({
          [`unreadCount.${userId}`]: Math.max(0, currentUnread - 1),
        });
      }
      
      console.log(`✅ [CF] Message ${messageId} marked as read`);
      
      return { success: true };
      
    } catch (error) {
      console.error(`❌ [CF] Error marking message as read: ${error}`);
      throw new functions.https.HttpsError('internal', error.message);
    }
  });

// ============================================
// 🔥 CLEAR ALL UNREAD FOR CHAT
// ============================================
exports.clearAllUnreadForChat = functions
  .runWith({ enforceAppCheck: false })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
    }
    
    const userId = context.auth.uid;
    const { chatId } = data;
    
    if (!chatId) {
      throw new functions.https.HttpsError('invalid-argument', 'chatId is required');
    }
    
    console.log(`🧹 [CF] clearAllUnreadForChat: chatId=${chatId}, userId=${userId}`);
    
    try {
      const chatRef = db.collection('chats').doc(chatId);
      
      const messagesSnapshot = await chatRef
        .collection('messages')
        .where('senderId', '!=', userId)
        .get();
      
      const batch = db.batch();
      
      for (const doc of messagesSnapshot.docs) {
        if (doc.data().read !== true) {
          batch.update(doc.ref, {
            'read': true,
            'readAt': admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }
      
      batch.update(chatRef, {
        [`unreadCount.${userId}`]: 0,
        [`lastRead.${userId}`]: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      const notificationsSnapshot = await db.collection('notifications')
        .where('userId', '==', userId)
        .where('chatId', '==', chatId)
        .where('isRead', '==', false)
        .get();
      
      for (const doc of notificationsSnapshot.docs) {
        batch.update(doc.ref, { isRead: true });
      }
      
      await batch.commit();
      
      console.log(`✅ [CF] Cleared unread messages for chat ${chatId}`);
      
      return {
        success: true,
      };
      
    } catch (error) {
      console.error(`❌ [CF] Error clearing unread: ${error}`);
      throw new functions.https.HttpsError('internal', error.message);
    }
  });

// ============================================
// 🔥 SYNC UNREAD COUNT
// ============================================
exports.syncUnreadCount = functions
  .runWith({ enforceAppCheck: false })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
    }
    
    const userId = context.auth.uid;
    const { chatId } = data;
    
    if (!chatId) {
      throw new functions.https.HttpsError('invalid-argument', 'chatId is required');
    }
    
    console.log(`🔄 [CF] syncUnreadCount: chatId=${chatId}, userId=${userId}`);
    
    try {
      const chatRef = db.collection('chats').doc(chatId);
      const chatDoc = await chatRef.get();
      
      if (!chatDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Chat not found');
      }
      
      const chatData = chatDoc.data();
      const firestoreUnread = chatData.unreadCount?.[userId] || 0;
      
      const messagesSnapshot = await chatRef
        .collection('messages')
        .where('senderId', '!=', userId)
        .get();
      
      let actualUnread = 0;
      for (const doc of messagesSnapshot.docs) {
        if (doc.data().read !== true) {
          actualUnread++;
        }
      }
      
      let fixed = false;
      if (firestoreUnread !== actualUnread) {
        console.log(`⚠️ [CF] Unread count mismatch: Firestore=${firestoreUnread}, Actual=${actualUnread}. Fixing...`);
        await chatRef.update({
          [`unreadCount.${userId}`]: actualUnread,
        });
        fixed = true;
      }
      
      return {
        success: true,
        firestoreUnread: firestoreUnread,
        actualUnread: actualUnread,
        fixed: fixed,
      };
      
    } catch (error) {
      console.error(`❌ [CF] Error syncing unread count: ${error}`);
      throw new functions.https.HttpsError('internal', error.message);
    }
  });

// ============================================
// 🔥 GET UNREAD COUNTS
// ============================================
exports.getUnreadCounts = functions
  .runWith({ enforceAppCheck: false })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
    }
    
    const userId = context.auth.uid;
    
    console.log(`📊 [CF] getUnreadCounts called for user: ${userId}`);
    
    try {
      const chatsSnapshot = await db.collection('chats')
        .where('participants', 'array-contains', userId)
        .get();
      
      const unreadCounts = {};
      let total = 0;
      
      for (const doc of chatsSnapshot.docs) {
        const chatData = doc.data();
        const unreadMap = chatData.unreadCount || {};
        const unread = unreadMap[userId] || 0;
        
        if (unread > 0) {
          unreadCounts[doc.id] = unread;
          total += unread;
        }
      }
      
      console.log(`📊 [CF] Found ${Object.keys(unreadCounts).length} chats with unread, total=${total}`);
      
      return {
        success: true,
        unreadCounts: unreadCounts,
        total: total,
      };
      
    } catch (error) {
      console.error(`❌ [CF] Error getting unread counts: ${error}`);
      throw new functions.https.HttpsError('internal', error.message);
    }
  });

// ============================================
// 🔥 GET ALL UNREAD CHATS
// ============================================
exports.getAllUnreadChats = functions
  .runWith({ enforceAppCheck: false })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
    }
    
    const userId = context.auth.uid;
    
    console.log(`📊 [CF] getAllUnreadChats for user: ${userId}`);
    
    try {
      const chatsSnapshot = await db.collection('chats')
        .where('participants', 'array-contains', userId)
        .get();
      
      const unreadChats = [];
      
      for (const doc of chatsSnapshot.docs) {
        const chatData = doc.data();
        const unreadMap = chatData.unreadCount || {};
        const unread = unreadMap[userId] || 0;
        
        if (unread > 0) {
          const otherUserId = chatData.participants.find(p => p !== userId);
          let otherUserData = {};
          
          if (otherUserId) {
            const userDoc = await db.collection('users').doc(otherUserId).get();
            otherUserData = userDoc.data() || {};
          }
          
          unreadChats.push({
            chatId: doc.id,
            unreadCount: unread,
            otherUserId: otherUserId,
            otherUserName: otherUserData.username || 'Unknown',
            otherUserAvatar: otherUserData.avatarUrl || '',
            lastMessage: chatData.lastMessage || '',
            lastMessageTime: chatData.lastMessageTime,
          });
        }
      }
      
      console.log(`📊 [CF] Found ${unreadChats.length} chats with unread messages`);
      
      return {
        success: true,
        unreadChats: unreadChats,
        totalUnread: unreadChats.reduce((sum, chat) => sum + chat.unreadCount, 0),
      };
      
    } catch (error) {
      console.error(`❌ [CF] Error getting unread chats: ${error}`);
      throw new functions.https.HttpsError('internal', error.message);
    }
  });

// ============================================
// 🔥 SEND PUSH NOTIFICATION
// ============================================
exports.sendPushNotification = functions
  .runWith({ enforceAppCheck: false })
  .https.onCall(async (data, context) => {
    console.log("📱 [sendPushNotification] Called");
    
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Not authenticated');
    }
    
    const { userId, title, body, route, entityId, senderId, senderName } = data;
    
    console.log(`📱 [sendPushNotification] To: ${userId}, Title: ${title}`);
    
    if (!userId) {
      throw new functions.https.HttpsError('invalid-argument', 'userId required');
    }
    
    try {
      const userDoc = await db.collection('users').doc(userId).get();
      const fcmToken = userDoc.data()?.fcmToken;
      
      if (!fcmToken) {
        console.log(`⚠️ No FCM token for user ${userId}`);
        return { success: false, error: 'No FCM token' };
      }
      
      const message = {
        token: fcmToken,
        notification: { title: title || 'New message', body: body || '' },
        data: {
          type: route === 'post' ? 'like' : (route === 'profile' ? 'follow' : 'message'),
          route: route || 'chat',
          entityId: entityId || '',
          senderId: senderId || '',
          senderName: senderName || 'User',
          deepLink: `foviox://${route || 'chat'}/${entityId || ''}`,
        },
        android: {
          priority: 'high',
          ttl: 0,
          notification: { 
            priority: 'max',
            sound: 'default', 
            channelId: 'social_notifications',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        apns: {
          headers: { 'apns-priority': '10' },
          payload: { aps: { sound: 'default', badge: 1 } },
        },
      };
      
      await admin.messaging().send(message);
      console.log(`✅ Push sent to ${userId}`);
      return { success: true };
      
    } catch (error) {
      console.error(`❌ Error sending push:`, error);
      throw new functions.https.HttpsError('internal', error.message);
    }
  });

// ============================================
// 🔥 UPDATE FCM TOKEN
// ============================================
exports.updateFCMToken = functions
  .runWith({ enforceAppCheck: false })
  .https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Not authenticated');

    const userId = context.auth.uid;
    const { token, platform } = data;
    if (!token) throw new functions.https.HttpsError('invalid-argument', 'token required');

    await db.collection('users').doc(userId).update({
      fcmToken: token,
      fcmTokenUpdated: admin.firestore.FieldValue.serverTimestamp(),
      fcmTokenPlatform: platform || 'unknown',
    });

    return { success: true };
  });

// ============================================
// 🔥 PUSH NOTIFICATIONS FOR LIKES
// ============================================
exports.onLikeCreated = functions.firestore
  .document('likes/{likeId}')
  .onCreate(async (snap, context) => {
    const likeData = snap.data();
    const postId = likeData.postId;
    const likerId = likeData.userId;
    
    console.log(`❤️ New like on post ${postId} from user ${likerId}`);
    
    try {
      const postDoc = await db.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        console.log(`❌ Post ${postId} not found`);
        return null;
      }
      
      const post = postDoc.data();
      const postOwnerId = post.userId;
      
      if (postOwnerId === likerId) {
        console.log(`⏭️ User liked own post, skipping notification`);
        return null;
      }
      
      const likerDoc = await db.collection('users').doc(likerId).get();
      const likerData = likerDoc.data() || {};
      const likerName = likerData.username || likerData.displayName || 'Someone';
      const likerAvatar = likerData.avatarUrl || '';
      
      const notificationRef = db.collection('notifications').doc();
      await notificationRef.set({
        id: notificationRef.id,
        userId: postOwnerId,
        type: 'like',
        route: 'post',
        entityId: postId,
        senderId: likerId,
        senderName: likerName,
        senderAvatar: likerAvatar,
        postId: postId,
        title: 'New Like',
        body: 'liked your post',
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      const userDoc = await db.collection('users').doc(postOwnerId).get();
      const fcmToken = userDoc.data()?.fcmToken;
      
      if (fcmToken) {
        await sendPushNotificationHelper(
          fcmToken,
          likerName,
          'liked your post',
          'post',
          postId,
          likerId,
          likerName,
          { postId: postId }
        );
      }
      
      console.log(`✅ Like notification processed for post ${postId}`);
      return null;
      
    } catch (error) {
      console.error(`❌ Error in onLikeCreated:`, error);
      return null;
    }
  });

// ============================================
// 🔥 PUSH NOTIFICATIONS FOR COMMENTS
// ============================================
exports.onCommentCreated = functions.firestore
  .document('posts/{postId}/comments/{commentId}')
  .onCreate(async (snap, context) => {
    const commentData = snap.data();
    const postId = context.params.postId;
    const commentId = context.params.commentId;
    const commenterId = commentData.userId;
    const commentText = commentData.text;
    
    console.log(`💬 New comment on post ${postId} from user ${commenterId}: "${commentText}"`);
    
    try {
      const postDoc = await db.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        console.log(`❌ Post ${postId} not found`);
        return null;
      }
      
      const post = postDoc.data();
      const postOwnerId = post.userId;
      const isReply = commentData.replyToCommentId != null;
      const replyToUserId = commentData.replyToUserId;
      
      const commenterDoc = await db.collection('users').doc(commenterId).get();
      const commenterData = commenterDoc.data() || {};
      const commenterName = commenterData.username || commenterData.displayName || 'Someone';
      const commenterAvatar = commenterData.avatarUrl || '';
      
      let targetUserId = postOwnerId;
      let notificationBody = 'commented on your post';
      
      if (isReply && replyToUserId && replyToUserId !== commenterId) {
        targetUserId = replyToUserId;
        notificationBody = `replied to your comment: "${commentText.substring(0, 50)}${commentText.length > 50 ? '...' : ''}"`;
      }
      
      if (targetUserId === commenterId) {
        console.log(`⏭️ User commented on own post/reply, skipping notification`);
        return null;
      }
      
      const notificationRef = db.collection('notifications').doc();
      await notificationRef.set({
        id: notificationRef.id,
        userId: targetUserId,
        type: 'comment',
        route: 'post',
        entityId: postId,
        senderId: commenterId,
        senderName: commenterName,
        senderAvatar: commenterAvatar,
        postId: postId,
        commentId: commentId,
        commentText: commentText,
        isReply: isReply,
        replyToUserId: replyToUserId,
        title: 'New Comment',
        body: notificationBody,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      const userDoc = await db.collection('users').doc(targetUserId).get();
      const fcmToken = userDoc.data()?.fcmToken;
      
      if (fcmToken) {
        await sendPushNotificationHelper(
          fcmToken,
          commenterName,
          notificationBody,
          'post',
          postId,
          commenterId,
          commenterName,
          { postId: postId, commentId: commentId }
        );
      }
      
      console.log(`✅ Comment notification processed for post ${postId}`);
      return null;
      
    } catch (error) {
      console.error(`❌ Error in onCommentCreated:`, error);
      return null;
    }
  });

// ============================================
// 🔥 PUSH NOTIFICATIONS FOR FOLLOWS
// ============================================
exports.onFollowCreated = functions.firestore
  .document('followers/{userId}/userFollowers/{followerId}')
  .onCreate(async (snap, context) => {
    const followedUserId = context.params.userId;
    const followerId = context.params.followerId;
    
    console.log(`👥 New follow: ${followerId} -> ${followedUserId}`);
    
    try {
      if (followedUserId === followerId) {
        console.log(`⏭️ User followed themselves, skipping notification`);
        return null;
      }
      
      const followerDoc = await db.collection('users').doc(followerId).get();
      const followerData = followerDoc.data() || {};
      const followerName = followerData.username || followerData.displayName || 'Someone';
      const followerAvatar = followerData.avatarUrl || '';
      
      const notificationRef = db.collection('notifications').doc();
      await notificationRef.set({
        id: notificationRef.id,
        userId: followedUserId,
        type: 'follow',
        route: 'profile',
        entityId: followerId,
        senderId: followerId,
        senderName: followerName,
        senderAvatar: followerAvatar,
        title: 'New Follower',
        body: 'started following you',
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      const userDoc = await db.collection('users').doc(followedUserId).get();
      const fcmToken = userDoc.data()?.fcmToken;
      
      if (fcmToken) {
        await sendPushNotificationHelper(
          fcmToken,
          followerName,
          'started following you',
          'profile',
          followerId,
          followerId,
          followerName
        );
      }
      
      console.log(`✅ Follow notification processed for user ${followedUserId}`);
      return null;
      
    } catch (error) {
      console.error(`❌ Error in onFollowCreated:`, error);
      return null;
    }
  });

// ============================================
// 🔥 PUSH NOTIFICATIONS FOR MESSAGES
// ============================================
exports.onNewMessage = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const chatId = context.params.chatId;
    const senderId = message.senderId;
    const text = message.text;

    console.log(`📨 New message in chat ${chatId} from user ${senderId}`);

    let senderName = 'User';
    let senderAvatar = '';

    try {
      const senderDoc = await db.collection('users').doc(senderId).get();
      if (senderDoc.exists) {
        const senderData = senderDoc.data();
        senderName = senderData?.username ?? senderData?.displayName ?? 'User';
        senderAvatar = senderData?.avatarUrl ?? '';
      }
    } catch (e) {
      senderName = message.senderName ?? 'User';
    }

    try {
      const chatDoc = await db.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) {
        console.log(`❌ Chat ${chatId} not found`);
        return null;
      }
      
      const chat = chatDoc.data();
      const participants = chat.participants || [];
      
      const updates = {};
      const notifications = [];
      const pushTokens = [];

      for (const userId of participants) {
        if (String(userId) === String(senderId)) continue;
        
        const mutedDoc = await db.collection('users')
          .doc(userId)
          .collection('mutedChats')
          .doc(chatId)
          .get();
        
        const isMuted = mutedDoc.exists;
        
        if (!isMuted) {
          const currentUnread = chat.unreadCount?.[userId] || 0;
          updates[`unreadCount.${userId}`] = currentUnread + 1;

          const notificationRef = db.collection('notifications').doc();
          notifications.push(notificationRef.set({
            id: notificationRef.id,
            userId,
            type: 'message',
            route: 'chat',
            entityId: chatId,
            chatId: chatId,
            senderId,
            senderName,
            senderAvatar,
            messageText: text,
            title: senderName,
            body: text.length > 100 ? text.substring(0, 100) + '...' : text,
            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          }));

          const userDoc = await db.collection('users').doc(userId).get();
          const fcmToken = userDoc.data()?.fcmToken;
          if (fcmToken) {
            pushTokens.push({ token: fcmToken, userId });
          }
        } else {
          console.log(`🔇 User ${userId} has muted chat ${chatId}, skipping notification`);
        }
      }

      if (Object.keys(updates).length > 0) {
        await db.collection('chats').doc(chatId).update({
          ...updates,
          lastMessage: text,
          lastMessageTime: admin.firestore.FieldValue.serverTimestamp(),
          lastMessageSenderId: senderId,
          lastMessageSenderName: senderName,
          lastMessageId: snap.id,
        });
      }

      await Promise.all(notifications);

      for (const { token, userId } of pushTokens) {
        await sendPushNotificationHelper(
          token,
          senderName,
          text.length > 100 ? text.substring(0, 100) + '...' : text,
          'chat',
          chatId,
          senderId,
          senderName,
          { chatId: chatId }
        );
      }

      console.log(`✅ Message ${snap.id} processed, sent to ${pushTokens.length} recipients`);
      return null;
      
    } catch (error) {
      console.error(`❌ Error in onNewMessage:`, error);
      return null;
    }
  });

// ============================================
// 🔥 DELETE USER ACCOUNT
// ============================================
exports.deleteUserAccount = functions
  .runWith({ 
    enforceAppCheck: false, 
    timeoutSeconds: 540,
    memory: '1GB',
    secrets: [ALGOLIA_ADMIN_KEY_SECRET]
  })
  .https.onCall(async (data, context) => {
    const userId = data.userId;
    
    console.log(`\n🗑️ ========== STARTING COMPLETE DELETE for user: ${userId} ==========\n`);
    
    if (!userId) {
      throw new functions.https.HttpsError('invalid-argument', 'User ID required');
    }
    
    const algoliaKey = ALGOLIA_ADMIN_KEY_SECRET.value();
    console.log(`🔑 Algolia key present: ${!!algoliaKey}`);
    
    const results = {
      likes: 0,
      following: 0,
      followers: 0,
      followsCleaned: 0,
      subcollections: 0,
      posts: 0,
      postComments: 0,
      chats: 0,
      messages: 0,
      notifications: 0,
      algolia: false,
      userDoc: false
    };
    
    // 1. Удаляем лайки
    try {
      const likesQuery = db.collection('likes').where('userId', '==', userId);
      results.likes = await deleteQueryInBatches(likesQuery, 400);
      console.log(`✅ Deleted ${results.likes} likes`);
    } catch (e) {
      console.log(`⚠️ Error deleting likes: ${e.message}`);
    }
    
    // 2. Сохраняем списки подписок
    let userFollowingList = [];
    let userFollowersList = [];
    
    try {
      const followingSnapshot = await db.collection('following').doc(userId).collection('userFollowing').get();
      userFollowingList = followingSnapshot.docs.map(doc => doc.id);
      console.log(`📊 User is following ${userFollowingList.length} users`);
      
      const followersSnapshot = await db.collection('followers').doc(userId).collection('userFollowers').get();
      userFollowersList = followersSnapshot.docs.map(doc => doc.id);
      console.log(`📊 User has ${userFollowersList.length} followers`);
    } catch (e) {
      console.log(`⚠️ Error saving follow lists: ${e.message}`);
    }
    
    // 3. Удаляем подписки
    try {
      const followingRef = db.collection('following').doc(userId).collection('userFollowing');
      results.following = await deleteCollectionInBatches(followingRef, 400);
      console.log(`✅ Deleted ${results.following} following entries`);
    } catch (e) {
      console.log(`⚠️ Error deleting following: ${e.message}`);
    }
    
    // 4. Удаляем подписчиков
    try {
      const followersRef = db.collection('followers').doc(userId).collection('userFollowers');
      results.followers = await deleteCollectionInBatches(followersRef, 400);
      console.log(`✅ Deleted ${results.followers} follower entries`);
    } catch (e) {
      console.log(`⚠️ Error deleting followers: ${e.message}`);
    }
    
    // 5. Обновляем счетчики
    try {
      let cleanedCount = 0;
      
      for (const followingId of userFollowingList) {
        try {
          await db.collection('users').doc(followingId).update({
            followersCount: admin.firestore.FieldValue.increment(-1)
          });
          cleanedCount++;
        } catch (e) {
          console.log(`   ⚠️ Could not update followersCount for ${followingId}: ${e.message}`);
        }
      }
      
      for (const followerId of userFollowersList) {
        try {
          await db.collection('users').doc(followerId).update({
            followingCount: admin.firestore.FieldValue.increment(-1)
          });
          cleanedCount++;
        } catch (e) {
          console.log(`   ⚠️ Could not update followingCount for ${followerId}: ${e.message}`);
        }
      }
      
      results.followsCleaned = cleanedCount;
      console.log(`✅ Cleaned ${results.followsCleaned} follow relationships`);
    } catch (e) {
      console.log(`⚠️ Error cleaning follow relationships: ${e.message}`);
    }
    
    // 6. Удаляем подколлекции пользователя
    const subcollections = ['savedPosts', 'blockedUsers', 'mutedChats', 'userPosts'];
    for (const sub of subcollections) {
      try {
        const subRef = db.collection('users').doc(userId).collection(sub);
        const deletedCount = await deleteCollectionInBatches(subRef, 400);
        results.subcollections += deletedCount;
        console.log(`✅ Deleted ${deletedCount} from ${sub}`);
      } catch (e) {
        console.log(`⚠️ Error deleting ${sub}: ${e.message}`);
      }
    }
    
    // 7. Удаляем посты и комментарии
    try {
      const postsQuery = db.collection('posts').where('userId', '==', userId);
      let postsDeleted = 0;
      let commentsDeleted = 0;
      
      while (true) {
        const posts = await postsQuery.limit(400).get();
        if (posts.empty) break;
        
        const batch = db.batch();
        
        for (const postDoc of posts.docs) {
          const comments = await postDoc.ref.collection('comments').get();
          for (const commentDoc of comments.docs) {
            batch.delete(commentDoc.ref);
            commentsDeleted++;
          }
          
          const likes = await db.collection('likes').where('postId', '==', postDoc.id).get();
          for (const likeDoc of likes.docs) {
            batch.delete(likeDoc.ref);
          }
          
          const metrics = await postDoc.ref.collection('watch_metrics').get();
          for (const metricDoc of metrics.docs) {
            batch.delete(metricDoc.ref);
          }
          
          batch.delete(postDoc.ref);
          postsDeleted++;
        }
        
        await batch.commit();
        await new Promise(resolve => setTimeout(resolve, 100));
      }
      
      results.posts = postsDeleted;
      results.postComments = commentsDeleted;
      console.log(`✅ Deleted ${results.posts} posts and ${results.postComments} comments`);
    } catch (e) {
      console.log(`⚠️ Error deleting posts: ${e.message}`);
    }
    
    // 8. Удаляем чаты и сообщения
    try {
      const chatsQuery = db.collection('chats').where('participants', 'array-contains', userId);
      let chatsDeleted = 0;
      let messagesDeleted = 0;
      
      while (true) {
        const chats = await chatsQuery.limit(400).get();
        if (chats.empty) break;
        
        const batch = db.batch();
        
        for (const chatDoc of chats.docs) {
          const messages = await chatDoc.ref.collection('messages').get();
          for (const msgDoc of messages.docs) {
            batch.delete(msgDoc.ref);
            messagesDeleted++;
          }
          batch.delete(chatDoc.ref);
          chatsDeleted++;
        }
        
        await batch.commit();
        await new Promise(resolve => setTimeout(resolve, 100));
      }
      
      results.chats = chatsDeleted;
      results.messages = messagesDeleted;
      console.log(`✅ Deleted ${results.chats} chats and ${results.messages} messages`);
    } catch (e) {
      console.log(`⚠️ Error deleting chats: ${e.message}`);
    }
    
    // 9. Удаляем уведомления
    try {
      let notificationsDeleted = 0;
      
      const receivedQuery = db.collection('notifications').where('userId', '==', userId);
      const deleted1 = await deleteQueryInBatches(receivedQuery, 400);
      notificationsDeleted += deleted1;
      
      const sentQuery = db.collection('notifications').where('senderId', '==', userId);
      const deleted2 = await deleteQueryInBatches(sentQuery, 400);
      notificationsDeleted += deleted2;
      
      results.notifications = notificationsDeleted;
      console.log(`✅ Deleted ${results.notifications} notifications`);
    } catch (e) {
      console.log(`⚠️ Error deleting notifications: ${e.message}`);
    }
    
    // 10. Удаляем из Algolia
    try {
      if (algoliaKey) {
        const algoliaClient = algoliasearch(ALGOLIA_APP_ID, algoliaKey);
        const usersIndex = algoliaClient.initIndex("users");
        await usersIndex.deleteObject(userId);
        results.algolia = true;
        console.log(`✅ User ${userId} deleted from Algolia`);
      }
    } catch (e) {
      console.log(`⚠️ Algolia error: ${e.message}`);
    }
    
    // 11. Удаляем документ пользователя
    try {
      await db.collection('users').doc(userId).delete();
      results.userDoc = true;
      console.log(`✅ User document deleted`);
    } catch (e) {
      console.log(`⚠️ Error deleting user doc: ${e.message}`);
    }
    
    console.log(`\n✅ ========== DELETE COMPLETED FOR ${userId} ==========`);
    console.log(`📊 DELETE SUMMARY:`, results);
    
    return { success: true, stats: results };
  });

// ============================================
// 🔥 TEST DELETE FUNCTION
// ============================================
exports.testDelete = functions
  .runWith({ enforceAppCheck: false })
  .https.onCall(async (data, context) => {
    const userId = data.userId;
    console.log(`🧪 TEST DELETE for user: ${userId}`);
    
    if (!userId) {
      throw new functions.https.HttpsError('invalid-argument', 'User ID required');
    }
    
    try {
      const userDoc = await db.collection('users').doc(userId).get();
      return { success: true, user: userDoc.data()?.username };
    } catch (error) {
      console.error('❌ Error:', error);
      throw error;
    }
  });

// ============================================
// 🔥 ALGOLIA TRIGGERS - С ТЕГАМИ
// ============================================

exports.onPostCreatedForAlgolia = functions
  .region('europe-west1')
  .runWith({ secrets: [ALGOLIA_ADMIN_KEY_SECRET] })
  .firestore.document('posts/{postId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const postId = context.params.postId;
    const algoliaKey = ALGOLIA_ADMIN_KEY_SECRET.value();
    
    const { postsIndex } = initAlgolia(algoliaKey);
    if (!postsIndex) return;

    // ✅ ДОБАВЛЕНЫ ТЕГИ
    const record = {
      objectID: postId,
      caption: data.caption || "",
      hashtags: data.hashtags || [],
      imageUrl: data.imageUrls?.[0] || data.imageUrl || "",
      thumbnailUrl: data.thumbnailUrl || "",
      likes: data.likes || 0,
      comments: data.comments || 0,
      createdAt: data.createdAt || Date.now(),
      userId: data.userId,
      userName: data.userName,
      userAvatar: data.userAvatar || "",
      mediaType: data.mediaType || 'photo',
      videoUrl: data.videoUrl || '',
      fitModes: data.fitModes || [],
      imageUrls: data.imageUrls || [],
      // 🔥🔥🔥 ТЕГИ 🔥🔥🔥
      tags: data.tags || [],
      linkTags: data.tags || [],
    };

    try {
      await postsIndex.saveObject(record);
      console.log(`✅ [Algolia] Indexed post: ${postId}, mediaType: ${record.mediaType}, tags: ${record.tags.length}`);
    } catch (e) {
      console.error(`❌ [Algolia] Error indexing post: ${e}`);
    }
  });

exports.onPostUpdatedForAlgolia = functions
  .region('europe-west1')
  .runWith({ secrets: [ALGOLIA_ADMIN_KEY_SECRET] })
  .firestore.document('posts/{postId}')
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();
    const postId = context.params.postId;
    const algoliaKey = ALGOLIA_ADMIN_KEY_SECRET.value();
    
    const { postsIndex } = initAlgolia(algoliaKey);
    if (!postsIndex) return;

    const updates = { objectID: postId };
    let hasUpdates = false;

    // Основные поля
    if (newData.likes !== oldData.likes) {
      updates.likes = newData.likes || 0;
      hasUpdates = true;
    }
    if (newData.comments !== oldData.comments) {
      updates.comments = newData.comments || 0;
      hasUpdates = true;
    }
    if (newData.caption !== oldData.caption) {
      updates.caption = newData.caption || "";
      hasUpdates = true;
    }
    if (newData.imageUrls?.[0] !== oldData.imageUrls?.[0]) {
      updates.imageUrl = newData.imageUrls?.[0] || "";
      hasUpdates = true;
    }
    if (newData.mediaType !== oldData.mediaType) {
      updates.mediaType = newData.mediaType || 'photo';
      hasUpdates = true;
    }
    if (newData.videoUrl !== oldData.videoUrl) {
      updates.videoUrl = newData.videoUrl || '';
      hasUpdates = true;
    }
    if (JSON.stringify(newData.fitModes) !== JSON.stringify(oldData.fitModes)) {
      updates.fitModes = newData.fitModes || [];
      hasUpdates = true;
    }
    if (JSON.stringify(newData.imageUrls) !== JSON.stringify(oldData.imageUrls)) {
      updates.imageUrls = newData.imageUrls || [];
      hasUpdates = true;
    }
    // 🔥 ОБНОВЛЯЕМ ТЕГИ
    if (JSON.stringify(newData.tags) !== JSON.stringify(oldData.tags)) {
      updates.tags = newData.tags || [];
      updates.linkTags = newData.tags || [];
      hasUpdates = true;
    }

    if (hasUpdates) {
      try {
        await postsIndex.partialUpdateObject(updates);
        console.log(`✅ [Algolia] Updated post: ${postId}`);
      } catch (e) {
        console.error(`❌ [Algolia] Update error: ${e}`);
      }
    }
  });

exports.onPostDeletedForAlgolia = functions
  .region('europe-west1')
  .runWith({ secrets: [ALGOLIA_ADMIN_KEY_SECRET] })
  .firestore.document('posts/{postId}')
  .onDelete(async (snap, context) => {
    const postId = context.params.postId;
    const algoliaKey = ALGOLIA_ADMIN_KEY_SECRET.value();
    
    const { postsIndex } = initAlgolia(algoliaKey);
    if (!postsIndex) return;
    
    try {
      await postsIndex.deleteObject(postId);
      console.log(`✅ [Algolia] Deleted post: ${postId}`);
    } catch (e) {
      console.error(`❌ [Algolia] Delete error: ${e}`);
    }
  });

exports.onUserCreatedForAlgolia = functions
  .region('europe-west1')
  .runWith({ secrets: [ALGOLIA_ADMIN_KEY_SECRET] })
  .firestore.document('users/{userId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const userId = context.params.userId;
    const algoliaKey = ALGOLIA_ADMIN_KEY_SECRET.value();
    
    const { usersIndex } = initAlgolia(algoliaKey);
    if (!usersIndex) return;

    try {
      await usersIndex.saveObject({
        objectID: userId,
        username: data.username || "",
        avatarUrl: data.avatarUrl || "",
        followersCount: data.followersCount || 0,
        bio: data.bio || "",
        createdAt: Date.now(),
      });
      console.log(`✅ [Algolia] Indexed user: ${userId}`);
    } catch (e) {
      console.error(`❌ [Algolia] User indexing error: ${e}`);
    }
  });

exports.onUserUpdatedForAlgolia = functions
  .region('europe-west1')
  .runWith({ secrets: [ALGOLIA_ADMIN_KEY_SECRET] })
  .firestore.document('users/{userId}')
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();
    const userId = context.params.userId;
    const algoliaKey = ALGOLIA_ADMIN_KEY_SECRET.value();
    
    const { usersIndex } = initAlgolia(algoliaKey);
    if (!usersIndex) return;

    if (newData.followersCount !== oldData.followersCount || newData.username !== oldData.username || newData.avatarUrl !== oldData.avatarUrl) {
      try {
        await usersIndex.partialUpdateObject({
          objectID: userId,
          followersCount: newData.followersCount || 0,
          username: newData.username || "",
          avatarUrl: newData.avatarUrl || "",
        });
        console.log(`✅ [Algolia] Updated user: ${userId}`);
      } catch (e) {
        console.error(`❌ [Algolia] User update error: ${e}`);
      }
    }
  });

// ============================================
// 🔥 МАССОВОЕ ОБНОВЛЕНИЕ ТЕГОВ
// ============================================
exports.updateAllPostsTagsInAlgolia = functions
  .runWith({ 
    enforceAppCheck: false, 
    secrets: [ALGOLIA_ADMIN_KEY_SECRET],
    timeoutSeconds: 540,
    memory: '1GB'
  })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Not authenticated');
    }
    
    console.log('🔄 [CF] Mass updating posts with tags in Algolia...');
    
    const algoliaKey = ALGOLIA_ADMIN_KEY_SECRET.value();
    const { postsIndex } = initAlgolia(algoliaKey);
    if (!postsIndex) {
      throw new functions.https.HttpsError('failed-precondition', 'Algolia not initialized');
    }
    
    try {
      const postsSnapshot = await db.collection('posts').get();
      console.log(`📊 [CF] Found ${postsSnapshot.docs.length} posts in Firestore`);
      
      let updated = 0;
      let batch = [];
      
      for (const doc of postsSnapshot.docs) {
        const post = doc.data();
        const postId = doc.id;
        
        if (post.tags && post.tags.length > 0) {
          batch.push({
            objectID: postId,
            tags: post.tags,
            linkTags: post.tags,
          });
          
          if (batch.length >= 100) {
            await postsIndex.partialUpdateObjects(batch);
            updated += batch.length;
            console.log(`✅ [CF] Updated ${updated}/${postsSnapshot.docs.length} posts`);
            batch = [];
          }
        }
      }
      
      if (batch.length > 0) {
        await postsIndex.partialUpdateObjects(batch);
        updated += batch.length;
      }
      
      console.log(`✅ [CF] Successfully updated ${updated} posts with tags`);
      return { success: true, updated: updated, total: postsSnapshot.docs.length };
      
    } catch (error) {
      console.error(`❌ [CF] Error:`, error);
      throw new functions.https.HttpsError('internal', error.message);
    }
  });

// ============================================
// 🔥 ОБНОВЛЕНИЕ ПОСТОВ ПРИ СМЕНЕ ИМЕНИ
// ============================================
exports.onUserUpdateUpdatePosts = functions
  .region('europe-west1')
  .runWith({ secrets: [ALGOLIA_ADMIN_KEY_SECRET], timeoutSeconds: 120 })
  .firestore.document('users/{userId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const userId = context.params.userId;
    
    const oldUsername = beforeData.username;
    const newUsername = afterData.username;
    
    if (oldUsername === newUsername) {
      console.log(`⏭️ [Algolia] Username not changed for user ${userId}`);
      return null;
    }
    
    console.log(`🔄 [Algolia] Username changed for user ${userId}: "${oldUsername}" -> "${newUsername}"`);
    
    const algoliaKey = ALGOLIA_ADMIN_KEY_SECRET.value();
    const { postsIndex } = initAlgolia(algoliaKey);
    
    if (!postsIndex) {
      console.log(`⚠️ [Algolia] Algolia not initialized, skipping`);
      return null;
    }
    
    try {
      const searchResult = await postsIndex.search('', {
        filters: `userId:"${userId}"`,
        hitsPerPage: 1000,
      });
      
      const hits = searchResult.hits;
      console.log(`📡 [Algolia] Found ${hits.length} posts to update for user ${userId}`);
      
      if (hits.length === 0) {
        console.log(`📭 [Algolia] No posts found for user ${userId}`);
        return null;
      }
      
      for (const hit of hits) {
        await postsIndex.partialUpdateObject({
          objectID: hit.objectID,
          userName: newUsername,
        });
      }
      
      console.log(`✅ [Algolia] Updated ${hits.length} posts with new username: ${newUsername}`);
      
    } catch (error) {
      console.error(`❌ [Algolia] Error updating posts:`, error);
    }
    
    return null;
  });

// ============================================
// 🔥 ПРИНУДИТЕЛЬНОЕ ОБНОВЛЕНИЕ ВСЕХ ПОСТОВ
// ============================================
exports.updateAllUserPostsInAlgolia = functions
  .runWith({ enforceAppCheck: false, secrets: [ALGOLIA_ADMIN_KEY_SECRET] })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Not authenticated');
    }
    
    const { userId, username, avatarUrl } = data;
    
    if (!userId) {
      throw new functions.https.HttpsError('invalid-argument', 'userId required');
    }
    
    console.log(`🔄 [CF] Force updating all user posts for ${userId} with username: ${username}`);
    
    const algoliaKey = ALGOLIA_ADMIN_KEY_SECRET.value();
    const { usersIndex, postsIndex } = initAlgolia(algoliaKey);
    
    if (!postsIndex || !usersIndex) {
      throw new functions.https.HttpsError('failed-precondition', 'Algolia not initialized');
    }
    
    try {
      await usersIndex.partialUpdateObject({
        objectID: userId,
        username: username || '',
        avatarUrl: avatarUrl || '',
      });
      
      const searchResult = await postsIndex.search('', {
        filters: `userId:"${userId}"`,
        hitsPerPage: 1000,
      });
      
      const hits = searchResult.hits;
      console.log(`📡 [CF] Found ${hits.length} posts to update`);
      
      for (const hit of hits) {
        await postsIndex.partialUpdateObject({
          objectID: hit.objectID,
          userName: username,
          userAvatar: avatarUrl,
        });
      }
      
      console.log(`✅ [CF] Updated ${hits.length} posts for user ${userId}`);
      
      return { success: true, postsUpdated: hits.length };
      
    } catch (error) {
      console.error(`❌ [CF] Error:`, error);
      throw new functions.https.HttpsError('internal', error.message);
    }
  });

exports.indexExistingUsers = functions
  .runWith({ enforceAppCheck: false, secrets: [ALGOLIA_ADMIN_KEY_SECRET] })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Not authenticated');
    }
    
    console.log('🔧 Indexing existing users...');
    
    const algoliaKey = ALGOLIA_ADMIN_KEY_SECRET.value();
    const { usersIndex } = initAlgolia(algoliaKey);
    if (!usersIndex) {
      throw new functions.https.HttpsError('failed-precondition', 'Algolia not initialized');
    }
    
    try {
      const usersSnapshot = await db.collection('users').get();
      const records = [];
      
      for (const doc of usersSnapshot.docs) {
        const data = doc.data();
        records.push({
          objectID: doc.id,
          username: data.username || "",
          avatarUrl: data.avatarUrl || "",
          followersCount: data.followersCount || 0,
          bio: data.bio || "",
          createdAt: Date.now(),
        });
      }
      
      console.log(`📊 Found ${records.length} users to index`);
      
      const batchSize = 100;
      for (let i = 0; i < records.length; i += batchSize) {
        const batch = records.slice(i, i + batchSize);
        await usersIndex.saveObjects(batch);
        console.log(`✅ Indexed ${i + batch.length}/${records.length} users`);
      }
      
      console.log(`✅ Successfully indexed ${records.length} users`);
      return { success: true, count: records.length };
      
    } catch (e) {
      console.error('❌ Error indexing users:', e);
      throw new functions.https.HttpsError('internal', e.message);
    }
  });

exports.updateUserInAlgolia = functions
  .runWith({ enforceAppCheck: false, secrets: [ALGOLIA_ADMIN_KEY_SECRET] })
  .https.onCall(async (data, context) => {
    const { userId, username, avatarUrl } = data;
    
    if (!userId) {
      throw new functions.https.HttpsError('invalid-argument', 'userId required');
    }
    
    console.log(`🔄 Updating user ${userId} in Algolia...`);
    
    const algoliaKey = ALGOLIA_ADMIN_KEY_SECRET.value();
    const { usersIndex } = initAlgolia(algoliaKey);
    if (!usersIndex) {
      console.log('⚠️ Algolia not initialized');
      return { success: false, error: 'Algolia not initialized' };
    }
    
    try {
      const userDoc = await db.collection('users').doc(userId).get();
      const userData = userDoc.data() || {};
      
      const record = {
        objectID: userId,
        username: username || userData.username || '',
        avatarUrl: avatarUrl || userData.avatarUrl || '',
        followersCount: userData.followersCount || 0,
        bio: userData.bio || '',
        updatedAt: Date.now(),
      };
      
      await usersIndex.partialUpdateObject(record, { createIfNotExists: true });
      
      console.log(`✅ User ${userId} updated in Algolia`);
      return { success: true };
      
    } catch (e) {
      console.error('❌ Error updating user in Algolia:', e);
      throw new functions.https.HttpsError('internal', e.message);
    }
  });

console.log('✅ All functions initialized');