import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/api/ride_api.dart';
import '../../../core/theme/app_theme.dart';

class NearbyMapCard extends StatefulWidget {
  final int driverCount;

  const NearbyMapCard({super.key, required this.driverCount});

  @override
  State<NearbyMapCard> createState() => _NearbyMapCardState();
}

class _NearbyMapCardState extends State<NearbyMapCard> {
  LatLng _center = const LatLng(6.5244, 3.3792); // Lagos default
  final List<LatLng> _driverPositions = [];

  @override
  void initState() {
    super.initState();
    _initLocationAndDrivers();
  }

  Future<void> _initLocationAndDrivers() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null && mounted) {
        setState(() {
          _center = LatLng(pos.latitude, pos.longitude);
        });
        _loadNearbyDrivers(pos.latitude, pos.longitude);
        return;
      }
    } catch (_) {}

    if (mounted) {
      _loadNearbyDrivers(_center.latitude, _center.longitude);
    }
  }

  Future<void> _loadNearbyDrivers(double lat, double lng) async {
    try {
      final data = await RideApi.instance.getNearbyDrivers(
        lat: lat.toString(),
        long: lng.toString(),
      );
      final rawUsers = data['Users'];
      if (rawUsers is List && mounted) {
        final list = <LatLng>[];
        for (final u in rawUsers) {
          if (u is Map<String, dynamic> && u['isDriver'] == true) {
            final dLat = double.tryParse(u['lat']?.toString() ?? u['latitude']?.toString() ?? '');
            final dLng = double.tryParse(u['long']?.toString() ?? u['longitude']?.toString() ?? '');
            if (dLat != null && dLng != null) {
              list.add(LatLng(dLat, dLng));
            }
          }
        }
        if (list.isNotEmpty && mounted) {
          setState(() {
            _driverPositions.clear();
            _driverPositions.addAll(list);
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final effectiveCount = _driverPositions.isNotEmpty
        ? _driverPositions.length
        : (widget.driverCount > 0 ? widget.driverCount : 3);

    return GestureDetector(
      onTap: () => context.push('/search'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: SRColors.purple700.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            SizedBox(
              height: 120,
              child: Stack(
                children: [
                  kIsWeb
                      ? _StaticMapPlaceholder()
                      : FlutterMap(
                          key: ValueKey('${_center.latitude}_${_center.longitude}'),
                          options: MapOptions(
                            initialCenter: _center,
                            initialZoom: 14,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                              subdomains: const ['a', 'b', 'c', 'd'],
                              userAgentPackageName: 'com.streetrideplus.streetride',
                              maxZoom: 19,
                            ),
                            CircleLayer(
                              circles: [
                                CircleMarker(
                                  point: _center,
                                  radius: 22,
                                  color: SRColors.purple700.withValues(alpha: 0.12),
                                  borderStrokeWidth: 1.5,
                                  borderColor: SRColors.purple700.withValues(alpha: 0.4),
                                ),
                                CircleMarker(
                                  point: _center,
                                  radius: 6,
                                  color: SRColors.purple700,
                                  borderStrokeWidth: 2.5,
                                  borderColor: Colors.white,
                                ),
                              ],
                            ),
                            MarkerLayer(
                              markers: _driverPositions.map((p) {
                                return Marker(
                                  point: p,
                                  width: 28,
                                  height: 28,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: SRColors.purple900,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.directions_car_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                  Positioned(
                    left: 12,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: [
                          BoxShadow(
                            color: SRColors.indigo900.withValues(alpha: 0.16),
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
                          const SizedBox(width: 6),
                          Text(
                            '$effectiveCount driver${effectiveCount == 1 ? '' : 's'} nearby',
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
                  Positioned(
                    right: 12,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: SRColors.purple700,
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: [
                          BoxShadow(
                            color: SRColors.purple700.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Text(
                            'Book now',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 16, color: SRColors.purple700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Real-time drivers around you · Choose your driver & fare',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: SRColors.ink700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      child: const Center(
        child: Icon(Icons.location_on_rounded, color: SRColors.purple700, size: 28),
      ),
    );
  }
}
