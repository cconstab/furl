/// Validation utilities for furl CLI arguments
library validation;

/// Validate atSign format
/// Returns true if the atSign is valid, false otherwise
bool validateAtSign(String atSign) {
  // Must start with @
  if (!atSign.startsWith('@')) {
    return false;
  }
  
  // Must have content after @
  if (atSign.length <= 1) {
    return false;
  }
  
  // Should only have one @
  if (atSign.indexOf('@', 1) != -1) {
    return false;
  }
  
  // Extract username part (after @)
  final username = atSign.substring(1);
  
  // Username validation: alphanumeric, dots, hyphens, underscores
  // But cannot start or end with dot, hyphen, or underscore
  final validUsernameRegex = RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9._-]*[a-zA-Z0-9])?$');
  
  return validUsernameRegex.hasMatch(username);
}
