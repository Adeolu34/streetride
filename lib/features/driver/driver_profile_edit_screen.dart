import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/session_service.dart';
import '../../core/api/ride_api.dart';

class DriverProfileEditScreen extends StatefulWidget {
  const DriverProfileEditScreen({super.key});

  @override
  State<DriverProfileEditScreen> createState() =>
      _DriverProfileEditScreenState();
}

class _DriverProfileEditScreenState extends State<DriverProfileEditScreen> {
  late final TextEditingController _firstCtrl;
  late final TextEditingController _surnameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _vMakeCtrl;
  late final TextEditingController _vModelCtrl;
  late final TextEditingController _vYearCtrl;
  late final TextEditingController _bankCtrl;

  String _vType = '';
  String _vColor = '';
  XFile? _pickedImage;
  bool _saving = false;
  String? _errorMsg;
  String _displayName = '';

  static const _vehicleTypes = [
    'Saloon/Sedan',
    'SUV',
    'Hatchback',
    'Minivan/Bus',
    'Pickup Truck',
    'Tricycle (Keke)',
    'Motorcycle',
    'Other',
  ];

  static const _colorSwatches = [
    _ColorSwatch('White', Color(0xFFF5F5F5), Color(0xFFCCCCCC)),
    _ColorSwatch('Black', Color(0xFF1C1C1E), null),
    _ColorSwatch('Silver', Color(0xFFB0B0B8), null),
    _ColorSwatch('Grey', Color(0xFF757575), null),
    _ColorSwatch('Red', Color(0xFFCC2222), null),
    _ColorSwatch('Blue', Color(0xFF1A3A9C), null),
    _ColorSwatch('Green', Color(0xFF2A7A44), null),
    _ColorSwatch('Gold', Color(0xFFB8860B), null),
    _ColorSwatch('Brown', Color(0xFF6B3A2A), null),
    _ColorSwatch('Orange', Color(0xFFE06A1A), null),
  ];

  @override
  void initState() {
    super.initState();
    final p = SessionService.instance.profile;
    _firstCtrl = TextEditingController(text: p?.firstName ?? '');
    _surnameCtrl = TextEditingController(text: p?.surname ?? '');
    _emailCtrl = TextEditingController(text: p?.email ?? '');
    _cityCtrl = TextEditingController(text: p?.city ?? '');
    _vMakeCtrl = TextEditingController(text: p?.vMake ?? '');
    _vModelCtrl = TextEditingController(text: p?.vModel ?? '');
    _vYearCtrl = TextEditingController(text: p?.vYear ?? '');
    _bankCtrl = TextEditingController(text: p?.bankno ?? '');
    _vType = p?.vType ?? '';
    _vColor = p?.vColor ?? '';
    _displayName = '${p?.firstName ?? ''} ${p?.surname ?? ''}'.trim();

    _firstCtrl.addListener(_updateName);
    _surnameCtrl.addListener(_updateName);
  }

  void _updateName() {
    setState(() {
      _displayName =
          '${_firstCtrl.text.trim()} ${_surnameCtrl.text.trim()}'.trim();
    });
  }

  @override
  void dispose() {
    _firstCtrl.removeListener(_updateName);
    _surnameCtrl.removeListener(_updateName);
    _firstCtrl.dispose();
    _surnameCtrl.dispose();
    _emailCtrl.dispose();
    _cityCtrl.dispose();
    _vMakeCtrl.dispose();
    _vModelCtrl.dispose();
    _vYearCtrl.dispose();
    _bankCtrl.dispose();
    super.dispose();
  }

  int get _completeness {
    int filled = 0;
    int total = 8;
    if (_firstCtrl.text.trim().isNotEmpty) filled++;
    if (_surnameCtrl.text.trim().isNotEmpty) filled++;
    if (_emailCtrl.text.trim().isNotEmpty) filled++;
    if (_cityCtrl.text.trim().isNotEmpty) filled++;
    if (_vType.isNotEmpty) filled++;
    if (_vMakeCtrl.text.trim().isNotEmpty && _vModelCtrl.text.trim().isNotEmpty) filled++;
    if (_vYearCtrl.text.trim().isNotEmpty) filled++;
    if (_bankCtrl.text.trim().isNotEmpty) filled++;
    return ((filled / total) * 100).round();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 900,
    );
    if (img != null) setState(() => _pickedImage = img);
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SRColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),
                _PickerTile(
                  icon: Icons.camera_alt_rounded,
                  label: 'Take a photo',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                const Divider(height: 1, indent: 64, color: SRColors.border),
                _PickerTile(
                  icon: Icons.photo_library_rounded,
                  label: 'Choose from gallery',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showVehicleTypePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: SRColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'Vehicle type',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: SRColors.ink900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(_vehicleTypes.length, (i) {
                final t = _vehicleTypes[i];
                final selected = _vType == t;
                return Column(
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() => _vType = t);
                        Navigator.pop(context);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                t,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? SRColors.purple700
                                      : SRColors.ink900,
                                ),
                              ),
                            ),
                            if (selected)
                              const Icon(Icons.check_circle_rounded,
                                  color: SRColors.purple700, size: 20),
                          ],
                        ),
                      ),
                    ),
                    if (i < _vehicleTypes.length - 1)
                      const Divider(
                          height: 1,
                          indent: 20,
                          endIndent: 20,
                          color: SRColors.border),
                  ],
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final profile = SessionService.instance.profile;
    if (profile == null) return;

    if (_firstCtrl.text.trim().isEmpty || _surnameCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'First name and surname are required.');
      return;
    }

    setState(() {
      _saving = true;
      _errorMsg = null;
    });

    try {
      await RideApi.instance.updateProfile(
        phone: profile.phone,
        firstName: _firstCtrl.text.trim(),
        surname: _surnameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        isDriver: true,
        bankno: _bankCtrl.text.trim(),
        vType: _vType,
        vMake: _vMakeCtrl.text.trim(),
        vModel: _vModelCtrl.text.trim(),
        vYear: _vYearCtrl.text.trim(),
        vColor: _vColor,
        imagePath: _pickedImage?.path,
      );

      final updated = profile.copyWith(
        firstName: _firstCtrl.text.trim(),
        surname: _surnameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        bankno: _bankCtrl.text.trim(),
        vType: _vType,
        vMake: _vMakeCtrl.text.trim(),
        vModel: _vModelCtrl.text.trim(),
        vYear: _vYearCtrl.text.trim(),
        vColor: _vColor,
      );
      await SessionService.instance.updateProfile(updated);

      if (mounted) {
        _showSuccess();
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: SRColors.green500, size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'Profile saved!',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: SRColors.ink900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your profile has been updated successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: SRColors.ink500),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SRColors.purple700,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(99)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = SessionService.instance.profile;
    final photoUrl = profile?.photoUrl ?? '';
    final pct = _completeness;

    return Scaffold(
      backgroundColor: SRColors.lavenderBg,
      body: Column(
        children: [
          // ── Dark gradient header ───────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: SRColors.gradNight,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Column(
                  children: [
                    // Toolbar
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Edit Profile',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _saving ? null : _save,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: SRColors.purple700,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text(
                                    'Save',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Photo
                    GestureDetector(
                      onTap: _showImagePicker,
                      child: Stack(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color:
                                      SRColors.amber500.withValues(alpha: 0.7),
                                  width: 2.5),
                            ),
                            child: ClipOval(
                              child: _pickedImage != null
                                  ? Image.file(File(_pickedImage!.path),
                                      fit: BoxFit.cover)
                                  : photoUrl.isNotEmpty
                                      ? Image.network(photoUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _InitialsAvatar(
                                                  _displayName.isEmpty
                                                      ? '?'
                                                      : _initials(_displayName)))
                                      : _InitialsAvatar(_displayName.isEmpty
                                          ? '?'
                                          : _initials(_displayName)),
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: SRColors.amber500,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt_rounded,
                                  color: Colors.white, size: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Live name
                    Text(
                      _displayName.isEmpty ? 'Your Name' : _displayName,
                      style: TextStyle(
                        color: _displayName.isEmpty
                            ? Colors.white38
                            : Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Completeness bar
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Profile $pct% complete',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: pct / 100,
                            minHeight: 5,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation(
                              pct >= 80
                                  ? SRColors.green500
                                  : SRColors.amber500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Scrollable content ─────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Personal Info ──────────────────────────────────────
                  _SectionHeader(label: 'Personal Info'),
                  const SizedBox(height: 8),
                  _Card(
                    children: [
                      _InlineField(
                        icon: Icons.person_rounded,
                        label: 'First name',
                        controller: _firstCtrl,
                      ),
                      _Divider(),
                      _InlineField(
                        icon: Icons.person_outline_rounded,
                        label: 'Surname',
                        controller: _surnameCtrl,
                      ),
                      _Divider(),
                      _InlineField(
                        icon: Icons.email_rounded,
                        label: 'Email address',
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      _Divider(),
                      _InlineField(
                        icon: Icons.location_city_rounded,
                        label: 'City',
                        controller: _cityCtrl,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Vehicle ────────────────────────────────────────────
                  _SectionHeader(label: 'Vehicle Details'),
                  const SizedBox(height: 8),
                  _Card(
                    children: [
                      // Type picker
                      GestureDetector(
                        onTap: _showVehicleTypePicker,
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
                                child: const Icon(Icons.directions_car_rounded,
                                    color: SRColors.purple700, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Vehicle type',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: SRColors.ink500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _vType.isEmpty ? 'Select type' : _vType,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: _vType.isEmpty
                                            ? SRColors.ink500
                                            : SRColors.ink900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.expand_more_rounded,
                                  color: SRColors.ink500, size: 20),
                            ],
                          ),
                        ),
                      ),
                      _Divider(),
                      Row(
                        children: [
                          Expanded(
                            child: _InlineField(
                              icon: Icons.business_rounded,
                              label: 'Make',
                              hint: 'Toyota',
                              controller: _vMakeCtrl,
                            ),
                          ),
                          Container(width: 1, height: 60, color: SRColors.border),
                          Expanded(
                            child: _InlineField(
                              icon: Icons.calendar_today_rounded,
                              label: 'Year',
                              hint: '2020',
                              controller: _vYearCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                            ),
                          ),
                        ],
                      ),
                      _Divider(),
                      _InlineField(
                        icon: Icons.build_rounded,
                        label: 'Model',
                        hint: 'Corolla',
                        controller: _vModelCtrl,
                      ),
                      _Divider(),

                      // Color picker
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    color: SRColors.lavenderBg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.palette_rounded,
                                      color: SRColors.purple700, size: 18),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Vehicle colour',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: SRColors.ink500,
                                  ),
                                ),
                                const Spacer(),
                                if (_vColor.isNotEmpty)
                                  Text(
                                    _vColor,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: SRColors.purple700,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _colorSwatches.map((s) {
                                  final selected = _vColor == s.name;
                                  return GestureDetector(
                                    onTap: () =>
                                        setState(() => _vColor = s.name),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      margin: const EdgeInsets.only(right: 10),
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: s.color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: selected
                                              ? SRColors.purple700
                                              : (s.borderColor ??
                                                  Colors.transparent),
                                          width: selected ? 3 : 1,
                                        ),
                                        boxShadow: selected
                                            ? [
                                                BoxShadow(
                                                  color: SRColors.purple700
                                                      .withValues(alpha: 0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                )
                                              ]
                                            : null,
                                      ),
                                      child: selected
                                          ? Icon(
                                              Icons.check_rounded,
                                              size: 18,
                                              color: s.color.computeLuminance() > 0.5
                                                  ? SRColors.ink900
                                                  : Colors.white,
                                            )
                                          : null,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Payment ────────────────────────────────────────────
                  _SectionHeader(label: 'Payment'),
                  const SizedBox(height: 8),
                  _Card(
                    children: [
                      _InlineField(
                        icon: Icons.account_balance_rounded,
                        label: 'Bank account number',
                        hint: '0123456789',
                        controller: _bankCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      'Used to receive your ride earnings.',
                      style: TextStyle(
                        fontSize: 11,
                        color: SRColors.ink500.withValues(alpha: 0.7),
                      ),
                    ),
                  ),

                  // ── Error ──────────────────────────────────────────────
                  if (_errorMsg != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: SRColors.coral100,
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: SRColors.coral500.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: SRColors.coral500, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMsg!,
                              style: const TextStyle(
                                  fontSize: 13, color: SRColors.coral600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Save button ────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SRColors.purple700,
                        disabledBackgroundColor:
                            SRColors.purple700.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99)),
                        elevation: 0,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text(
                              'Save changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

String _initials(String name) {
  final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  if (parts.isNotEmpty) return parts[0][0].toUpperCase();
  return '?';
}

class _ColorSwatch {
  final String name;
  final Color color;
  final Color? borderColor;
  const _ColorSwatch(this.name, this.color, this.borderColor);
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 0),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: SRColors.ink500,
            letterSpacing: 0.8,
          ),
        ),
      );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: SRColors.border),
          boxShadow: [
            BoxShadow(
              color: SRColors.purple700.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(children: children),
      );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 64, color: SRColors.border);
}

class _InlineField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _InlineField({
    required this.icon,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: SRColors.lavenderBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: SRColors.purple700, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: SRColors.ink500,
                  ),
                ),
                const SizedBox(height: 2),
                TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: SRColors.ink900,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: SRColors.ink500.withValues(alpha: 0.5),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  cursorColor: SRColors.purple700,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickerTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: SRColors.lavenderBg,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: SRColors.purple700, size: 20),
      ),
      title: Text(label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String initials;
  const _InitialsAvatar(this.initials);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
