import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/session_service.dart';
import '../../core/services/background_poll_service.dart';
import '../../core/api/ride_api.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _walletBalance = 0;
  int _totalTrips = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final profile = SessionService.instance.profile;
    if (profile == null) return;

    try {
      final walletRes = await RideApi.instance.getWalletStatus(profile.phone);
      final bal = walletRes['ToBalance'] ?? walletRes['TotalBalance'] ?? '0';
      final parsed = double.tryParse(bal.toString()) ?? 0;
      if (mounted) setState(() => _walletBalance = parsed.toInt());
    } catch (_) {
      final fromProfile = double.tryParse(profile.walletBalance) ?? 0;
      if (mounted) setState(() => _walletBalance = fromProfile.toInt());
    }

    try {
      final histRes = await RideApi.instance.getPaymentHistory(profile.phone);
      final total = histRes['TotalTransactions'] ?? 0;
      if (mounted) setState(() => _totalTrips = int.tryParse(total.toString()) ?? 0);
    } catch (_) {}
  }

  String _fmtBalance(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Future<void> _openEditSheet() async {
    final profile = SessionService.instance.profile;
    if (profile == null) return;

    final isDriver = SessionService.instance.isDriver;

    final firstCtrl = TextEditingController(text: profile.firstName);
    final surnameCtrl = TextEditingController(text: profile.surname);
    final emailCtrl = TextEditingController(text: profile.email);
    final cityCtrl = TextEditingController(text: profile.city);
    final phoneCtrl = TextEditingController(text: profile.phone);
    final bankCtrl = TextEditingController(text: profile.bankno);
    final vTypeCtrl = TextEditingController(text: profile.vType);
    final vMakeCtrl = TextEditingController(text: profile.vMake);
    final vModelCtrl = TextEditingController(text: profile.vModel);
    final vYearCtrl = TextEditingController(text: profile.vYear);
    final vColorCtrl = TextEditingController(text: profile.vColor);

    XFile? pickedImage;
    bool saving = false;
    String? errorMsg;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> pickImage(ImageSource source) async {
            final picker = ImagePicker();
            final img = await picker.pickImage(
              source: source,
              imageQuality: 80,
              maxWidth: 800,
            );
            if (img != null) setSheet(() => pickedImage = img);
          }

          void showImageOptions() {
            showModalBottomSheet(
              context: ctx,
              backgroundColor: Colors.transparent,
              builder: (_) => Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: SRColors.border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: Container(
                          width: 40, height: 40,
                          decoration: const BoxDecoration(
                            color: SRColors.lavenderBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              color: SRColors.purple700, size: 20),
                        ),
                        title: const Text('Take a photo',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        onTap: () {
                          Navigator.pop(ctx);
                          pickImage(ImageSource.camera);
                        },
                      ),
                      ListTile(
                        leading: Container(
                          width: 40, height: 40,
                          decoration: const BoxDecoration(
                            color: SRColors.lavenderBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.photo_library_rounded,
                              color: SRColors.purple700, size: 20),
                        ),
                        title: const Text('Choose from gallery',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        onTap: () {
                          Navigator.pop(ctx);
                          pickImage(ImageSource.gallery);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          }

          Future<void> save() async {
            setSheet(() {
              saving = true;
              errorMsg = null;
            });
            try {
              await RideApi.instance.updateProfile(
                phone: phoneCtrl.text.trim(),
                firstName: firstCtrl.text.trim(),
                surname: surnameCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                city: cityCtrl.text.trim(),
                isDriver: isDriver,
                bankno: bankCtrl.text.trim(),
                vType: isDriver ? vTypeCtrl.text.trim() : '',
                vMake: isDriver ? vMakeCtrl.text.trim() : '',
                vModel: isDriver ? vModelCtrl.text.trim() : '',
                vYear: isDriver ? vYearCtrl.text.trim() : '',
                vColor: isDriver ? vColorCtrl.text.trim() : '',
                imagePath: pickedImage?.path,
              );
              final updated = profile.copyWith(
                phone: phoneCtrl.text.trim(),
                firstName: firstCtrl.text.trim(),
                surname: surnameCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                city: cityCtrl.text.trim(),
                bankno: bankCtrl.text.trim(),
                vType: isDriver ? vTypeCtrl.text.trim() : profile.vType,
                vMake: isDriver ? vMakeCtrl.text.trim() : profile.vMake,
                vModel: isDriver ? vModelCtrl.text.trim() : profile.vModel,
                vYear: isDriver ? vYearCtrl.text.trim() : profile.vYear,
                vColor: isDriver ? vColorCtrl.text.trim() : profile.vColor,
              );
              await SessionService.instance.updateProfile(updated);
              if (ctx.mounted) Navigator.of(ctx).pop(true);
            } catch (e) {
              setSheet(() {
                saving = false;
                errorMsg = e.toString().replaceFirst('Exception: ', '');
              });
            }
          }

          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.9,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle + header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 40, height: 4,
                            decoration: BoxDecoration(
                              color: SRColors.border,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Edit Profile',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: SRColors.ink900,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.of(ctx).pop(),
                              child: const Icon(Icons.close_rounded,
                                  color: SRColors.ink500, size: 22),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: SRColors.border),

                  // Scrollable fields
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                          20, 20, 20,
                          MediaQuery.of(ctx).viewInsets.bottom + 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Photo picker
                          Center(
                            child: GestureDetector(
                              onTap: showImageOptions,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 80, height: 80,
                                    decoration: BoxDecoration(
                                      color: SRColors.lavenderBg,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: SRColors.purple700, width: 2),
                                    ),
                                    child: pickedImage != null
                                        ? ClipOval(
                                            child: Image.file(
                                              File(pickedImage!.path),
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : profile.photoUrl != null &&
                                                profile.photoUrl!.isNotEmpty
                                            ? ClipOval(
                                                child: Image.network(
                                                  profile.photoUrl!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      Center(
                                                    child: Text(
                                                      profile.initials,
                                                      style: const TextStyle(
                                                        fontSize: 26,
                                                        fontWeight: FontWeight.w700,
                                                        color: SRColors.purple700,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : Center(
                                                child: Text(
                                                  profile.initials,
                                                  style: const TextStyle(
                                                    fontSize: 26,
                                                    fontWeight: FontWeight.w700,
                                                    color: SRColors.purple700,
                                                  ),
                                                ),
                                              ),
                                  ),
                                  Positioned(
                                    bottom: 0, right: 0,
                                    child: Container(
                                      width: 26, height: 26,
                                      decoration: BoxDecoration(
                                        color: SRColors.purple700,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(Icons.camera_alt_rounded,
                                          color: Colors.white, size: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Center(
                            child: Text('Tap to change photo',
                                style: TextStyle(
                                    fontSize: 12, color: SRColors.ink500)),
                          ),
                          const SizedBox(height: 24),

                          // Basic info
                          const _SectionLabel('Basic info'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _EditField(
                                    label: 'First name',
                                    controller: firstCtrl),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _EditField(
                                    label: 'Surname',
                                    controller: surnameCtrl),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _EditField(
                            label: 'Email',
                            controller: emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          _EditField(
                              label: 'City', controller: cityCtrl),
                          const SizedBox(height: 12),
                          _EditField(
                            label: 'Phone',
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 20),

                          // Bank
                          const _SectionLabel('Payment'),
                          const SizedBox(height: 12),
                          _EditField(
                            label: 'Bank account number',
                            controller: bankCtrl,
                            keyboardType: TextInputType.number,
                          ),

                          // Vehicle — drivers only
                          if (isDriver) ...[
                            const SizedBox(height: 20),
                            const _SectionLabel('Vehicle'),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _EditField(
                                      label: 'Type', controller: vTypeCtrl),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _EditField(
                                      label: 'Make', controller: vMakeCtrl),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _EditField(
                                      label: 'Model', controller: vModelCtrl),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _EditField(
                                    label: 'Year',
                                    controller: vYearCtrl,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _EditField(
                                label: 'Colour', controller: vColorCtrl),
                          ],

                          // Error
                          if (errorMsg != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: SRColors.coral100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      color: SRColors.coral500, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(errorMsg!,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: SRColors.coral600)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),

                  // Save button pinned at bottom
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: saving ? null : save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SRColors.purple700,
                          disabledBackgroundColor:
                              SRColors.purple700.withValues(alpha: 0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99),
                          ),
                          elevation: 0,
                        ),
                        child: saving
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Save changes',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    firstCtrl.dispose();
    surnameCtrl.dispose();
    emailCtrl.dispose();
    cityCtrl.dispose();
    phoneCtrl.dispose();
    bankCtrl.dispose();
    vTypeCtrl.dispose();
    vMakeCtrl.dispose();
    vModelCtrl.dispose();
    vYearCtrl.dispose();
    vColorCtrl.dispose();

    if (result == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final profile = SessionService.instance.profile;
    final initials = profile?.initials ?? 'U';
    final name = profile != null
        ? '${profile.firstName} ${profile.surname}'
        : 'Guest User';

    return Scaffold(
      backgroundColor: SRColors.lavenderBg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _ProfileHeader(
              initials: initials,
              name: name,
              tripCount: _totalTrips,
              photoUrl: profile?.photoUrl,
              onEdit: _openEditSheet,
            ),
            const SizedBox(height: 16),
            _StatsRow(walletBalance: _fmtBalance(_walletBalance), totalTrips: _totalTrips),
            const SizedBox(height: 20),
            _MenuSection(
              title: 'Account',
              items: [
                _MenuItem(
                  icon: Icons.credit_card_rounded,
                  label: 'Payment methods',
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.bookmark_rounded,
                  label: 'Saved places',
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.language_rounded,
                  label: 'Language & region',
                  onTap: () => context.push('/language'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MenuSection(
              title: 'Support',
              items: [
                _MenuItem(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & FAQ',
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.health_and_safety_rounded,
                  label: 'Safety Hub',
                  onTap: () => context.push('/safety'),
                ),
                _MenuItem(
                  icon: Icons.info_outline_rounded,
                  label: 'About StreetRide',
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: GestureDetector(
                onTap: () {
                  SessionService.instance.clear();
                  BackgroundPollService.stop();
                  context.go('/welcome');
                },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: SRColors.coral100,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: SRColors.coral500, width: 1.5),
                  ),
                  child: const Center(
                    child: Text(
                      'Log out',
                      style: TextStyle(
                        color: SRColors.coral500,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: SRColors.ink500,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String initials;
  final String name;
  final int tripCount;
  final String? photoUrl;
  final VoidCallback onEdit;
  const _ProfileHeader({
    required this.initials,
    required this.name,
    required this.tripCount,
    required this.onEdit,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: SRColors.gradHero,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: onEdit,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: photoUrl != null && photoUrl!.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(initials,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.directions_car_rounded,
                      color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '$tripCount trip${tripCount == 1 ? '' : 's'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final String walletBalance;
  final int totalTrips;
  const _StatsRow({required this.walletBalance, required this.totalTrips});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SRColors.border),
      ),
      child: Row(
        children: [
          _Stat(label: 'Total trips', value: '$totalTrips'),
          _StatDivider(),
          _Stat(label: 'Wallet', value: '₦$walletBalance'),
          _StatDivider(),
          const _Stat(label: 'Plus', value: 'Active'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: SRColors.ink900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: SRColors.ink500),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: SRColors.border);
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;
  const _MenuSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: SRColors.ink500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: SRColors.border),
            ),
            child: Column(
              children: List.generate(items.length, (i) {
                final item = items[i];
                return Column(
                  children: [
                    GestureDetector(
                      onTap: item.onTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: SRColors.lavenderBg,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(item.icon,
                                  color: SRColors.purple700, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.label,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: SRColors.ink900,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: SRColors.ink500, size: 20),
                          ],
                        ),
                      ),
                    ),
                    if (i < items.length - 1)
                      const Divider(
                          height: 1, color: SRColors.border, indent: 64),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.label, required this.onTap});
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;

  const _EditField({
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: SRColors.ink500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: SRColors.ink900,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: SRColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: SRColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: SRColors.purple700, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
