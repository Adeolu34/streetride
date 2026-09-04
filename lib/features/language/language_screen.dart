import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/language_provider.dart';
import '../../core/theme/app_theme.dart';

class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key});

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = ref.read(languageProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SRColors.lavenderBg,
      appBar: AppBar(
        backgroundColor: SRColors.purple700,
        foregroundColor: Colors.white,
        title: const Text(
          'Language & Region',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose your preferred language',
              style: TextStyle(
                fontSize: 14,
                color: SRColors.ink500,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 20),
            _LanguageCard(
              flag: '🇬🇧',
              name: 'English',
              nativeName: 'English',
              code: 'en',
              selected: _selected == 'en',
              onTap: () => setState(() => _selected = 'en'),
            ),
            const SizedBox(height: 12),
            _LanguageCard(
              flag: '🇳🇬',
              name: 'Igbo',
              nativeName: 'Asụsụ Igbo',
              code: 'ig',
              selected: _selected == 'ig',
              onTap: () => setState(() => _selected = 'ig'),
            ),
            const SizedBox(height: 12),
            _LanguageCard(
              flag: '🇳🇬',
              name: 'Pidgin',
              nativeName: 'Nigerian Pidgin',
              code: 'pcm',
              selected: _selected == 'pcm',
              onTap: () => setState(() => _selected = 'pcm'),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await ref
                      .read(languageProvider.notifier)
                      .setLanguage(_selected);
                  if (context.mounted) context.pop();
                },
                child: const Text('Save'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  final String flag;
  final String name;
  final String nativeName;
  final String code;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.flag,
    required this.name,
    required this.nativeName,
    required this.code,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? SRColors.purple700.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? SRColors.purple700 : SRColors.border,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: selected ? SRColors.purple700 : SRColors.ink900,
                    ),
                  ),
                  Text(
                    nativeName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: SRColors.ink500,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: SRColors.purple700,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 14,
                ),
              )
            else
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: SRColors.border, width: 1.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
