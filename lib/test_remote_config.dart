import 'package:flutter/material.dart';
import 'package:sports_chat_app/src/services/remote_config_service.dart';
import 'package:sports_chat_app/src/services/email_service.dart';

class TestRemoteConfigScreen extends StatefulWidget {
  const TestRemoteConfigScreen({super.key});

  @override
  State<TestRemoteConfigScreen> createState() => _TestRemoteConfigScreenState();
}

class _TestRemoteConfigScreenState extends State<TestRemoteConfigScreen> {
  final RemoteConfigService _remoteConfig = RemoteConfigService();
  final EmailService _emailService = EmailService();
  String _status = 'Loading...';
  String _mapsKey = '';
  String _emailKey = '';
  String _emailUrl = '';
  String _fromEmail = '';

  @override
  void initState() {
    super.initState();
    _testRemoteConfig();
  }

  Future<void> _testRemoteConfig() async {
    try {
      await _remoteConfig.initialize();
      
      setState(() {
        _status = 'Remote Config loaded successfully!';
        _mapsKey = _remoteConfig.googleMapsApiKey;
        _emailKey = _remoteConfig.emailApiKey;
        _emailUrl = _remoteConfig.emailServiceUrl;
        _fromEmail = _remoteConfig.emailFromAddress;
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _testEmail() async {
    setState(() {
      _status = 'Sending test email...';
    });
    
    final success = await _emailService.sendEmail(
      to: 'test@example.com',
      subject: 'Test from SprintIndex',
      body: 'This is a test email from Remote Config integration!',
    );
    
    setState(() {
      _status = success ? 'Email sent successfully!' : 'Email failed to send';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remote Config Test'),
        backgroundColor: const Color(0xFFFF8C00),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status: $_status',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text('Maps API Key: ${_mapsKey.isNotEmpty ? "${_mapsKey.substring(0, 15)}..." : "Not loaded"}'),
            const SizedBox(height: 10),
            Text('Email API Key: ${_emailKey.isNotEmpty ? "${_emailKey.substring(0, 15)}..." : "Not loaded"}'),
            const SizedBox(height: 10),
            Text('Email Service URL: $_emailUrl'),
            const SizedBox(height: 10),
            Text('From Email: $_fromEmail'),
            const SizedBox(height: 20),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _testRemoteConfig,
                  child: const Text('Refresh Config'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _testEmail,
                  child: const Text('Test Email'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}