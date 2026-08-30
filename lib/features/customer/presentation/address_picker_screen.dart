import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/config/app_theme.dart';
import '../../../core/utils/location_service.dart';

/// Result handed back to the request form.
class PickedAddress {
  const PickedAddress({required this.address, this.pin});

  final String address;
  final LatLng? pin;
}

/// Full-screen map picker: drop a pin, or type the address by hand.
class AddressPickerScreen extends ConsumerStatefulWidget {
  const AddressPickerScreen({
    super.key,
    this.initialAddress = '',
    this.initialPin,
  });

  final String initialAddress;
  final LatLng? initialPin;

  @override
  ConsumerState<AddressPickerScreen> createState() =>
      _AddressPickerScreenState();
}

class _AddressPickerScreenState extends ConsumerState<AddressPickerScreen> {
  final _mapController = MapController();
  late final TextEditingController _addressController =
      TextEditingController(text: widget.initialAddress);

  LatLng? _pin;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _pin = widget.initialPin;
    if (_pin == null) _useDeviceLocation(silent: true);
  }

  @override
  void dispose() {
    _addressController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _useDeviceLocation({bool silent = false}) async {
    setState(() => _locating = true);
    final position =
        await ref.read(locationServiceProvider).currentPosition();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (position != null) _pin = position;
    });

    if (position != null) {
      _mapController.move(position, 16);
    } else if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Location unavailable. Drop a pin or type the address instead.'),
        ),
      );
    }
  }

  void _confirm() {
    final address = _addressController.text.trim();
    if (address.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe the address so we can find it.')),
      );
      return;
    }
    Navigator.of(context).pop(PickedAddress(address: address, pin: _pin));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final center = _pin ?? kDefaultMapCenter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job location'),
        actions: [
          IconButton(
            onPressed: _locating ? null : () => _useDeviceLocation(),
            icon: _locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.my_location_rounded),
            tooltip: 'Use my location',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: _pin == null ? 12 : 16,
                    onTap: (_, point) => setState(() => _pin = point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.xirfadle.xirfadle_app',
                      maxZoom: 19,
                    ),
                    if (_pin != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _pin!,
                            width: 44,
                            height: 44,
                            alignment: Alignment.topCenter,
                            child: const Icon(
                              Icons.location_on,
                              size: 44,
                              color: AppTheme.brandTeal,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.touch_app_rounded,
                            size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _pin == null
                                ? 'Tap the map to drop a pin'
                                : 'Pin set — tap again to move it',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _addressController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 2,
                    minLines: 1,
                    decoration: const InputDecoration(
                      labelText: 'Address / landmark',
                      hintText: 'e.g. Hodan district, near Banadir hospital',
                      prefixIcon: Icon(Icons.home_outlined),
                    ),
                  ),
                  if (_pin != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Pin: ${_pin!.latitude.toStringAsFixed(5)}, ${_pin!.longitude.toStringAsFixed(5)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _confirm,
                    child: const Text('Use this location'),
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
