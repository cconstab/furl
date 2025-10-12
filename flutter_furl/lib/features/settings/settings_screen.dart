import 'package:flutter/material.dart';
import '../../core/services/config_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _filebinController = TextEditingController();
  final _atSignController = TextEditingController();
  bool _isLoading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _filebinController.dispose();
    _atSignController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    // Load current settings from atKey
    final privateConfig = await ConfigManager.getPrivateOverride();

    setState(() {
      _filebinController.text = privateConfig?['url'] ?? ConfigManager.defaultFilebinUrl;
      _atSignController.text = privateConfig?['config_atsign'] ?? ConfigManager.defaultConfigAtSign;
      _isLoading = false;
    });

    // Add listeners to detect changes
    _filebinController.addListener(() => setState(() => _hasChanges = true));
    _atSignController.addListener(() => setState(() => _hasChanges = true));
  }

  Future<void> _saveSettings() async {
    // Validate URL
    if (_filebinController.text.isNotEmpty) {
      try {
        final uri = Uri.parse(_filebinController.text);
        if (!uri.scheme.startsWith('http')) {
          _showError('Invalid URL: Must start with https://');
          return;
        }
      } catch (e) {
        _showError('Invalid URL format');
        return;
      }
    }

    // Validate atSign
    var configAtSign = _atSignController.text.trim();
    if (configAtSign.isNotEmpty && !configAtSign.startsWith('@')) {
      configAtSign = '@$configAtSign';
      _atSignController.text = configAtSign;
    }

    try {
      // Store in private atKey
      await ConfigManager.setPrivateOverride(
        _filebinController.text,
        configAtSign,
      );

      setState(() => _hasChanges = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Settings saved to atKey successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to save settings: $e');
    }
  }

  Future<void> _resetToDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text('Are you sure you want to reset all settings to default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Clear the private override atKey
        await ConfigManager.clearPrivateOverride();

        setState(() {
          _filebinController.text = ConfigManager.defaultFilebinUrl;
          _atSignController.text = ConfigManager.defaultConfigAtSign;
          _hasChanges = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Settings reset to defaults'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        _showError('Failed to reset settings: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Filebin Settings'),
        actions: [
          if (_hasChanges)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save Settings',
              onPressed: _saveSettings,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset to Defaults',
            onPressed: _resetToDefaults,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filebin Configuration',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Configure where files are uploaded and stored',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),

            // Filebin URL Field
            TextField(
              controller: _filebinController,
              decoration: const InputDecoration(
                labelText: 'Filebin Server URL',
                hintText: 'https://filebin.net',
                helperText: 'The server URL where files will be uploaded',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.cloud_upload),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),

            // Default atSign Field
            TextField(
              controller: _atSignController,
              decoration: const InputDecoration(
                labelText: 'Default atSign',
                hintText: '@furl',
                helperText: 'The atSign to check for filebin URL configuration',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: 24),

            // Info Card
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'How it works',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The app will check public:filebin.furl@<atsign> first, then fall back to this local configuration.\n\n'
                      'This allows organizations to centrally configure the filebin URL by publishing it to an atSign.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Current Config Display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Configuration',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Divider(),
                    _buildConfigRow('Filebin URL', _filebinController.text),
                    _buildConfigRow('Default atSign', _atSignController.text),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _hasChanges
          ? FloatingActionButton.extended(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save),
              label: const Text('Save Changes'),
            )
          : null,
    );
  }

  Widget _buildConfigRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '(not set)' : value,
              style: TextStyle(
                color: value.isEmpty ? Colors.grey : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
