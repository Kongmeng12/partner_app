import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// The two map sources the platform uses. MapTiler comes through the API's
/// proxy so its key never ships in the app, the same route as the customer
/// app. OpenStreetMap, which the web pages load directly, is the fallback
/// for any tile the proxy cannot serve (no key set, quota spent, MapTiler
/// down). Without it a partner would be asked to pin on a blank grey map.
TileLayer mapTiles() => TileLayer(
  urlTemplate: '${AppConfig.apiBaseUrl}/maps/tile/{z}/{x}/{y}.png',
  fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  // OSM's tile policy requires an identifying User-Agent.
  userAgentPackageName: 'com.phaphak.partner',
  maxNativeZoom: 19,
);

/// Where the map opens when nothing is pinned yet: central Vientiane.
const _fallbackCenter = LatLng(17.9667, 102.6000);

/// Roughly the country. Same box as the admin's picker, since a pin outside
/// Laos is a mis-tap, not a property.
bool inLaos(LatLng p) =>
    p.latitude >= 13.5 && p.latitude <= 22.6 && p.longitude >= 100 && p.longitude <= 108;

/// Full-screen map where the partner taps to drop their property's pin, or
/// jumps to where they are standing. Pops the chosen [LatLng], or nothing on
/// Back.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, this.initial});

  final LatLng? initial;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _map = MapController();
  late LatLng? _pin = widget.initial;
  bool _locating = false;

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final error = await _ensurePermission();
      if (error != null) {
        if (mounted) showMessage(context, error, error: true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      final here = LatLng(pos.latitude, pos.longitude);
      setState(() => _pin = here);
      _map.move(here, 17);
    } catch (_) {
      if (mounted) showMessage(context, 'ຫາທີ່ຢູ່ປັດຈຸບັນບໍ່ໄດ້ ລອງໃໝ່ອີກຄັ້ງ', error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// A message to show, or null once the app may read the location.
  Future<String?> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'ກະລຸນາເປີດ GPS / Location ກ່ອນ';
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return 'ບໍ່ໄດ້ຮັບອະນຸຍາດໃຫ້ເຂົ້າເຖິງທີ່ຢູ່';
    }
    if (permission == LocationPermission.deniedForever) {
      return 'ການເຂົ້າເຖິງທີ່ຢູ່ຖືກປິດໄວ້ ກະລຸນາເປີດໃນການຕັ້ງຄ່າ';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pin = _pin;
    final outside = pin != null && !inLaos(pin);
    return Scaffold(
      appBar: AppBar(title: const Text('ເລືອກທີ່ຕັ້ງທີ່ພັກ')),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: pin ?? _fallbackCenter,
                initialZoom: pin == null ? 12 : 16,
                onTap: (_, point) => setState(() => _pin = point),
              ),
              children: [
                mapTiles(),
                if (pin != null) MarkerLayer(markers: [pinMarker(pin)]),
                const MapAttribution(),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    pin == null
                        ? 'ແຕະໃສ່ແຜນທີ່ບ່ອນທີ່ພັກຂອງທ່ານຕັ້ງຢູ່'
                        : '${pin.latitude.toStringAsFixed(5)}, ${pin.longitude.toStringAsFixed(5)}'
                            '${outside ? ' — ຢູ່ນອກປະເທດລາວ' : ''}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: pin == null ? C.muted : (outside ? C.dangerFg : C.text),
                      fontSize: 13.5,
                      fontWeight: pin == null ? FontWeight.w400 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _locating ? null : _useCurrentLocation,
                    icon:
                        _locating
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.my_location, size: 18),
                    label: const Text('ໃຊ້ທີ່ຢູ່ປັດຈຸບັນ'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed:
                        (pin == null || outside) ? null : () => Navigator.of(context).pop(pin),
                    child: const Text('ຢືນຢັນທີ່ຕັ້ງນີ້'),
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

/// The property pin, its tip on the point rather than its centre.
Marker pinMarker(LatLng point) => Marker(
  point: point,
  width: 44,
  height: 44,
  alignment: Alignment.topCenter,
  child: const Icon(Icons.location_pin, size: 44, color: C.accent),
);

/// MapTiler's terms require the credit on every map that shows its tiles.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) => RichAttributionWidget(
    alignment: AttributionAlignment.bottomLeft,
    showFlutterMapAttribution: false,
    attributions: [
      TextSourceAttribution(
        'MapTiler',
        onTap: () => launchUrl(Uri.parse('https://www.maptiler.com/copyright/')),
      ),
      TextSourceAttribution(
        'OpenStreetMap contributors',
        onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
      ),
    ],
  );
}
