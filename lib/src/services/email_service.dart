import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sports_chat_app/src/services/remote_config_service.dart';

class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  final RemoteConfigService _remoteConfig = RemoteConfigService();

  Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
    bool isHtml = false,
  }) async {
    try {
      // Ensure Remote Config is initialized
      if (!_remoteConfig.isInitialized) {
        await _remoteConfig.initialize();
      }

      final apiKey = _remoteConfig.emailApiKey;
      final serviceUrl = _remoteConfig.emailServiceUrl;
      final fromAddress = _remoteConfig.emailFromAddress;

      if (apiKey.isEmpty || serviceUrl.isEmpty) {
        debugPrint('Email service not configured in Remote Config');
        return false;
      }

      // Example for SendGrid API
      final response = await http.post(
        Uri.parse('$serviceUrl/mail/send'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'personalizations': [
            {
              'to': [
                {'email': to}
              ]
            }
          ],
          'from': {'email': fromAddress},
          'subject': subject,
          'content': [
            {
              'type': isHtml ? 'text/html' : 'text/plain',
              'value': body,
            }
          ],
        }),
      );

      if (response.statusCode == 202) {
        debugPrint('Email sent successfully to $to');
        return true;
      } else {
        debugPrint('Failed to send email: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error sending email: $e');
      return false;
    }
  }

  Future<bool> sendWelcomeEmail(String userEmail, String userName) async {
    return await sendEmail(
      to: userEmail,
      subject: 'Welcome to SprintIndex!',
      body: '''
Hello $userName,

Welcome to SprintIndex! We're excited to have you join our sports community.

You can now:
- Find sports clubs near you
- Connect with other athletes
- Join exciting sports events

Get started by exploring clubs in your area!

Best regards,
The SprintIndex Team
      ''',
    );
  }

  Future<bool> sendClubInvitation({
    required String userEmail,
    required String userName,
    required String clubName,
    required String inviterName,
  }) async {
    return await sendEmail(
      to: userEmail,
      subject: 'You\'re invited to join $clubName!',
      body: '''
Hello $userName,

$inviterName has invited you to join $clubName on SprintIndex!

Join the club to:
- Connect with fellow athletes
- Participate in club activities
- Stay updated on events and matches

Open the SprintIndex app to accept this invitation.

Best regards,
The SprintIndex Team
      ''',
    );
  }
}
