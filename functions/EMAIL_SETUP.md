# Email Configuration Setup

## Overview
The password reset email functionality uses Firebase Cloud Functions with SendGrid API to send emails securely.

## Setup Instructions

### 1. Get SendGrid API Key

1. Go to [SendGrid](https://sendgrid.com) and create an account (free tier available)
2. Navigate to Settings → API Keys
3. Click "Create API Key"
4. Name it "SprintIndex Mail" or similar
5. Select **Mail Send** permission only (most secure)
6. Copy the API key

### 2. Configure Environment Variable

Edit `functions/.env.local` and add your API key:

```
SENDGRID_API_KEY=SG.your-actual-api-key-here
```

### 3. Verify Sender Email

In SendGrid dashboard:
1. Go to Settings → Sender Authentication
2. Verify your domain or single sender email
3. Use the verified email in the Cloud Function (currently set to `noreply@sprintindex.com`)

### 4. Deploy Cloud Functions

```bash
cd functions
npm install
firebase deploy --only functions
```

### 5. Test the Function

Use the Firebase Console or call it from your app:

```dart
final result = await FirebaseFunctions.instance
    .httpsCallable('sendPasswordResetEmail')
    .call({
      'email': 'user@example.com',
      'resetUrl': 'https://sprintindex.com/reset-password?token=...',
    });
```

## Why SendGrid API Key?

✅ **More Secure:**
- Can be revoked instantly without changing your email password
- Limited to only sending emails (no access to your account)
- Industry standard for transactional emails

✅ **Better Control:**
- Monitor email delivery in SendGrid dashboard
- Track bounces and complaints
- Set up webhooks for delivery events

✅ **Professional:**
- Better email deliverability
- Handles spam filtering properly
- Supports email templates and scheduling

## Troubleshooting

- **"Email service not configured"**: Check that SENDGRID_API_KEY is set in `.env.local`
- **"Failed to send email"**: Verify the API key is correct and has Mail Send permission
- **Emails going to spam**: Verify your sender email in SendGrid dashboard
- **Function not found**: Ensure you've deployed with `firebase deploy --only functions`

## Security Notes

- Never commit `.env.local` to version control (it's in .gitignore)
- Rotate your API key periodically
- Use different API keys for development and production
- For production, use Firebase Secret Manager instead of .env files
