import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/iban_validator.dart';
import '../../groups/application/group_providers.dart';

/// Opens the bottom sheet for editing the display name and the IBAN.
Future<void> showProfileSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _ProfileSheet(),
  );
}

class _ProfileSheet extends ConsumerStatefulWidget {
  const _ProfileSheet();

  @override
  ConsumerState<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends ConsumerState<_ProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ibanController = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ref.read(profileProvider.future);
    final iban = await ref.read(ibanProvider.future);
    if (!mounted) return;
    setState(() {
      _nameController.text = profile?.name ?? '';
      _ibanController.text = iban ?? '';
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ibanController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await ref.read(groupActionsProvider).saveProfile(
          name: _nameController.text.trim(),
          iban: IbanValidator.normalize(_ibanController.text),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profil a platby',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              enabled: _loaded,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Vaše jméno',
                helperText: 'Takto vás uvidí ostatní ve skupinách',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Zadejte jméno' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ibanController,
              enabled: _loaded,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Váš IBAN (pro příjem plateb přes QR)',
                hintText: 'CZ65 0800 0000 1920 0014 5399',
                helperText: 'Uloženo pouze v tomto zařízení',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return null; // IBAN is optional
                return IbanValidator.isValid(text)
                    ? null
                    : 'IBAN není platný, zkontrolujte ho';
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loaded && !_saving ? _save : null,
                child: const Text('Uložit změny'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
