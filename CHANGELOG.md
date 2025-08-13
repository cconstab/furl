# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0] - 2025-08-12

### Added
- **Unified Server**: Combined API and web servers into single `furl_server.dart` binary
- Command line options for unified server (--port, --web-root, --help)
- Better emoji-based logging and status messages
- Automatic redirect from root path (/) to furl.html
- Enhanced 404 error pages with navigation links

### Changed
- **BREAKING**: API endpoints now prefixed with `/api/` (e.g., `/api/health`, `/api/fetch/`)
- Web interface now uses same-origin API calls for better security
- Default server port consolidated to 8080 for both API and web
- Simplified deployment requiring only one server process
- Updated documentation to reflect single-server architecture

### Removed
- **Legacy servers**: Removed `furl_api.dart` and `furl_web.dart` (replaced by unified server)
- Redundant documentation and deprecated references

### Deprecated
- None (deprecated files have been removed)

### Improved
- Easier deployment with single binary
- Better resource utilization (one process vs two)
- Simplified configuration and management
- Enhanced user experience with consistent port usage

## [1.0.0] - 2025-08-12

### Added
- Initial release of Furl secure file sharing system
- AES-256 file encryption with ephemeral keys
- PIN-protected key storage using 9-character codes
- atPlatform integration for secure metadata storage
- Web-based decryption interface with client-side crypto
- Multi-server architecture (API server + Web server)
- Support for various file types including images
- Zero-knowledge security model
- Comprehensive documentation and security analysis

### Features
- Command-line tool for file encryption and upload (`bin/furl.dart`)
- HTTP API server for atSign resolution and CORS proxy (`bin/furl_api.dart`)
- Static web server for hosting decryption interface (`bin/furl_web.dart`)
- Browser-based file decryption with automatic download
- Public file storage integration (filebin.net)
- Configurable TTL for automatic secret expiration
- Verbose logging and error handling
- Cross-platform compatibility (Windows, macOS, Linux)

### Security
- Multi-layer encryption (file + key protection)
- PIN-based shared secret system
- Client-side only decryption
- Separate storage of file data and encryption metadata
- Forward secrecy with unique keys per file
- Defense in depth security architecture
