import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';
import '../models/emergency_resource.dart';
import '../models/incident.dart';
import '../models/responder_location.dart';
import '../models/sos_alert.dart';
import '../models/sos_location.dart';
import '../services/offline_tile_provider.dart';
import '../theme/app_theme.dart';
import '../utils/geo.dart';
import 'category_icon.dart';

/// Renders reported incidents on an OpenStreetMap-powered map (no API key or
/// billing required). Busy areas are grouped into count clusters; responders
/// broadcasting their position appear as live dots; previously-viewed tiles
/// are cached for offline use.
class IncidentMap extends StatefulWidget {
  final List<Incident> incidents;
  final List<ResponderLocation> responders;
  final List<SosAlert> sosAlerts;
  final List<SosLocationUpdate> sosTrail;
  final List<EmergencyResource> resources;
  final double? centerLatitude;
  final double? centerLongitude;
  final String? currentUserLabel;
  final double height;
  final void Function(Incident)? onIncidentTap;

  const IncidentMap({
    super.key,
    required this.incidents,
    this.responders = const [],
    this.sosAlerts = const [],
    this.sosTrail = const [],
    this.resources = const [],
    this.centerLatitude,
    this.centerLongitude,
    this.currentUserLabel,
    this.height = 260,
    this.onIncidentTap,
  });

  @override
  State<IncidentMap> createState() => _IncidentMapState();
}

class _IncidentMapState extends State<IncidentMap> {
  final MapController _mapController = MapController();
  OfflineTileProvider? _tileProvider;
  LatLng _center =
      const LatLng(AppConfig.kakobaLatitude, AppConfig.kakobaLongitude);

  /// Nearby incidents (<= ~450 m apart) are grouped so dense areas show a
  /// single count cluster instead of a pile of overlapping markers.
  static const _clusterKm = 0.45;

  @override
  void initState() {
    super.initState();
    OfflineTileProvider.create().then((provider) {
      if (!mounted) return;
      setState(() => _tileProvider = provider);
    });
  }

  @override
  void didUpdateWidget(covariant IncidentMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final center = _computeCenter();
    if (center != _center) {
      _center = center;
      _mapController.move(_center, 14);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  LatLng _computeCenter() {
    final cLat = widget.centerLatitude;
    final cLng = widget.centerLongitude;
    if (cLat != null && cLng != null) return LatLng(cLat, cLng);
    if (widget.incidents.isNotEmpty) {
      final first = widget.incidents.first.location;
      return LatLng(first.latitude, first.longitude);
    }
    return const LatLng(AppConfig.kakobaLatitude, AppConfig.kakobaLongitude);
  }

  List<List<Incident>> _clusters() {
    final groups = <List<Incident>>[];
    final unassigned = List<Incident>.of(widget.incidents);
    while (unassigned.isNotEmpty) {
      final group = <Incident>[unassigned.removeLast()];
      var grew = true;
      while (grew) {
        grew = false;
        for (var i = unassigned.length - 1; i >= 0; i--) {
          final inc = unassigned[i];
          final near = group.any((g) {
            final a = g.location;
            final b = inc.location;
            return haversineKm(a.latitude, a.longitude, b.latitude, b.longitude) <=
                _clusterKm;
          });
          if (near) {
            group.add(inc);
            unassigned.removeAt(i);
            grew = true;
          }
        }
      }
      groups.add(group);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];

    if (widget.centerLatitude != null && widget.centerLongitude != null) {
      markers.add(Marker(
        point: LatLng(widget.centerLatitude!, widget.centerLongitude!),
        width: 42,
        height: 42,
        child: const _LocationPin(),
      ));
    }

    for (final responder in widget.responders) {
      markers.add(Marker(
        point: LatLng(responder.latitude, responder.longitude),
        width: 36,
        height: 36,
        child: Tooltip(
          message: '${responder.responderName} (responder)',
          child: _ResponderDot(),
        ),
      ));
    }

    for (final sos in widget.sosAlerts) {
      markers.add(Marker(
        point: LatLng(sos.latitude, sos.longitude),
        width: 40,
        height: 40,
        child: Tooltip(
          message: 'SOS - ${sos.userName}',
          child: const _SosPin(),
        ),
      ));
    }

    for (final resource in widget.resources) {
      markers.add(Marker(
        point: LatLng(resource.latitude, resource.longitude),
        width: 34,
        height: 34,
        child: Tooltip(
          message: '${resource.type.label} - ${resource.name}',
          child: _ResourcePin(type: resource.type),
        ),
      ));
    }

    for (final cluster in _clusters()) {
      if (cluster.length == 1) {
        final incident = cluster.first;
        markers.add(Marker(
          point: LatLng(
            incident.location.latitude,
            incident.location.longitude,
          ),
          width: 42,
          height: 42,
          child: GestureDetector(
            onTap: () => widget.onIncidentTap?.call(incident),
            child: Tooltip(
              message:
                  '${incident.category.label} - ${incident.locationLabel.isEmpty ? incident.description : incident.locationLabel}',
              child: CategoryIcon(incident.category, size: 38),
            ),
          ),
        ));
      } else {
        final centroid = _centroid(cluster);
        final urgent = cluster
            .any((i) => i.priority == IncidentPriority.urgent);
        markers.add(Marker(
          point: centroid,
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: () => _mapController.move(
                centroid,
                _mapController.camera.zoom + 2),
            child: _ClusterBadge(count: cluster.length, urgent: urgent),
          ),
        ));
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: widget.height,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: 14,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              tileProvider: _tileProvider,
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.safesecurity',
              maxZoom: 19,
            ),
            if (widget.sosTrail.length > 1)
              PolylineLayer(polylines: [
                Polyline(
                  points: [
                    for (final p in widget.sosTrail)
                      LatLng(p.latitude, p.longitude),
                  ],
                  strokeWidth: 4,
                  color: AppColors.primary,
                  borderColor: Colors.white,
                  borderStrokeWidth: 1,
                ),
              ]),
            MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }

  LatLng _centroid(List<Incident> cluster) {
    final lat = cluster
            .fold<double>(0, (sum, i) => sum + i.location.latitude) /
        cluster.length;
    final lng = cluster
            .fold<double>(0, (sum, i) => sum + i.location.longitude) /
        cluster.length;
    return LatLng(lat, lng);
  }
}

/// Blue "you are here" pin that follows the current GPS fix.
class _LocationPin extends StatelessWidget {
  const _LocationPin();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Your location',
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.secondary,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: const Icon(Icons.my_location, color: Colors.white, size: 18),
      ),
    );
  }
}

/// Live responder position shown on the map when they broadcast location.
class _ResponderDot extends StatelessWidget {
  const _ResponderDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF2E7D32),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 1)),
        ],
      ),
      child: const Icon(Icons.emergency, color: Colors.white, size: 15),
    );
  }
}

/// Red SOS marker shown for a person in distress.
class _SosPin extends StatelessWidget {
  const _SosPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: const Icon(Icons.sos, color: Colors.white, size: 18),
    );
  }
}

/// Marker for a static emergency facility in the directory layer.
class _ResourcePin extends StatelessWidget {
  final EmergencyResourceType type;
  const _ResourcePin({required this.type});

  static const _icons = {
    EmergencyResourceType.hospital: Icons.local_hospital,
    EmergencyResourceType.police: Icons.local_police,
    EmergencyResourceType.fire: Icons.local_fire_department,
    EmergencyResourceType.safeHaven: Icons.home_work,
    EmergencyResourceType.rallyPoint: Icons.groups,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: AppColors.secondary, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      child: Icon(_icons[type], size: 16, color: AppColors.secondary),
    );
  }
}

/// Count badge representing a group of nearby incidents. Tapping zooms in.
class _ClusterBadge extends StatelessWidget {
  final int count;
  final bool urgent;
  const _ClusterBadge({required this.count, this.urgent = false});

  @override
  Widget build(BuildContext context) {
    final color = urgent ? AppColors.primary : AppColors.secondary;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    );
  }
}