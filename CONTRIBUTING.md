# Contributing to Sports Chat App

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to the Sports Chat App project.

## Code of Conduct

Be respectful, inclusive, and professional in all interactions.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/sports-chat-app.git`
3. Create a feature branch: `git checkout -b feature/your-feature-name`
4. Install dependencies: `flutter pub get`

## Development Setup

### Prerequisites
- Flutter SDK 3.9.2 or higher
- Dart SDK (included with Flutter)
- Android Studio or Xcode
- Firebase CLI

### Local Configuration
1. Copy the API keys template:
   ```bash
   cp api_keys_template.env api_keys.env
   ```
2. Add your local API keys to `api_keys.env`
3. Set up Firebase configuration files locally (not committed to repo)

## Making Changes

### Code Style
- Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use `flutter analyze` to check for issues
- Format code with `dart format`

### Commit Messages
- Use clear, descriptive commit messages
- Start with a verb: "Add", "Fix", "Update", "Remove"
- Example: `Add real-time notification support for direct messages`

### Testing
- Write tests for new features
- Run tests before submitting: `flutter test`
- Ensure no existing tests are broken

## Submitting Changes

1. Push to your fork
2. Create a Pull Request with a clear description
3. Reference any related issues: `Fixes #123`
4. Ensure all checks pass
5. Request review from maintainers

## Pull Request Guidelines

- Keep PRs focused on a single feature or fix
- Include screenshots for UI changes
- Update documentation if needed
- Ensure no sensitive data is exposed
- Test on both Android and iOS if possible

## Reporting Issues

### Bug Reports
- Use the bug report template
- Include device info, OS version, and Flutter version
- Provide steps to reproduce
- Include error logs if available

### Feature Requests
- Use the feature request template
- Explain the use case
- Describe expected behavior

## Project Structure

```
lib/
├── main.dart              # App entry point
├── models/                # Data models
├── services/              # Firebase and API services
├── screens/               # UI screens
├── widgets/               # Reusable components
└── utils/                 # Helper functions
```

## Important Notes

- **Never commit API keys or sensitive data**
- **Never commit Firebase configuration files**
- **Always use the template files for configuration**
- Test thoroughly before submitting PRs
- Keep dependencies up to date

## Questions?

- Check existing issues and documentation
- Create a new issue with the question label
- Review the setup guides in the repository

Thank you for contributing!
