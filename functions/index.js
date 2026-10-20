const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
require('dotenv').config();

admin.initializeApp();

// Increment comment count when a new comment is created
exports.incrementCommentCount = functions.firestore
  .document('posts/{postId}/comments/{commentId}')
  .onCreate(async (snap, context) => {
    const { postId } = context.params;
    
    try {
      await admin.firestore().collection('posts').doc(postId).update({
        commentsCount: admin.firestore.FieldValue.increment(1),
      });
      console.log(`Comment count incremented for post ${postId}`);
    } catch (error) {
      console.error(`Error incrementing comment count for post ${postId}:`, error);
    }
  });

// Decrement comment count when a comment is deleted
exports.decrementCommentCount = functions.firestore
  .document('posts/{postId}/comments/{commentId}')
  .onDelete(async (snap, context) => {
    const { postId } = context.params;
    
    try {
      await admin.firestore().collection('posts').doc(postId).update({
        commentsCount: admin.firestore.FieldValue.increment(-1),
      });
      console.log(`Comment count decremented for post ${postId}`);
    } catch (error) {
      console.error(`Error decrementing comment count for post ${postId}:`, error);
    }
  });

// Helper function to determine channel ID based on notification type
function getChannelIdForType(notificationType) {
  const typeToChannel = {
    'direct_message': 'messages',
    'club_message': 'messages',
    'new_follow': 'social',
    'like': 'social',
    'dislike': 'social',
    'comment': 'social',
    'club_join_request': 'clubs',
    'club_join_approved': 'clubs',
    'club_join_rejected': 'clubs',
    'club_post': 'clubs',
    'club_created': 'clubs',
    'club_joined': 'clubs',
    'club_deleted': 'clubs',
    'club_removed': 'clubs',
    'club_exited': 'clubs',
    'follower_post': 'posts',
    'following_post': 'posts',
    'new_post': 'posts',
    'new_club_nearby': 'posts',
    'post_upload': 'system',
    'profile_update': 'social',
    'nearby_club': 'posts',
  };
  
  return typeToChannel[notificationType] || 'system';
}

// Helper function to determine iOS category based on notification type
function getIOSCategoryForType(notificationType) {
  const typeToCategory = {
    'direct_message': 'MESSAGES_CATEGORY',
    'club_message': 'MESSAGES_CATEGORY',
    'new_follow': 'SOCIAL_CATEGORY',
    'like': 'SOCIAL_CATEGORY',
    'dislike': 'SOCIAL_CATEGORY',
    'comment': 'SOCIAL_CATEGORY',
    'club_join_request': 'CLUBS_CATEGORY',
    'club_join_approved': 'CLUBS_CATEGORY',
    'club_join_rejected': 'CLUBS_CATEGORY',
    'club_post': 'CLUBS_CATEGORY',
    'club_created': 'CLUBS_CATEGORY',
    'club_joined': 'CLUBS_CATEGORY',
    'club_deleted': 'CLUBS_CATEGORY',
    'club_removed': 'CLUBS_CATEGORY',
    'club_exited': 'CLUBS_CATEGORY',
    'follower_post': 'POSTS_CATEGORY',
    'following_post': 'POSTS_CATEGORY',
    'new_post': 'POSTS_CATEGORY',
    'new_club_nearby': 'POSTS_CATEGORY',
    'post_upload': 'SYSTEM_CATEGORY',
    'profile_update': 'SOCIAL_CATEGORY',
    'nearby_club': 'POSTS_CATEGORY',
  };
  
  return typeToCategory[notificationType] || 'SYSTEM_CATEGORY';
}

// Send notification when a new notification document is created
exports.sendNotificationOnCreate = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    const notificationId = context.params.notificationId;
    const recipientUserId = notification.recipientUserId;
    const fcmToken = notification.fcmToken;
    const notificationType = notification.data?.type || 'default';

    console.log(`📨 Processing notification ${notificationId}`);
    console.log(`   Recipient: ${recipientUserId}, Token: ${fcmToken?.substring(0, 20)}...`);
    console.log(`   Type: ${notificationType}, Title: ${notification.title}`);

    if (!recipientUserId || !fcmToken) {
      console.error(`❌ Missing required fields for notification ${notificationId}`);
      console.error(`   recipientUserId: ${recipientUserId}, fcmToken: ${fcmToken}`);
      
      // Mark as failed
      try {
        await admin.firestore()
          .collection('notifications')
          .doc(notificationId)
          .update({
            sent: false,
            error: 'Missing recipientUserId or fcmToken',
            failedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
      } catch (updateError) {
        console.error(`Failed to update notification status: ${updateError}`);
      }
      return;
    }

    try {
      const channelId = getChannelIdForType(notificationType);
      const iosCategory = getIOSCategoryForType(notificationType);
      
      console.log(`   Channel: ${channelId}, iOS Category: ${iosCategory}`);
      
      // Prepare FCM message
      const message = {
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: {
          type: notificationType,
          notificationId: notificationId,
          ...(notification.data || {}),
        },
        android: {
          priority: 'high',
          notification: {
            channelId: channelId,
            sound: 'default',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: notification.title,
                body: notification.body,
              },
              sound: 'default',
              badge: 1,
              category: iosCategory,
            },
          },
        },
      };

      // Send notification
      console.log(`   Sending FCM message...`);
      const response = await admin.messaging().send({
        ...message,
        token: fcmToken,
      });

      // Mark as sent
      await admin.firestore()
        .collection('notifications')
        .doc(notificationId)
        .update({
          sent: true,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          messageId: response,
        });

      console.log(`✅ Notification ${notificationId} sent successfully`);
      console.log(`   Message ID: ${response}`);
    } catch (error) {
      console.error(`❌ Error sending notification ${notificationId}:`, error);
      console.error(`   Error code: ${error.code}`);
      console.error(`   Error message: ${error.message}`);
      
      // Mark as failed
      try {
        await admin.firestore()
          .collection('notifications')
          .doc(notificationId)
          .update({
            sent: false,
            error: error.message,
            errorCode: error.code,
            failedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        console.log(`   Marked notification as failed in database`);
      } catch (updateError) {
        console.error(`   Failed to update notification status: ${updateError}`);
      }
    }
  });

// Send notification to topic
exports.sendTopicNotification = functions.firestore
  .document('topicNotifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    const topic = notification.topic;
    const notificationType = notification.data?.type || 'default';

    if (!topic) {
      console.log('No topic in notification');
      return;
    }

    try {
      const channelId = getChannelIdForType(notificationType);
      const iosCategory = getIOSCategoryForType(notificationType);
      
      const message = {
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: {
          type: notificationType,
          notificationId: context.params.notificationId,
          ...notification.data,
        },
        android: {
          priority: 'high',
          notification: {
            channelId: channelId,
            sound: 'default',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: notification.title,
                body: notification.body,
              },
              sound: 'default',
              badge: 1,
              category: iosCategory,
            },
          },
        },
      };

      const response = await admin.messaging().sendToTopic(topic, message);

      await admin.firestore()
        .collection('topicNotifications')
        .doc(context.params.notificationId)
        .update({
          sent: true,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          messageId: response,
        });

      console.log(`Topic notification sent to ${topic} via channel ${channelId}: ${response}`);
    } catch (error) {
      console.error('Error sending topic notification:', error);
      
      await admin.firestore()
        .collection('topicNotifications')
        .doc(context.params.notificationId)
        .update({
          sent: false,
          error: error.message,
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
  });

// Retry failed notifications every 5 minutes
exports.retryFailedNotifications = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    console.log('🔄 Checking for failed notifications to retry...');
    
    try {
      const failedNotifications = await admin.firestore()
        .collection('notifications')
        .where('sent', '==', false)
        .where('retryCount', '<', 3)
        .limit(10)
        .get();

      console.log(`Found ${failedNotifications.size} failed notifications to retry`);

      for (const doc of failedNotifications.docs) {
        const notification = doc.data();
        const notificationId = doc.id;
        const retryCount = (notification.retryCount || 0) + 1;

        console.log(`🔄 Retrying notification ${notificationId} (attempt ${retryCount})`);

        try {
          const channelId = getChannelIdForType(notification.data?.type || 'default');
          const iosCategory = getIOSCategoryForType(notification.data?.type || 'default');

          const message = {
            notification: {
              title: notification.title,
              body: notification.body,
            },
            data: {
              type: notification.data?.type || 'default',
              notificationId: notificationId,
              ...(notification.data || {}),
            },
            android: {
              priority: 'high',
              notification: {
                channelId: channelId,
                sound: 'default',
                clickAction: 'FLUTTER_NOTIFICATION_CLICK',
              },
            },
            apns: {
              payload: {
                aps: {
                  alert: {
                    title: notification.title,
                    body: notification.body,
                  },
                  sound: 'default',
                  badge: 1,
                  category: iosCategory,
                },
              },
            },
          };

          const response = await admin.messaging().send({
            ...message,
            token: notification.fcmToken,
          });

          await admin.firestore()
            .collection('notifications')
            .doc(notificationId)
            .update({
              sent: true,
              sentAt: admin.firestore.FieldValue.serverTimestamp(),
              messageId: response,
              retryCount: retryCount,
            });

          console.log(`✅ Retry successful for notification ${notificationId}`);
        } catch (error) {
          console.error(`❌ Retry failed for notification ${notificationId}:`, error.message);

          await admin.firestore()
            .collection('notifications')
            .doc(notificationId)
            .update({
              retryCount: retryCount,
              lastError: error.message,
              lastRetryAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
      }

      console.log('✅ Retry check completed');
    } catch (error) {
      console.error('❌ Error in retry function:', error);
    }
  });

// Send password reset email via SendGrid
exports.sendPasswordResetEmail = functions.https.onCall(async (data, context) => {
  const { email, resetUrl } = data;

  if (!email || !resetUrl) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Email and resetUrl are required'
    );
  }

  const sendGridApiKey = process.env.SENDGRID_API_KEY;
  if (!sendGridApiKey) {
    console.error('SENDGRID_API_KEY not configured');
    throw new functions.https.HttpsError(
      'internal',
      'Email service not configured'
    );
  }

  try {
    const htmlContent = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            line-height: 1.6;
            color: #333;
            background-color: #f9f9f9;
            margin: 0;
            padding: 0;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
            background-color: #ffffff;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            padding: 20px 0;
            border-bottom: 2px solid #FF8C00;
        }
        .logo {
            font-size: 28px;
            font-weight: bold;
        }
        .sprint {
            color: #000;
        }
        .index {
            color: #FF8C00;
        }
        .content {
            padding: 30px 0;
        }
        .button-container {
            text-align: center;
            margin: 30px 0;
        }
        .reset-button {
            display: inline-block;
            background-color: #FF8C00;
            color: white;
            padding: 14px 40px;
            text-decoration: none;
            border-radius: 6px;
            font-weight: bold;
            font-size: 16px;
            border: 2px solid #FF8C00;
        }
        .warning {
            background-color: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 15px;
            margin: 20px 0;
            border-radius: 4px;
        }
        .expiry-notice {
            background-color: #f0f0f0;
            padding: 15px;
            border-radius: 4px;
            text-align: center;
            font-size: 14px;
            color: #666;
            margin: 20px 0;
        }
        .footer {
            text-align: center;
            color: #999;
            font-size: 12px;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #eee;
        }
        .security-tips {
            background-color: #e8f4f8;
            border-left: 4px solid #0288d1;
            padding: 15px;
            margin: 20px 0;
            border-radius: 4px;
            font-size: 14px;
        }
        .link-text {
            font-size: 12px;
            color: #0066cc;
            word-break: break-all;
            background-color: #f5f5f5;
            padding: 10px;
            border-radius: 4px;
            font-family: monospace;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">
                <span class="sprint">Sprint</span><span class="index">Index</span>
            </div>
        </div>
        
        <div class="content">
            <h2 style="margin-top: 0;">Reset Your Password</h2>
            
            <p>Hello,</p>
            
            <p>We received a request to reset your password for your SprintIndex account. Click the button below to create a new password:</p>
            
            <div class="button-container">
                <a href="${resetUrl}" class="reset-button">Reset Password</a>
            </div>
            
            <div class="expiry-notice">
                ⏱️ This link will expire in 1 hour
            </div>
            
            <p style="font-size: 14px; color: #666;">If the button above doesn't work, copy and paste this link in your browser:</p>
            <div class="link-text">${resetUrl}</div>
            
            <div class="security-tips">
                <strong>🔒 Security Tips:</strong><br>
                • Never share this link with anyone<br>
                • SprintIndex will never ask for your password via email<br>
                • If you didn't request this, ignore this email
            </div>
            
            <div class="warning">
                <strong>⚠️ Didn't request a password reset?</strong><br>
                If you didn't request this, please ignore this email or contact our support team if you have concerns about your account security.
            </div>
            
            <p>Best regards,<br><strong>The SprintIndex Team</strong></p>
        </div>
        
        <div class="footer">
            <p>This is an automated message, please do not reply to this email.</p>
            <p>&copy; 2025 SprintIndex. All rights reserved.</p>
            <p>Questions? Contact support@sprintindex.com</p>
        </div>
    </div>
</body>
</html>
    `;

    const plainTextContent = `
Reset Your Password

Hello,

We received a request to reset your password for your SprintIndex account. Click the link below to create a new password:

${resetUrl}

This link will expire in 1 hour.

Security Tips:
• Never share this link with anyone
• SprintIndex will never ask for your password via email
• If you didn't request this, ignore this email

Didn't request a password reset?
If you didn't request this, please ignore this email or contact our support team if you have concerns about your account security.

Best regards,
The SprintIndex Team

---
This is an automated message, please do not reply to this email.
© 2025 SprintIndex. All rights reserved.
Questions? Contact support@sprintindex.com
    `;

    const response = await axios.post(
      'https://api.sendgrid.com/v3/mail/send',
      {
        personalizations: [
          {
            to: [{ email: email }],
            subject: 'Reset Your SprintIndex Password',
          },
        ],
        from: {
          email: 'noreply@sprintindex.com',
          name: 'SprintIndex',
        },
        reply_to: {
          email: 'support@sprintindex.com',
          name: 'SprintIndex Support',
        },
        content: [
          {
            type: 'text/plain',
            value: plainTextContent,
          },
          {
            type: 'text/html',
            value: htmlContent,
          },
        ],
        headers: {
          'X-Priority': '3',
          'X-MSMail-Priority': 'Normal',
          'Importance': 'Normal',
          'X-Mailer': 'SprintIndex',
        },
        mail_settings: {
          sandbox_mode: {
            enable: false,
          },
          bypass_list_management: {
            enable: true,
          },
        },
        tracking_settings: {
          click_tracking: {
            enable: true,
            enable_text: false,
          },
          open_tracking: {
            enable: true,
          },
          subscription_tracking: {
            enable: false,
          },
        },
      },
      {
        headers: {
          Authorization: `Bearer ${sendGridApiKey}`,
          'Content-Type': 'application/json',
        },
      }
    );

    console.log(`Password reset email sent to ${email}`);
    return { success: true, message: 'Email sent successfully' };
  } catch (error) {
    console.error('Error sending password reset email:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to send password reset email'
    );
  }
});

// Scheduled function to delete expired temporary posts
// Runs every hour to clean up expired posts
exports.deleteExpiredPosts = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async (context) => {
    try {
      const now = admin.firestore.Timestamp.now();
      
      // Query all temporary posts that have expired
      const expiredPostsSnapshot = await admin.firestore()
        .collection('posts')
        .where('isPermanent', '==', false)
        .where('expiresAt', '<=', now)
        .get();
      
      console.log(`Found ${expiredPostsSnapshot.docs.length} expired posts to delete`);
      
      // Delete each expired post
      const batch = admin.firestore().batch();
      let deleteCount = 0;
      
      expiredPostsSnapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
        deleteCount++;
      });
      
      // Commit the batch delete
      if (deleteCount > 0) {
        await batch.commit();
        console.log(`Successfully deleted ${deleteCount} expired posts`);
      }
      
      return { success: true, deletedCount: deleteCount };
    } catch (error) {
      console.error('Error deleting expired posts:', error);
      return { success: false, error: error.message };
    }
  });
