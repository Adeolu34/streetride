import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/booking/providers/ride_provider.dart';
import '../theme/app_theme.dart';

class RideNotificationOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const RideNotificationOverlay({super.key, required this.child});

  @override
  ConsumerState<RideNotificationOverlay> createState() =>
      _RideNotificationOverlayState();
}

class _RideNotificationOverlayState
    extends ConsumerState<RideNotificationOverlay> {
  Timer? _autoHide;

  @override
  void dispose() {
    _autoHide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      rideProvider.select((s) => s.notifVisible),
      (_, visible) {
        if (visible) {
          _autoHide?.cancel();
          _autoHide = Timer(const Duration(seconds: 5), () {
            if (mounted) ref.read(rideProvider.notifier).dismissNotif();
          });
        } else {
          _autoHide?.cancel();
        }
      },
    );

    final state = ref.watch(rideProvider);
    final topPad = MediaQuery.of(context).padding.top;

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        widget.child,
        AnimatedPositioned(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          top: state.notifVisible ? topPad + 12 : -200,
          left: 16,
          right: 16,
          child: IgnorePointer(
            ignoring: !state.notifVisible,
            child: _NotifBanner(
              message: state.notifMessage,
              detail: state.notifDetail,
              onDismiss: () => ref.read(rideProvider.notifier).dismissNotif(),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotifBanner extends StatelessWidget {
  final String message;
  final String detail;
  final VoidCallback onDismiss;

  const _NotifBanner({
    required this.message,
    required this.detail,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: SRColors.indigo900,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: SRColors.purple700.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDismiss,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
