import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../models/incident.dart';
import '../../models/responder_location.dart';
import '../../repositories/repository.dart';
import '../../services/location_service.dart';
import '../../widgets/common.dart';
import '../../widgets/incident_map.dart';
import '../incident_detail_screen.dart';

class IncidentMapScreen extends StatefulWidget {
  const IncidentMapScreen({super.key});

  @override
  State<IncidentMapScreen> createState() => _IncidentMapScreenState();
}

class _IncidentMapScreenState extends State<IncidentMapScreen> {
  final _locationService = const LocationService();
  Position? _position;

  @override
  void initState() {
    super.initState();
    _obtain();
  }

  Future<void> _obtain() async {
    final position = await _locationService.getCurrentPosition();
    if (!mounted) return;
    setState(() => _position = position);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<IRepository>();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Incident map'),
        actions: [
          IconButton(
            onPressed: _obtain,
            icon: const Icon(Icons.my_location),
            tooltip: 'Centre on my location',
          ),
        ],
      ),
      body: StreamBuilder<List<Incident>>(
        stream: repo.watchAllIncidents(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.error_outline,
              title: 'Could not load incidents',
            );
          }
          final incidents = snapshot.data;
          if (incidents == null) return const LoadingScreen();
          final position = _position;
          return StreamBuilder<List<ResponderLocation>>(
            stream: repo.watchResponderLocations(),
            initialData: const [],
            builder: (context, responderSnapshot) {
              final responders = responderSnapshot.data ?? const [];
              return Column(
                children: [
                  Expanded(
                    child: IncidentMap(
                      incidents: incidents,
                      responders: responders,
                      centerLatitude: position?.latitude,
                      centerLongitude: position?.longitude,
                      currentUserLabel: 'You are here',
                      height: double.infinity,
                      onIncidentTap: (incident) =>
                          Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              IncidentDetailScreen(incident: incident),
                        ),
                      ),
                    ),
                  ),
                  if (responders.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.emergency,
                              size: 14, color: Color(0xFF2E7D32)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${responders.length} responder(s) live on the map.',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF6B6A6F)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (incidents.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No reported incidents to display.',
                          style: TextStyle(color: Color(0xFF6B6A6F))),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}