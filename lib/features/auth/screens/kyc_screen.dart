import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/sr_button.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _steps = [
    _KycStep(
      icon: Icons.badge_rounded,
      title: 'Government ID',
      subtitle: 'NIN, Driver\'s Licence, or Voter\'s Card',
      status: _StepStatus.pending,
    ),
    _KycStep(
      icon: Icons.drive_eta_rounded,
      title: 'Vehicle Documents',
      subtitle: 'Proof of ownership, roadworthiness',
      status: _StepStatus.pending,
    ),
    _KycStep(
      icon: Icons.face_rounded,
      title: 'Selfie Verification',
      subtitle: 'A clear photo of your face',
      status: _StepStatus.pending,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SRColors.lavenderBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: SRColors.gradHero,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.verified_rounded,
                    color: Colors.white, size: 34),
              ),
              const SizedBox(height: 20),
              const Text(
                'Driver Verification',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: SRColors.ink900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Complete verification to start accepting rides. This usually takes less than 24 hours.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: SRColors.ink500,
                ),
              ),
              const SizedBox(height: 32),
              ...List.generate(
                _steps.length,
                (i) => _KycStepCard(
                  step: _steps[i],
                  stepNumber: i + 1,
                  onTap: () => _handleStep(i),
                ),
              ),
              const Spacer(),
              SRButton(
                label: 'Submit for Review',
                onTap: () => context.go('/driver-home'),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'You can complete this later from your profile.',
                  style: TextStyle(fontSize: 12, color: SRColors.ink500),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _handleStep(int i) {
    setState(() {
      _steps[i] = _KycStep(
        icon: _steps[i].icon,
        title: _steps[i].title,
        subtitle: _steps[i].subtitle,
        status: _StepStatus.uploaded,
      );
    });
  }
}

enum _StepStatus { pending, uploaded, verified }

class _KycStep {
  final IconData icon;
  final String title;
  final String subtitle;
  final _StepStatus status;

  _KycStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
  });
}

class _KycStepCard extends StatelessWidget {
  final _KycStep step;
  final int stepNumber;
  final VoidCallback onTap;

  const _KycStepCard({
    required this.step,
    required this.stepNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUploaded = step.status == _StepStatus.uploaded;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SRColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUploaded ? SRColors.green500 : SRColors.border,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isUploaded ? SRColors.green100 : SRColors.lavenderBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isUploaded ? Icons.check_circle_rounded : step.icon,
                color: isUploaded ? SRColors.green500 : SRColors.purple700,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: SRColors.ink900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: SRColors.ink500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isUploaded ? SRColors.green100 : SRColors.lavenderBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isUploaded ? Icons.check_rounded : Icons.upload_rounded,
                size: 16,
                color: isUploaded ? SRColors.green500 : SRColors.ink500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
