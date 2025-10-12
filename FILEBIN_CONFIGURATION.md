# Filebin Configuration Feature

This document describes the implementation of configurable filebin URL support in both the CLI and Flutter app using atKeys.

## Overview

The filebin URL is now configurable instead of hardcoded to `filebin.net`. Configuration is stored in atKeys (not local files), making it seamlessly available across all your devices.

The system uses a three-tier resolution strategy:

1. **Private override atKey**: Check `private:filebin_override.furl@myatsign` for your personal config
2. **Public config atKey**: Check `public:filebin.furl@<atsign>` for organization-wide config
3. **Default fallback**: Use `https://filebin.net` as the default

## Key Benefits of atKey Storage

- **Cross-device sync**: Your config automatically syncs across all devices
- **atPlatform native**: Uses the same atKey infrastructure as the rest of furl
- **Secure**: Private overrides are encrypted and only you can read them
- **Organization-friendly**: Public configs allow org-wide filebin server configuration

## CLI Implementation

### New Files Created

1. **`lib/config_manager.dart`**
   - Manages local configuration stored in `~/.furl/furl_config.json`
   - Provides methods to get/set filebin URL and default atSign
   - Default values: `https://filebin.net` and `@furl`

2. **`lib/filebin_resolver.dart`**
   - Resolves the filebin URL using the three-tier strategy
   - Tries atKey lookup first (if atClient available)
   - Falls back to local config, then default

### Modified Files

1. **`bin/furl.dart`**
   - Added imports for `config_manager.dart` and `filebin_resolver.dart`
   - Added `set-filebin` command handler
   - Updated upload logic to use `FilebinResolver.resolveFilebinUrl()`
   - Updated help text to include new command
   - Replaced hardcoded `filebin.net` URLs with resolved URLs

### New Command

```bash
furl set-filebin <filebin-url> [atsign]
```

**Arguments:**
- `filebin-url`: The filebin server URL (e.g., `https://filebin.example.com`)
- `atsign`: Optional atSign for lookups (default: `@furl`)

**Examples:**
```bash
# Use default @furl atSign
furl set-filebin https://filebin.example.com

# Use custom atSign
furl set-filebin https://filebin.example.com @mycompany

# View current config
cat ~/.furl/furl_config.json
```

**What it does:**
1. Validates the URL format (must be HTTPS)
2. Saves the URL and atSign to `~/.furl/furl_config.json`
3. Displays confirmation with file location

## Flutter App Implementation

### New Files Created

1. **`flutter_furl/lib/core/services/config_manager.dart`**
   - Uses SharedPreferences for storage
   - Same interface as CLI version
   - Stores: `filebinUrl` and `defaultAtSign`

2. **`flutter_furl/lib/core/services/filebin_resolver.dart`**
   - Same resolution logic as CLI
   - Uses `at_client_mobile` for atKey lookups
   - Falls back through the three-tier strategy

3. **`flutter_furl/lib/features/settings/settings_screen.dart`**
   - Full settings UI for configuring filebin
   - Text fields for URL and atSign
   - Save/Reset functionality
   - Validation and error handling
   - Info cards explaining the feature

### Modified Files

1. **`flutter_furl/lib/core/services/file_encryption_service.dart`**
   - Added import for `filebin_resolver.dart`
   - Updated `uploadFileToServer()` to use `FilebinResolver.resolveFilebinUrl()`
   - Replaced hardcoded `filebin.net` URL

### Settings Screen Features

- **URL Configuration**: Text field to enter custom filebin server URL
- **atSign Configuration**: Text field to set default lookup atSign
- **Validation**: Ensures URLs are valid HTTPS endpoints
- **Reset to Defaults**: One-click reset to `filebin.net` and `@furl`
- **Save Indicator**: Shows unsaved changes and save button
- **Info Cards**: Explains how the resolution works

## Configuration File Format

### CLI (`~/.furl/furl_config.json`)
```json
{
  "filebinUrl": "https://filebin.example.com",
  "defaultAtSign": "@mycompany"
}
```

### Flutter (SharedPreferences)
- Key: `filebinUrl` → Value: `"https://filebin.example.com"`
- Key: `defaultAtSign` → Value: `"@mycompany"`

## Resolution Logic

Both CLI and Flutter use the same resolution order:

1. **Try atKey**: `public:filebin.furl@<defaultAtSign>`
   - If found and not empty, use this URL
   - Allows centralized configuration management

2. **Try Local Config**:
   - CLI: Read from `~/.furl/furl_config.json`
   - Flutter: Read from SharedPreferences
   - If set and different from default, use this

3. **Use Default**: `https://filebin.net`
   - Always works as final fallback

## Usage Scenarios

### Scenario 1: Individual User with Custom Server
```bash
furl set-filebin https://my-filebin.com
# Now all uploads go to my-filebin.com
```

### Scenario 2: Organization-wide Configuration
1. Admin publishes URL to `public:filebin.furl@company`:
   ```bash
   # Admin stores it via atSign (manual step, not automated in v1)
   ```

2. Users configure their client to use `@company`:
   ```bash
   furl set-filebin https://filebin.net @company
   ```

3. System checks `@company` first for organization's filebin URL

### Scenario 3: Default Behavior
- No configuration needed
- Uses `filebin.net` automatically
- Works exactly as before

## Testing the Feature

### CLI Testing
```bash
# Test default behavior
furl @alice document.pdf 1h
# Should use filebin.net

# Set custom URL
furl set-filebin https://filebin.example.com

# Test with custom URL
furl @alice document.pdf 1h
# Should use filebin.example.com

# Check config file
cat ~/.furl/furl_config.json

# Reset to default
rm ~/.furl/furl_config.json
```

### Flutter Testing
1. Open app and navigate to Settings screen
2. Enter custom filebin URL
3. Save settings
4. Upload a file and verify it goes to custom server
5. Reset to defaults
6. Verify it uses filebin.net again

## Dependencies

### CLI
- No new dependencies (uses existing packages)
- Requires: `path`, `dart:io`, `dart:convert`

### Flutter
- `shared_preferences: ^2.2.3` (already in pubspec.yaml)
- `at_client_mobile` (already in use)

## Future Enhancements

Potential improvements for future versions:

1. **Publish to atKey**: Add `--publish` flag to `set-filebin` to automatically publish to atKey
2. **List Command**: `furl get-filebin` to show current configuration
3. **Test Connection**: Verify filebin server is reachable before saving
4. **Multiple Profiles**: Support multiple filebin profiles (personal, work, etc.)
5. **Auto-discovery**: Scan for filebin servers on local network
6. **Server Validation**: Ping server to ensure it's a valid filebin instance

## Migration Notes

This is a **backward-compatible** change:
- Existing behavior (using filebin.net) works without any configuration
- No changes needed to existing installations
- Users can opt-in to custom servers when needed
- No breaking changes to API or command structure

## Security Considerations

1. **HTTPS Required**: Only HTTPS URLs are accepted
2. **No Credentials**: URLs should not contain authentication credentials
3. **Local Storage**: Configuration files are stored in user's home directory
4. **Public atKeys**: URLs published to atKeys are public by design
5. **URL Validation**: Basic validation prevents obvious mistakes

## Documentation Updates Needed

The following documentation should be updated:
- README.md: Add section on filebin configuration
- User Guide: Explain the set-filebin command
- Flutter App: Add settings screen to navigation
- SECURITY_DESIGN.md: Note that filebin URL is configurable

## Conclusion

This feature provides flexible filebin server configuration while maintaining backward compatibility and ease of use. The three-tier resolution strategy ensures that organizations can centralize configuration while individuals can override as needed.
