import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:disaster/domain/entities/emergency_contact.dart';
import 'package:disaster/domain/entities/sos_event.dart';
import 'package:disaster/presentation/providers/sos_controller.dart';
import 'package:disaster/presentation/theme/app_theme.dart';

class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SOS')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SosExplainer(),
          const SizedBox(height: 16),
          _SosButton(),
          const SizedBox(height: 20),
          FutureBuilder<List<EmergencyContact>>(
            future: context.read<SosController>().loadContacts(),
            builder: (context, snap) {
              if (!snap.hasData || snap.data!.isEmpty) {
                return const _MissingContacts();
              }
              return _ContactPicker(contacts: snap.data!);
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Recent SOS',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const _History(),
        ],
      ),
    );
  }
}

class _SosExplainer extends StatelessWidget {
  const _SosExplainer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.danger),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tap the panic button below to send your live GPS location to your '
              'emergency contacts and raise an alert. Works offline — the alert is '
              'queued and delivered when you are back online.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _SosButton extends StatelessWidget {
  const _SosButton();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SosController>();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8C1D18), AppTheme.danger],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.danger.withValues(alpha: 0.4),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'EMERGENCY',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: ctrl.dispatching ? null : () => _dispatch(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.danger,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Icon(
                  ctrl.dispatching ? Icons.hourglass_top : Icons.sos,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            ctrl.dispatching ? 'Sending your location…' : 'Tap to send SOS',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (ctrl.hasSelection)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Will alert ${ctrl.selectedContacts.length} contact(s)',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          if (ctrl.lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Could not get GPS fix — ensure location permission.',
                style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _dispatch(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = context.read<SosController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send SOS?'),
        content: const Text(
          'This shares your live location with your emergency contacts now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final event = await controller.dispatch();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          event == null
              ? 'SOS failed — try again.'
              : 'SOS dispatched. Stay safe.',
        ),
      ),
    );
  }
}

class _MissingContacts extends StatelessWidget {
  const _MissingContacts();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No emergency contacts yet. Add contacts in the Contacts tab so they can receive your SOS.',
          style: TextStyle(fontSize: 13),
        ),
      ),
    );
  }
}

class _ContactPicker extends StatelessWidget {
  const _ContactPicker({required this.contacts});
  final List<EmergencyContact> contacts;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SosController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text(
            'Notify contacts',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        ...contacts.map(
          (c) => CheckboxListTile(
            value: ctrl.selectedContacts.any((s) => s.id == c.id),
            onChanged: (v) => ctrl.selectContact(c, v ?? false),
            title: Text(c.name),
            subtitle: Text(c.phone),
            secondary: Icon(
              c.isPrimary ? Icons.star : Icons.person_outline,
              color: c.isPrimary ? AppTheme.warningA : null,
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

class _History extends StatelessWidget {
  const _History();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SosController>();
    if (ctrl.history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No SOS sent yet.', style: TextStyle(color: Colors.grey)),
      );
    }
    return Column(
      children: [
        for (final e in ctrl.history)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: _statusColor(e.status).withValues(alpha: 0.15),
              child: Icon(Icons.sos, color: _statusColor(e.status), size: 18),
            ),
            title: Text(
              '${e.latitude.toStringAsFixed(4)}, ${e.longitude.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              e.capturedAt?.toLocal().toString().substring(0, 16) ?? '',
            ),
            trailing: e.needsSync
                ? TextButton(
                    onPressed: () => ctrl.retrySync(e.id),
                    child: const Text('Retry'),
                  )
                : Text(
                    e.status.name.toUpperCase(),
                    style: TextStyle(
                      color: _statusColor(e.status),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
      ],
    );
  }

  Color _statusColor(SosStatus status) => switch (status) {
    SosStatus.sent || SosStatus.delivered => AppTheme.safe,
    SosStatus.queued || SosStatus.pending => AppTheme.warningA,
    SosStatus.failed => AppTheme.danger,
  };
}
