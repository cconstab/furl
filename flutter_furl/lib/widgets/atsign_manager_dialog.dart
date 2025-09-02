import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_furl/features/onboarding/cubit/onboarding_cubit.dart';

class AtSignManagerDialog extends StatefulWidget {
  const AtSignManagerDialog({super.key});

  @override
  State<AtSignManagerDialog> createState() => _AtSignManagerDialogState();
}

class _AtSignManagerDialogState extends State<AtSignManagerDialog> {
  List<String> _storedAtSigns = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStoredAtSigns();
  }

  Future<void> _loadStoredAtSigns() async {
    try {
      final atSigns = await context.read<OnboardingCubit>().getStoredAtSigns();
      setState(() {
        _storedAtSigns = atSigns;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading atSigns: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _switchToAtSign(String atSign) async {
    Navigator.of(context).pop();
    await context.read<OnboardingCubit>().switchAtSign(atSign);
  }

  Future<void> _removeAtSign(String atSign) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove atSign'),
        content: Text(
            'Are you sure you want to remove $atSign?\n\nThis will delete all local data for this atSign including authentication keys.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removing $atSign...'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      try {
        await context.read<OnboardingCubit>().removeAtSign(atSign);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully removed $atSign'),
              backgroundColor: Colors.green,
            ),
          );
        }

        _loadStoredAtSigns();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove $atSign: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _clearAllAtSigns() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All atSigns'),
        content: const Text(
            'Are you sure you want to remove ALL atSigns?\n\nThis will delete all local data and log you out.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      Navigator.of(context).pop(); // Close the main dialog
      await context.read<OnboardingCubit>().clearAllAtSigns();
    }
  }

  Future<void> _addNewAtSign() async {
    Navigator.of(context).pop(); // Close the dialog
    await context.read<OnboardingCubit>().addNewAtSignWithoutSwitching(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.account_circle, color: Color(0xFF667eea)),
          SizedBox(width: 8),
          Text('Manage atSigns'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_storedAtSigns.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No atSigns stored',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...List.generate(_storedAtSigns.length, (index) {
                final atSign = _storedAtSigns[index];
                return BlocBuilder<OnboardingCubit, OnboardingState>(
                  builder: (context, state) {
                    final isCurrentAtSign = state is OnboardingCompleted && state.atSign == atSign;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCurrentAtSign ? const Color(0xFF667eea) : Colors.grey[300],
                          child: Text(
                            atSign.substring(1, 2).toUpperCase(),
                            style: TextStyle(
                              color: isCurrentAtSign ? Colors.white : Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          atSign,
                          style: TextStyle(
                            fontWeight: isCurrentAtSign ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: isCurrentAtSign ? const Text('Current atSign') : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isCurrentAtSign)
                              IconButton(
                                icon: const Icon(Icons.switch_account, color: Color(0xFF667eea)),
                                onPressed: () => _switchToAtSign(atSign),
                                tooltip: 'Switch to this atSign',
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeAtSign(atSign),
                              tooltip: 'Remove this atSign',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
          ],
        ),
      ),
      actions: [
        if (_storedAtSigns.isNotEmpty)
          TextButton(
            onPressed: _clearAllAtSigns,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: _addNewAtSign,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF667eea),
            foregroundColor: Colors.white,
          ),
          child: const Text('Add New atSign'),
        ),
      ],
    );
  }
}
