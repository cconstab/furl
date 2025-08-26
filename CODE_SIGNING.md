# Code Signing Setup for Furl

This document explains how to configure code signing secrets for the furl GitHub Actions workflows.

## Overview

The build workflow signs binaries for all platforms:
- **Windows**: Authenticode signing with code signing certificate
- **macOS**: Apple code signing and notarization  
- **Linux**: GPG detached signatures

## Required Secrets

### Windows Code Signing

Add these secrets to your GitHub repository:

#### `WINDOWS_CERTIFICATE`
- Your code signing certificate in Base64 format
- Usually a `.p12` or `.pfx` file

```bash
# Convert certificate to Base64
base64 -i your-certificate.p12 -o certificate.base64
# Copy the content of certificate.base64 to the secret
```

#### `WINDOWS_CERTIFICATE_PASSWORD`
- Password for your code signing certificate

### macOS Code Signing

#### `MACOS_CERTIFICATE`
- Your Apple Developer certificate in Base64 format
- Export from Keychain as `.p12` file

```bash
# Export from Keychain Access:
# 1. Find your "Developer ID Application" certificate
# 2. Right-click → Export
# 3. Save as .p12 with password
# 4. Convert to Base64
base64 -i developer-certificate.p12 -o macos-cert.base64
```

#### `MACOS_CERTIFICATE_PASSWORD`
- Password for your exported .p12 certificate

#### `MACOS_SIGNING_IDENTITY`
- Your signing identity (usually "Developer ID Application: Your Name (TEAM_ID)")
- Find in Keychain Access or Developer Portal

#### `APPLE_ID`
- Your Apple ID email address
- Used for notarization

#### `APPLE_APP_PASSWORD`
- App-specific password for your Apple ID
- Generate at: https://appleid.apple.com/account/manage
- Use "App-Specific Passwords" section

#### `APPLE_TEAM_ID`
- Your Apple Developer Team ID
- Find in Apple Developer Portal → Membership

### Linux/GPG Signing

#### `GPG_PRIVATE_KEY`
- Your GPG private key in ASCII armor format

```bash
# Export your private key
gpg --armor --export-secret-keys your-email@example.com > private-key.asc
# Copy the content of private-key.asc to the secret
```

#### `GPG_PASSPHRASE`
- Passphrase for your GPG private key

## Setting Up Secrets

### In GitHub Repository

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret with the exact name listed above

### Security Best Practices

#### Certificate Security
- Use separate certificates for different projects
- Set expiration dates and rotate certificates regularly
- Use Hardware Security Modules (HSM) when possible
- Never commit certificates to version control

#### Secret Management
- Use GitHub's encrypted secrets (never environment secrets for certificates)
- Limit repository access to trusted contributors
- Monitor secret usage in Actions logs
- Rotate secrets if compromised

#### Access Control
- Code signing only runs on tag pushes and main branch
- Pull requests do not trigger signing (security measure)
- Use branch protection rules

## Certificate Requirements

### Windows Authenticode
- **Type**: Code signing certificate from trusted CA
- **Recommended CAs**: DigiCert, Sectigo, GlobalSign
- **Format**: `.p12` or `.pfx` with private key
- **Validation**: Extended Validation (EV) preferred for immediate trust

### Apple Developer
- **Type**: "Developer ID Application" certificate
- **Requirements**: 
  - Apple Developer Program membership ($99/year)
  - Valid developer account in good standing
- **Format**: `.p12` export from Keychain Access
- **Notarization**: Required for macOS 10.14.5+

### GPG (Linux)
- **Type**: GPG key pair (RSA 4096-bit recommended)
- **Distribution**: Publish public key to key servers
- **Trust**: Establish web of trust or use keybase.io
- **Format**: ASCII armored private key

## Verification Commands

### Windows
```cmd
# Verify Authenticode signature
signtool verify /pa /v furl.exe

# PowerShell verification
Get-AuthenticodeSignature furl.exe
```

### macOS
```bash
# Verify code signature
codesign -v -v furl

# Check notarization
spctl -a -v furl

# Detailed signature info
codesign -d -vvv furl
```

### Linux
```bash
# Verify GPG signature
gpg --verify furl.sig furl

# Import public key first if needed
gpg --keyserver keyserver.ubuntu.com --recv-keys YOUR_KEY_ID
```

## Troubleshooting

### Common Issues

#### Windows
- **Error**: "Invalid certificate" → Check certificate validity and CA trust
- **Error**: "Timestamp failed" → Ensure internet connectivity for timestamping
- **Solution**: Use multiple timestamp servers for redundancy

#### macOS
- **Error**: "No identity found" → Verify certificate installation and name
- **Error**: "Notarization failed" → Check Apple ID credentials and 2FA
- **Solution**: Test locally with `xcrun notarytool` first

#### Linux
- **Error**: "Secret key not available" → Check GPG key import
- **Error**: "Bad passphrase" → Verify secret configuration
- **Solution**: Test GPG operations locally first

### Testing Locally

Before setting up GitHub Actions, test signing locally:

```bash
# Test Windows signing (on Windows with certificate installed)
signtool sign /f certificate.p12 /p password /t http://timestamp.digicert.com furl.exe

# Test macOS signing (on macOS with certificate in Keychain)
codesign --sign "Developer ID Application: Your Name" furl

# Test GPG signing (any platform with GPG)
gpg --armor --detach-sig furl
```

## Cost Considerations

- **Windows Code Signing**: $100-400/year depending on CA and validation level
- **Apple Developer Program**: $99/year
- **GPG**: Free but requires key management infrastructure

## Compliance Notes

Some organizations require:
- Hardware Security Modules (HSM) for certificate storage
- Timestamping for long-term signature validity
- Certificate transparency logging
- FIPS 140-2 validated signing infrastructure

Check your organization's requirements before choosing certificates.
