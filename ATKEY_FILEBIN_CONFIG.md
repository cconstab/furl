# atKey-Based Filebin Configuration - Implementation Summary

## What Changed

The filebin configuration system now uses **atKeys** instead of local files, making it truly cloud-native and device-independent.

## Architecture

### Resolution Order
```
1. private:filebin_override.furl@myatsign  (Personal config - highest priority)
   ↓ (if not found)
2. public:filebin.furl@furl                (Default org config)
   or public:filebin.furl@configatsign     (Custom org config)
   ↓ (if not found)
3. https://filebin.net                     (Hardcoded default)
```

### atKey Structure

**Private Override (Personal Config):**
- Key: `private:filebin_override.furl@myatsign`
- Value: `https://my-filebin.com|@mycompany`
- Format: `<url>|<config_atsign>`
- Purpose: Personal filebin preference + which org config to check
- Namespace: `.furl`

**Public Config (Organization-wide):**
- Key: `public:filebin.furl@furl` (default) or `public:filebin.furl@orgatsign`
- Value: `https://company-filebin.example.com`
- Format: Just the URL string
- Purpose: Org-wide filebin server that all employees can discover
- Namespace: `.furl`

## CLI Commands

### Set Personal Config
```bash
# Set your personal filebin override
furl set-filebin @alice https://my-filebin.com

# Set personal override AND configure which org to check for public config
furl set-filebin @alice https://my-filebin.com @mycompany
```

**What it does:**
1. Stores in `private:filebin_override.furl@alice`
2. Value: `https://my-filebin.com|@mycompany`
3. Your uploads will use `https://my-filebin.com`
4. If you clear your override, it will check `public:filebin.furl@mycompany`

### Publish Org-Wide Config (Admins)
```bash
# Publish a filebin URL for your whole organization
furl publish-filebin @mycompany https://company-filebin.example.com
```

**What it does:**
1. Stores in `public:filebin.furl@mycompany` (public = anyone can read)
2. Value: `https://company-filebin.example.com`
3. Anyone who configures their client to check `@mycompany` will use this URL

## Usage Scenarios

### Scenario 1: Default Behavior (No Configuration)
```bash
furl @alice document.pdf 1h
# Uses: https://filebin.net (default)
```

### Scenario 2: Personal filebin Server
```bash
# Alice sets her personal filebin
furl set-filebin @alice https://alice-filebin.net

# Now when she uploads
furl @alice document.pdf 1h
# Uses: https://alice-filebin.net (from her private override)
```

### Scenario 3: Organization Deployment
```
1. Admin publishes org filebin:
   $ furl publish-filebin @acmecorp https://filebin.acme.com

2. Employee configures their client:
   $ furl set-filebin @alice https://filebin.net @acmecorp
   (Uses default but checks @acmecorp for fallback)

3. Employee uploads:
   $ furl @alice document.pdf 1h
   Uses: https://filebin.net (from their private setting)

4. Employee clears their override:
   $ furl set-filebin @alice @acmecorp
   (No URL = clear override, keep config atsign)

5. Employee uploads again:
   $ furl @alice document.pdf 1h
   Uses: https://filebin.acme.com (from @acmecorp public config)
```

### Scenario 4: Mixed Personal + Org Config
```bash
# Alice works at AcmeCorp but wants to use her own filebin
# while keeping the company fallback

# 1. Company admin publishes org config
furl publish-filebin @acmecorp https://filebin.acme.com

# 2. Alice sets personal override with company fallback
furl set-filebin @alice https://alice-personal.net @acmecorp

# 3. Alice uploads (uses her personal server)
furl @alice doc1.pdf 1h
# Uses: https://alice-personal.net

# 4. Later, Alice removes her personal override
furl set-filebin @alice https://filebin.net @acmecorp

# 5. Alice uploads (now uses company server)
furl @alice doc2.pdf 1h
# Uses: https://filebin.acme.com (from @acmecorp)
```

## Flutter App

### Settings Screen
- Navigate to Settings from the app menu
- Configure:
  - **Filebin URL**: Your personal filebin server
  - **Config atSign**: Which atSign to check for public config
- Click Save to store in `private:filebin_override.furl@youratsign`
- Click Reset to clear your override and use defaults

### How It Works
1. Settings are stored in your private atKey (encrypted, device-independent)
2. Configuration syncs automatically across all your devices
3. Same resolution order as CLI

## Implementation Files

### CLI
- **lib/config_manager.dart**: atKey read/write operations
- **lib/filebin_resolver.dart**: Resolution logic
- **bin/furl.dart**: Commands and upload logic

### Flutter
- **flutter_furl/lib/core/services/config_manager.dart**: atKey operations
- **flutter_furl/lib/core/services/filebin_resolver.dart**: Resolution logic
- **flutter_furl/lib/features/settings/settings_screen.dart**: Settings UI
- **flutter_furl/lib/core/services/file_encryption_service.dart**: Upload with resolver

## Technical Details

### atKey Format (Private Override)
```
Key: filebin_override.furl@myatsign
Namespace: furl
Type: Private (encrypted)
Value: <filebin_url>|<config_atsign>
Example: https://my-filebin.com|@mycompany
```

### atKey Format (Public Config)
```
Key: filebin.furl@orgatsign
Namespace: furl
Type: Public (anyone can read)
Metadata: isPublic = true
Value: <filebin_url>
Example: https://company-filebin.example.com
```

### Code Flow (Upload)
```dart
1. Get AtClient (authenticate user)
2. Call FilebinResolver.resolveFilebinUrl(atClient)
   a. Check private:filebin_override.furl@myatsign
   b. If not found, extract config_atsign from override (or use @furl)
   c. Check public:filebin.furl@config_atsign
   d. If not found, return https://filebin.net
3. Use resolved URL for upload
```

## Benefits Over Local Files

### Before (Local Files)
- ❌ Config stored in ~/.furl/furl_config.json
- ❌ Device-specific (not synced)
- ❌ Manual backup/restore needed
- ❌ Inconsistent across devices
- ❌ Not atPlatform-native

### After (atKeys)
- ✅ Config stored in encrypted atKeys
- ✅ Automatically synced across devices
- ✅ No backup needed (atPlatform handles it)
- ✅ Consistent everywhere
- ✅ Native atPlatform integration
- ✅ Organization-friendly (public configs)

## Migration Path

### Backward Compatibility
- No breaking changes - defaults to filebin.net if no config exists
- Users can start using new commands immediately
- No migration script needed

### Adoption Strategy
1. **Individual users**: Start using `furl set-filebin` to set personal preferences
2. **Organizations**: Admin publishes with `furl publish-filebin`
3. **Employees**: Configure clients to check org's public config
4. **Gradual rollout**: Works alongside default behavior

## Testing

### CLI Testing
```bash
# Test 1: Default behavior (no config)
furl @alice test.txt 1h
# Should use filebin.net

# Test 2: Set personal override
furl set-filebin @alice https://test-filebin.com
furl @alice test.txt 1h
# Should use test-filebin.com

# Test 3: Publish org config
furl publish-filebin @testorg https://org-filebin.com

# Test 4: Use org config (no personal override)
furl set-filebin @alice https://filebin.net @testorg
# (Clear personal, keep org check)
furl @alice test.txt 1h
# Should use org-filebin.com from @testorg

# Test 5: Verify atKeys exist
# Check private:filebin_override.furl@alice
# Check public:filebin.furl@testorg
```

### Flutter Testing
1. Open Settings screen
2. Enter custom filebin URL and config atSign
3. Save
4. Upload a file
5. Verify it uses custom filebin
6. Reset settings
7. Upload again
8. Verify it uses default or public config

## Security Considerations

1. **Private Overrides**: Encrypted by atPlatform (only you can read)
2. **Public Configs**: Publicly readable by design (org-wide)
3. **URL Validation**: Both CLI and Flutter validate HTTPS URLs
4. **No Credentials in URLs**: URLs should not contain auth credentials
5. **atKey Permissions**: Private keys require authentication

## Future Enhancements

1. **CLI command to show current config**: `furl show-config`
2. **Test filebin connectivity**: `furl test-filebin <url>`
3. **List available org configs**: `furl list-filebin-servers`
4. **Export/import configs**: For backup/sharing
5. **Multiple named profiles**: Switch between different filebin servers

## Summary

The atKey-based filebin configuration makes furl truly cloud-native:
- Configuration lives in the atPlatform (not local files)
- Automatically syncs across all your devices
- Supports both personal and organization-wide configuration
- Seamlessly integrates with existing atKey infrastructure
- Maintains backward compatibility with default behavior

This is the proper atPlatform way to handle configuration! 🎯
