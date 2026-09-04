import 'package:flutter/material.dart';
import '../../core/services/trusted_contacts_service.dart';
import '../../core/theme/app_theme.dart';

class TrustedContactsScreen extends StatefulWidget {
  const TrustedContactsScreen({super.key});

  @override
  State<TrustedContactsScreen> createState() => _TrustedContactsScreenState();
}

class _TrustedContactsScreenState extends State<TrustedContactsScreen> {
  List<TrustedContact> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final contacts = await TrustedContactsService.load();
    if (mounted) setState(() { _contacts = contacts; _loading = false; });
  }

  Future<void> _save() async {
    await TrustedContactsService.save(_contacts);
  }

  void _addContact() {
    if (_contacts.length >= TrustedContactsService.maxContacts) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 trusted contacts allowed.')),
      );
      return;
    }
    _showContactSheet(null);
  }

  void _editContact(int index) => _showContactSheet(index);

  void _deleteContact(int index) {
    setState(() => _contacts.removeAt(index));
    _save();
  }

  void _showContactSheet(int? editIndex) {
    final existing = editIndex != null ? _contacts[editIndex] : null;
    final nameCtr = TextEditingController(text: existing?.name ?? '');
    final phoneCtr = TextEditingController(text: existing?.phone ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: SRColors.border,
                    borderRadius: BorderRadius.circular(99)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              editIndex != null ? 'Edit contact' : 'Add trusted contact',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: SRColors.ink900),
            ),
            const SizedBox(height: 16),
            _buildField('Full name', nameCtr, TextInputType.name),
            const SizedBox(height: 12),
            _buildField('Phone number', phoneCtr, TextInputType.phone),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SRColors.purple700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(99)),
                ),
                onPressed: () {
                  final name = nameCtr.text.trim();
                  final phone = phoneCtr.text.trim();
                  if (name.isEmpty || phone.isEmpty) return;
                  setState(() {
                    if (editIndex != null) {
                      _contacts[editIndex] = TrustedContact(name: name, phone: phone);
                    } else {
                      _contacts.add(TrustedContact(name: name, phone: phone));
                    }
                  });
                  _save();
                  Navigator.pop(context);
                },
                child: Text(editIndex != null ? 'Save changes' : 'Add contact'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctr, TextInputType type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: SRColors.ink700)),
        const SizedBox(height: 6),
        TextField(
          controller: ctr,
          keyboardType: type,
          decoration: InputDecoration(
            hintText: type == TextInputType.phone ? '08012345678' : 'e.g. Amaka Obi',
            hintStyle: const TextStyle(color: SRColors.ink500),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: SRColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: SRColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: SRColors.purple700, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SRColors.lavenderBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_rounded, color: SRColors.ink900),
        ),
        title: const Text(
          'Trusted Contacts',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700, color: SRColors.ink900),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: SRColors.purple700))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: SRColors.purple100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: SRColors.purple700, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'These contacts receive an alert when you trigger SOS. Add up to 5.',
                            style: TextStyle(
                                fontSize: 12, color: SRColors.purple700, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _contacts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people_outline_rounded,
                                  size: 48, color: SRColors.ink500.withValues(alpha: 0.4)),
                              const SizedBox(height: 12),
                              const Text('No trusted contacts yet',
                                  style: TextStyle(color: SRColors.ink500, fontSize: 14)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          itemCount: _contacts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final c = _contacts[i];
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: SRColors.border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: const BoxDecoration(
                                      color: SRColors.purple100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                        style: const TextStyle(
                                            color: SRColors.purple700,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c.name,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: SRColors.ink900)),
                                        Text(c.phone,
                                            style: const TextStyle(
                                                fontSize: 12, color: SRColors.ink500)),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _editContact(i),
                                    child: const Icon(Icons.edit_rounded,
                                        color: SRColors.purple700, size: 18),
                                  ),
                                  const SizedBox(width: 14),
                                  GestureDetector(
                                    onTap: () => _deleteContact(i),
                                    child: const Icon(Icons.delete_outline_rounded,
                                        color: SRColors.coral500, size: 18),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _addContact,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(
                          'Add contact (${_contacts.length}/${TrustedContactsService.maxContacts})'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SRColors.purple700,
                        side: const BorderSide(color: SRColors.purple700),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
