import 'package:flutter/material.dart';

class PolicyScreen extends StatelessWidget {
  final bool showPrivacy;

  const PolicyScreen({super.key, required this.showPrivacy});

  @override
  Widget build(BuildContext context) {
    final title = showPrivacy ? 'Privacy Policy' : 'Terms of Service';
    final content = showPrivacy ? _privacyText : _termsText;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Text(
          content,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[900],
            height: 1.6,
          ),
        ),
      ),
    );
  }
}

// ================= TERMS OF SERVICE =================

const String _termsText = '''
Terms of Service

Last updated: April 18, 2026

1. ACCEPTANCE OF TERMS
By accessing or using Foviox, you agree to be bound by these Terms of Service and all applicable laws and regulations. If you do not agree with any of these terms, you are prohibited from using or accessing this app.

2. AGE REQUIREMENT
You must be at least 13 years old to use Foviox. By using the app, you represent and warrant that you meet this age requirement.

3. USER ACCOUNTS
You are responsible for maintaining the security of your account and for all activities that occur under your account. You must notify us immediately of any unauthorized use of your account.

4. USER CONTENT
You retain ownership of the content you post on Foviox. By posting content, you grant Foviox a worldwide, non-exclusive, royalty-free license to use, copy, reproduce, process, adapt, modify, publish, transmit, display, and distribute such content.

5. PROHIBITED CONTENT
You may not post content that:
- Is illegal, harmful, threatening, abusive, harassing, defamatory, or obscene
- Infringes on any patent, trademark, trade secret, copyright, or other proprietary rights
- Contains spam, chain letters, or pyramid schemes
- Impersonates another person or entity
- Contains nudity, sexual content, or violence

6. INTELLECTUAL PROPERTY
The Foviox name, logo, and all related graphics are trademarks of Foviox. You may not use them without prior written permission.

7. THIRD-PARTY LINKS
Foviox may contain links to third-party websites or services. We are not responsible for the content or practices of any third-party sites.

8. TERMINATION
We reserve the right to suspend or terminate your account at any time for any reason, including violation of these Terms. You may delete your account at any time from Settings.

9. DISCLAIMER OF WARRANTIES
Foviox is provided "as is" without warranties of any kind, either express or implied.

10. LIMITATION OF LIABILITY
In no event shall Foviox be liable for any indirect, incidental, special, consequential, or punitive damages arising out of your use of the app.

11. CHANGES TO TERMS
We may modify these Terms at any time. Continued use of Foviox after changes constitutes acceptance of the new Terms.

12. GOVERNING LAW
These Terms shall be governed by the laws of the jurisdiction in which Foviox operates.

13. CONTACT INFORMATION
For questions about these Terms, contact us at:
📧 Email: fovioxteam@gmail.com

14. ACCOUNT DELETION
You can delete your account at any time from Security Settings in the app. Upon deletion, all your data will be permanently removed from our systems.
''';

// ================= PRIVACY POLICY =================

const String _privacyText = '''
Privacy Policy

Last updated: April 18, 2026

1. INFORMATION WE COLLECT

We collect information you provide directly to us:
- Account information: name, email address, profile photo
- User content: posts, comments, messages, likes, saves
- Social interactions: follows, followers, blocks

We automatically collect:
- Device information: IP address, device type, operating system, device identifiers
- Log data: access times, pages viewed, features used
- Approximate location: based on IP address (not precise GPS)
- Crash data: for improving app stability

2. HOW WE USE YOUR INFORMATION

We use your information to:
- Provide, maintain, and improve Foviox
- Personalize your content feed and recommendations
- Communicate with you about updates and features
- Monitor and analyze trends and usage
- Detect and prevent fraud, spam, or abuse
- Comply with legal obligations
- Send push notifications (you can opt-out in device settings)

3. SHARING YOUR INFORMATION

We do NOT sell your personal information. We may share information:
- With other users as directed by you (your public profile, posts, likes, comments)
- With service providers who assist in operating Foviox:
  • Google Firebase (hosting, database, authentication, storage, functions)
  • Google Cloud Platform
  • Algolia (search functionality)
- If required by law or to protect rights and safety
- In connection with a business transfer or acquisition

4. DATA RETENTION
We retain your information for as long as your account is active or as needed to provide services. You may request deletion of your account and associated data at any time from Security Settings.

5. YOUR RIGHTS
You have the right to:
- Access and update your personal information
- Request deletion of your data
- Opt-out of push notifications
- Control privacy settings (public/private account)
- Block other users

6. COOKIES AND TRACKING
We use cookies and similar technologies to:
- Remember your preferences
- Understand how you use Foviox
- Improve our services

7. CHILDREN'S PRIVACY
Foviox is not intended for children under 13. We do not knowingly collect information from children under 13. If you believe a child has provided us with personal information, please contact us.

8. DATA SECURITY
We implement reasonable security measures to protect your information. However, no method of transmission over the internet is 100% secure.

9. INTERNATIONAL TRANSFERS
Your information may be transferred to and processed in countries other than your own. We ensure appropriate safeguards are in place.

10. CALIFORNIA PRIVACY RIGHTS (CCPA)
California residents have the right to:
- Know what personal information is collected
- Request deletion of personal information
- Opt-out of the sale of personal information (we do not sell)
- Not be discriminated against for exercising privacy rights

11. GDPR RIGHTS (European Economic Area)
If you are in the EEA, you have the right to:
- Access, correct, or delete your data
- Restrict or object to processing
- Data portability
- Withdraw consent at any time
To exercise these rights, contact us at fovioxteam@gmail.com

12. TRACKING AND ANALYTICS
We use Firebase Analytics and Crashlytics to improve the app. We do NOT share your data with third parties for advertising purposes.

13. CHANGES TO THIS POLICY
We may update this Privacy Policy from time to time. We will notify you of significant changes via in-app notification or email.

14. CONTACT US
For privacy-related questions or requests:
📧 Email: fovioxteam@gmail.com
📍 Website: foviox.com (coming soon)

15. ACCOUNT DELETION
You can delete your account at any time from Security Settings → Delete Account. All your data (posts, messages, likes, followers, chats) will be permanently removed within 24 hours.
''';