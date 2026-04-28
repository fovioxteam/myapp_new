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
// 🔥 HELPER: ПАКЕТНОЕ УДАЛЕНИЕ (максимум 400 за раз)
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
      
      if (!userDoc.exists) {
        console.log(`⚠️ User ${userId} not found`);
        return { success: true, message: 'User not found' };
      }
      
      console.log(`✅ User ${userId} exists: ${userDoc.data()?.username}`);
      
      return { success: true, user: userDoc.data()?.username };
      
    } catch (error) {
      console.error('❌ Error:', error);
      throw error;
    }
  });

// ============================================
// 🔥 DELETE USER ACCOUNT (С ПРАВИЛЬНЫМ ОБНОВЛЕНИЕМ СЧЕТЧИКОВ)
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
    
    // Получаем Algolia ключ из секрета
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
    
    // ============================================
    // 1. УДАЛЯЕМ ЛАЙКИ ПОЛЬЗОВАТЕЛЯ
    // ============================================
    try {
      const likesQuery = db.collection('likes').where('userId', '==', userId);
      results.likes = await deleteQueryInBatches(likesQuery, 400);
      console.log(`✅ Deleted ${results.likes} likes`);
    } catch (e) {
      console.log(`⚠️ Error deleting likes: ${e.message}`);
    }
    
    // ============================================
    // 1.5 СОХРАНЯЕМ СПИСКИ ПОДПИСОК ДО УДАЛЕНИЯ (ВАЖНО!)
    // ============================================
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
    
    // ============================================
    // 2. УДАЛЯЕМ ПОДПИСКИ ПОЛЬЗОВАТЕЛЯ (following)
    // ============================================
    try {
      const followingRef = db.collection('following').doc(userId).collection('userFollowing');
      results.following = await deleteCollectionInBatches(followingRef, 400);
      console.log(`✅ Deleted ${results.following} following entries`);
    } catch (e) {
      console.log(`⚠️ Error deleting following: ${e.message}`);
    }
    
    // ============================================
    // 3. УДАЛЯЕМ ПОДПИСЧИКОВ ПОЛЬЗОВАТЕЛЯ (followers)
    // ============================================
    try {
      const followersRef = db.collection('followers').doc(userId).collection('userFollowers');
      results.followers = await deleteCollectionInBatches(followersRef, 400);
      console.log(`✅ Deleted ${results.followers} follower entries`);
    } catch (e) {
      console.log(`⚠️ Error deleting followers: ${e.message}`);
    }
    
    // ============================================
    // 4. ОБНОВЛЯЕМ СЧЕТЧИКИ (используя сохраненные списки)
    // ============================================
    try {
      let cleanedCount = 0;
      
      for (const followingId of userFollowingList) {
        try {
          await db.collection('users').doc(followingId).update({
            followersCount: admin.firestore.FieldValue.increment(-1)
          });
          cleanedCount++;
          console.log(`   ✅ Decreased followersCount for ${followingId}`);
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
          console.log(`   ✅ Decreased followingCount for ${followerId}`);
        } catch (e) {
          console.log(`   ⚠️ Could not update followingCount for ${followerId}: ${e.message}`);
        }
      }
      
      results.followsCleaned = cleanedCount;
      console.log(`✅ Cleaned ${results.followsCleaned} follow relationships and updated counters`);
    } catch (e) {
      console.log(`⚠️ Error cleaning follow relationships: ${e.message}`);
    }
    
    // ============================================
    // 5. УДАЛЯЕМ ПОДКОЛЛЕКЦИИ ПОЛЬЗОВАТЕЛЯ
    // ============================================
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
    console.log(`✅ Total subcollections deleted: ${results.subcollections}`);
    
    // ============================================
    // 6. УДАЛЯЕМ ПОСТЫ ПОЛЬЗОВАТЕЛЯ И КОММЕНТАРИИ К НИМ
    // ============================================
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
        console.log(`   Deleted ${postsDeleted} posts and ${commentsDeleted} comments so far...`);
        await new Promise(resolve => setTimeout(resolve, 100));
      }
      
      results.posts = postsDeleted;
      results.postComments = commentsDeleted;
      console.log(`✅ Deleted ${results.posts} posts and ${results.postComments} comments on those posts`);
    } catch (e) {
      console.log(`⚠️ Error deleting posts: ${e.message}`);
    }
    
    // ============================================
    // 7. УДАЛЯЕМ ЧАТЫ С УЧАСТИЕМ ПОЛЬЗОВАТЕЛЯ
    // ============================================
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
        console.log(`   Deleted ${chatsDeleted} chats and ${messagesDeleted} messages so far...`);
        await new Promise(resolve => setTimeout(resolve, 100));
      }
      
      results.chats = chatsDeleted;
      results.messages = messagesDeleted;
      console.log(`✅ Deleted ${results.chats} chats and ${results.messages} messages`);
    } catch (e) {
      console.log(`⚠️ Error deleting chats: ${e.message}`);
    }
    
    // ============================================
    // 8. УДАЛЯЕМ УВЕДОМЛЕНИЯ ПОЛЬЗОВАТЕЛЯ
    // ============================================
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
    
    // ============================================
    // 9. УДАЛЯЕМ ИЗ ALGOLIA
    // ============================================
    try {
      if (algoliaKey) {
        const algoliaClient = algoliasearch(ALGOLIA_APP_ID, algoliaKey);
        const usersIndex = algoliaClient.initIndex("users");
        await usersIndex.deleteObject(userId);
        results.algolia = true;
        console.log(`✅ User ${userId} deleted from Algolia`);
      } else {
        console.log(`⚠️ Skipping Algolia - no API key available`);
      }
    } catch (e) {
      console.log(`⚠️ Algolia error: ${e.message}`);
    }
    
    // ============================================
    // 10. УДАЛЯЕМ ДОКУМЕНТ ПОЛЬЗОВАТЕЛЯ
    // ============================================
    try {
      await db.collection('users').doc(userId).delete();
      results.userDoc = true;
      console.log(`✅ User document deleted`);
    } catch (e) {
      console.log(`⚠️ Error deleting user doc: ${e.message}`);
    }
    
    console.log(`\n✅ ========== DELETE COMPLETED FOR ${userId} ==========`);
    console.log(`📊 DELETE SUMMARY:`);
    console.log(`   - Likes deleted: ${results.likes}`);
    console.log(`   - Following entries deleted: ${results.following}`);
    console.log(`   - Follower entries deleted: ${results.followers}`);
    console.log(`   - Follow relationships cleaned: ${results.followsCleaned}`);
    console.log(`   - Subcollections deleted: ${results.subcollections}`);
    console.log(`   - Posts deleted: ${results.posts}`);
    console.log(`   - Comments on posts deleted: ${results.postComments}`);
    console.log(`   - Chats deleted: ${results.chats}`);
    console.log(`   - Messages deleted: ${results.messages}`);
    console.log(`   - Notifications deleted: ${results.notifications}`);
    console.log(`   - Algolia cleaned: ${results.algolia}`);
    console.log(`   - User document deleted: ${results.userDoc}`);
    console.log(`✅ ========== END ==========\n`);
    
    return { 
      success: true, 
      message: 'Account fully deleted',
      stats: results
    };
  });

// ============================================
// 🔥 SEND PUSH NOTIFICATION (CALLLABLE ДЛЯ ЧАТОВ)
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
// 🔥 MARK CHAT AS READ
// ============================================
exports.markChatAsRead = functions
  .runWith({ enforceAppCheck: false })
  .https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Not authenticated');

    const userId = context.auth.uid;
    const { chatId } = data;
    if (!chatId) throw new functions.https.HttpsError('invalid-argument', 'chatId required');

    await db.collection('chats').doc(chatId).update({ [`unreadCount.${userId}`]: 0 });

    const notificationsSnapshot = await db.collection('notifications')
      .where('userId', '==', userId)
      .where('chatId', '==', chatId)
      .where('isRead', '==', false)
      .get();

    const batch = db.batch();
    notificationsSnapshot.docs.forEach(doc => batch.update(doc.ref, { isRead: true }));
    await batch.commit();

    return { success: true };
  });

// ============================================
// 🔥 FIX COUNTERS
// ============================================
exports.fixCounters = functions.https.onRequest(async (req, res) => {
  try {
    console.log('🔄 Fixing counters...');
    const postsSnapshot = await db.collection('posts').get();
    const batch = db.batch();

    for (const postDoc of postsSnapshot.docs) {
      const likesSnapshot = await db
        .collection('likes')
        .where('postId', '==', postDoc.id)
        .count()
        .get();

      const commentsSnapshot = await db
        .collection('posts')
        .doc(postDoc.id)
        .collection('comments')
        .count()
        .get();

      batch.update(postDoc.ref, {
        likes: likesSnapshot.data().count,
        comments: commentsSnapshot.data().count,
      });
    }

    await batch.commit();
    console.log('✅ Counters fixed successfully');
    res.status(200).json({ success: true, message: 'Counters updated' });
  } catch (error) {
    console.error('❌ Error fixing counters:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// ============================================
// 🔥 RECALCULATE SCORES
// ============================================
const ER_WEIGHT = 0.4;
const DWELL_WEIGHT = 0.4;
const GROWTH_WEIGHT = 0.2;
const NEWBIE_BONUS = 1.3;
const EXPANDING_THRESHOLD = 0.5;
const MAIN_THRESHOLD = 0.7;
const TEST_POOL_SIZE = 200;

exports.recalculateScores = functions.pubsub
  .schedule('*/15 * * * *')
  .onRun(async () => {
    console.log('🔄 Starting score recalculation...');
    const posts = await db.collection('posts')
      .where('status', 'in', ['testing', 'expanding'])
      .get();

    let updatedCount = 0;
    const batch = db.batch();

    for (const post of posts.docs) {
      try {
        const data = post.data();
        const impressions = data.impressions || 1;
        const likes = data.likes || 0;
        const comments = data.comments || 0;
        const saves = data.saves || 0;
        const er = (likes + comments * 2 + saves * 3) / impressions;

        const watchMetrics = await post.ref
          .collection('watch_metrics')
          .where('isFinal', '==', true)
          .get();

        let avgWatchTime = 0;
        if (!watchMetrics.empty) {
          const total = watchMetrics.docs.reduce(
            (sum, doc) => sum + (doc.data().duration || 0),
            0
          );
          avgWatchTime = total / watchMetrics.size;
        }
        const dwellTime = Math.min(avgWatchTime / 60, 1);
        const newFollowers = data.newFollowers || 0;
        const growth = Math.min(newFollowers / 50, 1);

        let score = (ER_WEIGHT * er) +
                    (DWELL_WEIGHT * dwellTime) +
                    (GROWTH_WEIGHT * growth);

        const author = await db.collection('users').doc(data.userId).get();
        const authorData = author.data() || {};
        const postsCount = authorData.postsCount || 0;
        const followersCount = authorData.followersCount || 0;

        if (postsCount < 10 && followersCount < 100) {
          score *= NEWBIE_BONUS;
        }

        let newStatus = data.status;
        if (score >= MAIN_THRESHOLD && data.status !== 'main') {
          newStatus = 'main';
        } else if (score >= EXPANDING_THRESHOLD && data.status === 'testing') {
          newStatus = 'expanding';
        }

        batch.update(post.ref, {
          score,
          status: newStatus,
          lastCalculated: admin.firestore.FieldValue.serverTimestamp(),
        });
        updatedCount++;
      } catch (error) {
        console.error(`❌ Error processing post ${post.id}:`, error);
      }
    }

    await batch.commit();
    console.log(`✅ Updated ${updatedCount} posts`);
    return null;
  });

// ============================================
// 🔥 POST CREATED
// ============================================
exports.onPostCreated = functions.firestore
  .document('posts/{postId}')
  .onCreate(async (snap, context) => {
    const users = await db.collection('users')
      .where('isActive', '==', true)
      .limit(TEST_POOL_SIZE)
      .get();

    const testPool = users.docs.map(doc => doc.id);
    await snap.ref.update({
      testPool,
      status: 'testing',
      score: 0,
      impressions: 0,
      avgWatchTime: 0,
      newFollowers: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

// ============================================
// 🔥 WATCH METRICS
// ============================================
exports.onWatchMetric = functions.firestore
  .document('posts/{postId}/watch_metrics/{metricId}')
  .onCreate(async (snap, context) => {
    const postId = context.params.postId;
    const postRef = db.collection('posts').doc(postId);
    const watchMetrics = await postRef
      .collection('watch_metrics')
      .where('isFinal', '==', true)
      .get();

    if (!watchMetrics.empty) {
      const total = watchMetrics.docs.reduce(
        (sum, doc) => sum + (doc.data().duration || 0),
        0
      );
      const avgTime = total / watchMetrics.size;
      await postRef.update({ avgWatchTime: avgTime });
    }
  });

// ============================================
// 🔥 ALGOLIA TRIGGERS
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

    const record = {
      objectID: postId,
      caption: data.caption || "",
      hashtags: data.hashtags || [],
      imageUrl: data.imageUrls?.[0] || "",
      thumbnailUrl: data.thumbnailUrl || "",
      likes: data.likes || 0,
      comments: data.comments || 0,
      createdAt: Date.now(),
      userId: data.userId,
      userName: data.userName,
      userAvatar: data.userAvatar || "",
    };

    try {
      await postsIndex.saveObject(record);
      console.log(`✅ [Algolia] Indexed post: ${postId}`);
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

    if (newData.likes !== oldData.likes || newData.comments !== oldData.comments || newData.caption !== oldData.caption) {
      try {
        await postsIndex.partialUpdateObject({
          objectID: postId,
          likes: newData.likes || 0,
          comments: newData.comments || 0,
          caption: newData.caption || "",
        });
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

// ============================================
// 🔥 UPDATE USER IN ALGOLIA
// ============================================
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