import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../components/components.dart';
import '../../../models/address.dart';

/// Pin the door on the map (website: account page "Delivery Pin"). The pin
/// stays in the middle; the buyer drags the map under it, or jumps to where
/// they are. Pops the chosen [GeoPin], or null when backed out.
///
/// [onConfirm] saves it first (the default address pins straight to the
/// server); the page stays open with the error when saving fails.
class MapPinPage extends StatefulWidget {
  const MapPinPage({super.key, this.initial, this.title = 'Pin your door', this.addressLine, this.onConfirm});

  final GeoPin? initial;
  final String title;

  /// Shown above the map so the buyer knows which address they are pinning.
  final String? addressLine;
  final Future<void> Function(GeoPin pin)? onConfirm;

  @override
  State<MapPinPage> createState() => _MapPinPageState();
}

class _MapPinPageState extends State<MapPinPage> {
  /// The whole Philippines, when there is no pin yet.
  static const _philippines = LatLng(12.8797, 121.7740);

  final _map = MapController();
  late LatLng _center = widget.initial == null ? _philippines : LatLng(widget.initial!.lat, widget.initial!.lng);
  late bool _moved = widget.initial != null;
  bool _locating = false;
  bool _saving = false;

  GeoPin get _pin => GeoPin(double.parse(_center.latitude.toStringAsFixed(7)), double.parse(_center.longitude.toStringAsFixed(7)));

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) PsToast.error(context, 'Turn on Location on your phone, then try again.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          PsToast.error(context, permission == LocationPermission.deniedForever
              ? 'Location is blocked for PickSell. Allow it in your phone’s Settings, or drag the map instead.'
              : 'Allow location to jump to where you are, or drag the map instead.');
        }
        return;
      }
      final here = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (!mounted) return;
      final point = LatLng(here.latitude, here.longitude);
      _map.move(point, 18);
      setState(() {
        _center = point;
        _moved = true;
      });
    } catch (_) {
      if (mounted) PsToast.error(context, 'Couldn’t find your location. Drag the map to your door instead.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _confirm() async {
    final pin = _pin;
    if (!pin.inPhilippines) {
      PsToast.error(context, 'Pin a spot inside the Philippines.');
      return;
    }
    if (widget.onConfirm != null) {
      setState(() => _saving = true);
      try {
        await widget.onConfirm!(pin);
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _saving = false);
        PsToast.error(context, e.fieldError('lat') ?? e.message);
        return;
      }
    }
    if (mounted) Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    return PsAppShell(
      topBar: PsTopBar(title: widget.title),
      footer: PsFooterActions(
        primary: PsPrimaryButton(
          label: 'Use this spot',
          uppercase: false,
          loading: _saving,
          onPressed: _moved ? _confirm : null,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.sm, PsSpace.gutter, PsSpace.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.addressLine != null && widget.addressLine!.isNotEmpty) ...[
                  Text(widget.addressLine!, style: PsText.bodyStrong),
                  const SizedBox(height: 2),
                ],
                Text(
                  _moved ? 'Drag the map until the pin sits on your door or gate.' : 'Drag and zoom the map to your door, or tap “My location”.',
                  style: PsText.caption,
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: widget.initial == null ? 5.5 : 18,
                    minZoom: 4,
                    maxZoom: 19,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                    onPositionChanged: (camera, hasGesture) {
                      _center = camera.center;
                      if (hasGesture && !_moved) setState(() => _moved = true);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.picksell',
                    ),
                    const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
                  ],
                ),
                // The pin's tip marks the middle of the map.
                const IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 44),
                      child: Icon(Icons.location_on_rounded, size: 48, color: PsColors.primary, shadows: [Shadow(blurRadius: 6, color: Colors.black26)]),
                    ),
                  ),
                ),
                Positioned(
                  right: PsSpace.gutter,
                  bottom: PsSpace.gutter + 24,
                  child: FloatingActionButton.extended(
                    heroTag: 'locate',
                    onPressed: _locating ? null : _locate,
                    backgroundColor: PsColors.surface,
                    foregroundColor: PsColors.primaryStrong,
                    icon: _locating
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location_rounded),
                    label: const Text('My location'),
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
