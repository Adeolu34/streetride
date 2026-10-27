import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/saved_places_service.dart';
import '../../core/theme/app_theme.dart';

class SavedPlacesScreen extends StatefulWidget {
  const SavedPlacesScreen({super.key});

  @override
  State<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends State<SavedPlacesScreen> {
  SavedPlace? _home;
  SavedPlace? _work;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedPlaces();
  }

  Future<void> _loadSavedPlaces() async {
    final home = await SavedPlacesService.getHome();
    final work = await SavedPlacesService.getWork();
    if (mounted) {
      setState(() {
        _home = home;
        _work = work;
        _loading = false;
      });
    }
  }

  void _showPlaceOptions(String label, SavedPlace? current, bool isHome) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: SRColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Set $label Location',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: SRColors.ink900,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: SRColors.purple100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.map_rounded, color: SRColors.purple700, size: 22),
                  ),
                  title: const Text('Pick on Map', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Pin exact doorstep or entrance location', style: TextStyle(fontSize: 12, color: SRColors.ink500)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: SRColors.ink500),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final result = await context.push<Map<String, dynamic>>(
                      '/map-picker',
                      extra: {
                        'initialAddress': current?.address ?? '',
                        'lat': current?.lat,
                        'lng': current?.lng,
                      },
                    );
                    if (result != null && mounted) {
                      final place = SavedPlace(
                        label: label,
                        address: result['address']?.toString() ?? '',
                        primaryName: result['primaryName']?.toString() ?? '',
                        secondaryAddr: result['secondaryAddr']?.toString() ?? '',
                        lat: result['lat'] as double?,
                        lng: result['lng'] as double?,
                        placeId: result['placeId']?.toString() ?? '',
                      );
                      if (isHome) {
                        await SavedPlacesService.setHome(place);
                        setState(() => _home = place);
                      } else {
                        await SavedPlacesService.setWork(place);
                        setState(() => _work = place);
                      }
                    }
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: SRColors.lavenderBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_location_alt_rounded, color: SRColors.purple700, size: 22),
                  ),
                  title: const Text('Type Address', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Enter street address manually', style: TextStyle(fontSize: 12, color: SRColors.ink500)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: SRColors.ink500),
                  onTap: () {
                    Navigator.pop(ctx);
                    _promptManualAddress(label, current, isHome);
                  },
                ),
                if (current != null) ...[
                  const Divider(height: 24),
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700, size: 22),
                    ),
                    title: Text(
                      'Remove $label',
                      style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      if (isHome) {
                        await SavedPlacesService.setHome(null);
                        setState(() => _home = null);
                      } else {
                        await SavedPlacesService.setWork(null);
                        setState(() => _work = null);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _promptManualAddress(String label, SavedPlace? current, bool isHome) {
    final ctrl = TextEditingController(text: current?.address ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter $label Address',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: SRColors.ink900),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. 14 Victoria Island, Lagos',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: SRColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final val = ctrl.text.trim();
                        final place = val.isNotEmpty
                            ? SavedPlace(
                                label: label,
                                address: val,
                                primaryName: val.split(',').first.trim(),
                              )
                            : null;
                        if (isHome) {
                          await SavedPlacesService.setHome(place);
                          setState(() => _home = place);
                        } else {
                          await SavedPlacesService.setWork(place);
                          setState(() => _work = place);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SRColors.lavenderBg,
      appBar: AppBar(
        backgroundColor: SRColors.purple700,
        foregroundColor: Colors.white,
        title: const Text(
          'Saved Places',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Save frequent destinations to book rides with a single tap.',
                  style: TextStyle(fontSize: 14, color: SRColors.ink500),
                ),
                const SizedBox(height: 20),
                _PlaceTile(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  place: _home,
                  onTap: () => _showPlaceOptions('Home', _home, true),
                ),
                const SizedBox(height: 12),
                _PlaceTile(
                  icon: Icons.work_rounded,
                  label: 'Work',
                  place: _work,
                  onTap: () => _showPlaceOptions('Work', _work, false),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: SRColors.purple100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: SRColors.purple300),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: SRColors.purple700, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your saved places are preserved securely on your device and readily available on your home screen.',
                          style: TextStyle(fontSize: 13, color: SRColors.purple900, height: 1.4),
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

class _PlaceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final SavedPlace? place;
  final VoidCallback onTap;

  const _PlaceTile({
    required this.icon,
    required this.label,
    required this.place,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPlace = place != null && place!.address.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SRColors.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: hasPlace ? SRColors.purple100 : SRColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: hasPlace ? SRColors.purple700 : SRColors.ink500, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: SRColors.ink900),
                  ),
                  const SizedBox(height: 2),
                  if (hasPlace) ...[
                    if (place!.primaryName.isNotEmpty)
                      Text(
                        place!.primaryName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SRColors.purple900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      place!.secondaryAddr.isNotEmpty ? place!.secondaryAddr : place!.address,
                      style: const TextStyle(fontSize: 12, color: SRColors.ink500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else
                    Text(
                      'Tap to set your $label address',
                      style: const TextStyle(fontSize: 12, color: SRColors.purple700, fontWeight: FontWeight.w500),
                    ),
                ],
              ),
            ),
            Icon(
              hasPlace ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
              size: 20,
              color: SRColors.purple700,
            ),
          ],
        ),
      ),
    );
  }
}
