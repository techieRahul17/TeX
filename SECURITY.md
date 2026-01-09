# Security Policy

## Supported Versions

The following versions of **PingMe** are currently being supported with security updates.

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take the security of our application seriously. If you have any concerns regarding the security of PingMe or find a vulnerability:

1.  **Do NOT** open a public issue on GitHub.
2.  Please email us directly at **techierahul17@gmail.com** (or your preferred contact email).
3.  Include a detailed description of the vulnerability and steps to reproduce it.

We aim to acknowledge receiving your report within 48 hours and will provide a timeline for the fix.

### Important Notes for Developers

- **API Keys**: This project assumes standard Firebase Client SDK usage. While client keys (`apiKey` in `firebase_options.dart`) are generally public, please ensure your **Firestore Security Rules** are configured to prevent unauthorized access.
- **Secrets**: Never commit service account keys (JSON) or sensitive backend credentials to this repository.

Thank you for helping keep PingMe secure! 🛡️
