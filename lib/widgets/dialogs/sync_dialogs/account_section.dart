import 'package:flutter/material.dart';
import '../../../services/sync_service.dart';

class AccountSection extends StatelessWidget {
  final SyncService syncService;

  const AccountSection({super.key, required this.syncService});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.account_circle, size: 32, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                syncService.currentUserEmail ?? 'Signed in',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const Text(
                'Cloud sync account',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: syncService.signOut,
          child: const Text('Sign Out'),
        ),
      ],
    );
  }
}
