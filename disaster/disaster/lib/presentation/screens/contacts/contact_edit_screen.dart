import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:disaster/domain/entities/emergency_contact.dart';
import 'package:disaster/presentation/providers/contacts_controller.dart';

class ContactEditScreen extends StatefulWidget {
  const ContactEditScreen({super.key, this.contact});

  final EmergencyContact? contact;

  @override
  State<ContactEditScreen> createState() => _ContactEditScreenState();
}

class _ContactEditScreenState extends State<ContactEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _relationship;
  late bool _isPrimary;

  bool get _isEdit => widget.contact != null;

  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    _name = TextEditingController(text: c?.name ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _relationship = TextEditingController(text: c?.relationship ?? '');
    _isPrimary = c?.isPrimary ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _relationship.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ctrl = context.read<ContactsController>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (_isEdit) {
      await ctrl.update(
        widget.contact!.copyWith(
          name: _name.text.trim(),
          phone: _phone.text.trim(),
          relationship: _relationship.text.trim().isEmpty
              ? null
              : _relationship.text.trim(),
          isPrimary: _isPrimary,
        ),
      );
    } else {
      await ctrl.add(
        name: _name.text,
        phone: _phone.text,
        relationship: _relationship.text.trim().isEmpty
            ? null
            : _relationship.text.trim(),
        isPrimary: _isPrimary,
      );
    }
    messenger.showSnackBar(
      SnackBar(content: Text(_isEdit ? 'Contact updated.' : 'Contact added.')),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Contact' : 'New Contact')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Mom, Dr. Sharma',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: 'e.g. +91 98765 43210',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter a phone number';
                }
                final digits = v.replaceAll(RegExp(r'\D'), '');
                if (digits.length < 7) return 'Enter a valid phone number';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _relationship,
              decoration: const InputDecoration(
                labelText: 'Relationship (optional)',
                hintText: 'Family, Friend, Local authority…',
                prefixIcon: Icon(Icons.favorite_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _isPrimary,
              onChanged: (v) => setState(() => _isPrimary = v),
              title: const Text('Primary contact'),
              subtitle: const Text('Used by SOS when no contact is selected'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(_isEdit ? 'Save changes' : 'Add contact'),
            ),
          ],
        ),
      ),
    );
  }
}
