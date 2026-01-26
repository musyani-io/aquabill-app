import 'package:flutter/material.dart';

/// Conflicts UI: list conflicts and allow simple resolution actions.
class ConflictsScreen extends StatelessWidget {
  const ConflictsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Placeholder conflicts until wired to DAO
    final conflicts = List.generate(
      3,
      (i) => {
        'id': i + 1,
        'client': 'Client ${i + 1}',
        'local': 120 + i * 5,
        'server': 110 + i * 5,
      },
    );

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (_, index) {
        final item = conflicts[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text('${item['id']}')),
            title: Text(item['client'] as String),
            subtitle: Text(
              'Local: ${item['local']}  •  Server: ${item['server']}',
            ),
            trailing: Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Accepted server for #${item['id']} (stub)')),
                    );
                  },
                  child: const Text('Accept server'),
                ),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Resubmit for #${item['id']} (stub)')),
                    );
                  },
                  child: const Text('Resubmit'),
                ),
              ],
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: conflicts.length,
    );
  }
}
