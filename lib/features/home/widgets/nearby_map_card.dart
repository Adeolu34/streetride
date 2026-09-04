import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';

class NearbyMapCard extends StatelessWidget {
  final int driverCount;

  const NearbyMapCard({super.key, required this.driverCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: SRColors.purple700.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          SizedBox(
            height: 100,
            child: Stack(
              children: [
                kIsWeb
                    ? _StaticMapPlaceholder()
                    : FlutterMap(
                        options: MapOptions(
                          initialCenter: const LatLng(6.4698, 3.5852),
                          initialZoom: 13,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c', 'd'],
                            userAgentPackageName:
                                'com.streetrideplus.streetride',
                          ),
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: const LatLng(6.4698, 3.5852),
                                radius: 8,
                                color: SRColors.purple700,
                                borderStrokeWidth: 3,
                                borderColor: Colors.white,
                              ),
                            ],
                          ),
                        ],
                      ),
                Positioned(
                  left: 10,
                  bottom: 9,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: [
                        BoxShadow(
                          color: SRColors.indigo900.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 7,
                          height: 7,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: SRColors.green500,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$driverCount drivers nearby',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: SRColors.ink900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
            child: Row(
              children: [
                _DriverAvatar('AO', SRColors.purple700),
                _DriverAvatar('MK', SRColors.purple600, offset: -9),
                _DriverAvatar('IE', SRColors.indigo800, offset: -9),
                _DriverAvatar('+3', SRColors.lavenderBg,
                    textColor: SRColors.purple700, offset: -9),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Pick who quotes you — one driver or all of them.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: SRColors.ink500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StaticMapPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE8E4F3), Color(0xFFD4CCF0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Grid lines to mimic map
          CustomPaint(painter: _MapGridPainter()),
          // Center dot
          const Center(
            child: Icon(Icons.location_on_rounded,
                color: SRColors.purple700, size: 28),
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 0.7;
    const step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_MapGridPainter _) => false;
}

class _DriverAvatar extends StatelessWidget {
  final String label;
  final Color bg;
  final Color textColor;
  final double offset;

  const _DriverAvatar(
    this.label,
    this.bg, {
    this.textColor = Colors.white,
    this.offset = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(offset, 0),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
