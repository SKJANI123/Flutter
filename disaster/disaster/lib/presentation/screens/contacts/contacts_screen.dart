import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:disaster/domain/entities/emergency_contact.dart';
import 'package:disaster/presentation/providers/contacts_controller.dart';
import 'package:disaster/presentation/screens/contacts/contact_edit_screen.dart';
import 'package:disaster/presentation/theme/app_theme.dart';
import 'package:disaster/presentation/widgets/common.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ContactsController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add contact',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ContactEditScreen()),
            ),
          ),
        ],
      ),
      body: _buildBody(context, ctrl),
    );
  }

  Widget _buildBody(BuildContext context, ContactsController ctrl) {
    if (ctrl.loading) return const Center(child: CircularProgressIndicator());
    if (ctrl.error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load contacts',
      );
    }
    if (ctrl.contacts.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline,
        title: 'No emergency contacts',
        subtitle:
            'Add family, friends or local services so SOS can reach them.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => ctrl.load(),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: ctrl.contacts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final c = ctrl.contacts[i];
          return _ContactTile(contact: c, listTile: true);
        },
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, this.listTile = false});
  final EmergencyContact contact;
  final bool listTile;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<ContactsController>();
    final tile = Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
          child: Text(
            contact.name.isEmpty ? '?' : contact.name[0].toUpperCase(),
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                contact.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (contact.isPrimary) ...[
              const SizedBox(width: 6),
              const Icon(Icons.star, color: AppTheme.warningA, size: 16),
            ],
          ],
        ),
        subtitle: Text(
          '${contact.phone}${contact.relationship == null ? '' : ' · ${contact.relationship}'}',
        ),
        isThreeLine: false,
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            switch (v) {
              case 'edit':
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ContactEditScreen(contact: contact),
                  ),
                );
              case 'primary':
                ctrl.setPrimary(contact);
              case 'delete':
                ctrl.remove(contact.id);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'primary', child: Text('Set primary')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
    if (!listTile) return tile;
    return tile;
  }
}
