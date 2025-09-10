import 'dart:convert';
import 'package:cloud_sense_webapp/devicelocationinfo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:ui'; // Required for ImageFilter

class DeviceMapScreen extends StatefulWidget {
  @override
  _DeviceMapScreenState createState() => _DeviceMapScreenState();
}

class _DeviceMapScreenState extends State<DeviceMapScreen> {
  final MapController mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  LatLng centerCoordinates = LatLng(22.9734, 78.6569); // Center of India
  double zoomLevel = 5.5;
  Marker? searchPin;
  String searchQuery = '';
  List<Map<String, dynamic>> deviceLocations = [];
  List<Map<String, dynamic>> suggestions = [];
  final Map<String, String> deviceImageMap = {
    '5': 'assets/5.jpg',
    '25': 'assets/25.jpg',
    '28': 'assets/28.jpg'
    // Add more as needed
  };

  @override
  void initState() {
    super.initState();
    _loadDeviceDataFromApi();
  }

  Future<Map<String, String>> _getLocationDetails(
      double lat, double lon) async {
    final url =
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1';

    final response = await http.get(Uri.parse(url), headers: {
      'User-Agent': 'YourAppName/1.0 (contact@example.com)',
    });

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final addr = data['address'] ?? {};

      // Choose the most specific field available:
      final place = addr['attraction'] ??
          addr['building'] ??
          addr['neighbourhood'] ??
          addr['suburb'] ??
          addr['city'] ??
          addr['amenity'] ??
          addr['building'] ??
          addr['hamlet'] ??
          addr['village'] ??
          addr['town'] ??
          addr['city'] ??
          addr['county'] ??
          '';

      return {
        'place': place,
        'state': addr['state'] ?? '',
        'country': addr['country'] ?? '',
      };
    }

    return {'place': '', 'state': '', 'country': ''};
  }

  Future<void> _loadDeviceDataFromApi() async {
    final url =
        'https://xa9ry8sls0.execute-api.us-east-1.amazonaws.com/CloudSense_device_activity_api_function';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        // Extract devices from both Awadh_Jio and WS_Device_Activity
        final List<dynamic> awadhDevices =
            jsonResponse['Awadh_Jio_Device_Activity'] ?? [];
        final List<dynamic> wsDevices =
            jsonResponse['WS_Device_Activity'] ?? [];

        // Combine both lists
        final List<dynamic> combinedDevices = [...awadhDevices, ...wsDevices];

        final List<Map<String, dynamic>> devicesWithLocation = [];

        for (var item in combinedDevices) {
          final lat = item['LastKnownLatitude'];
          final lon = item['LastKnownLongitude'];

          if (lat != null && lon != null) {
            final location = await _getLocationDetails(
                (lat as num).toDouble(), (lon as num).toDouble());

            devicesWithLocation.add({
              'deviceId': item['DeviceId'].toString(),
              'latitude': (lat).toDouble(),
              'longitude': (lon).toDouble(),
              'last_active': item['lastReceivedTime'],
              'topic': item['Topic'] ?? 'N/A',
              'place': location['place'],
              'state': location['state'],
              'country': location['country'],
            });
          }
        }

        setState(() {
          deviceLocations = devicesWithLocation;
        });
      } else {
        _showError('Failed to load devices: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Error loading devices: $e');
    }
  }

  void _showDeviceInfoDialog(
      BuildContext context, Map<String, dynamic> device) {
    final deviceId = device['deviceId'];
    bool isToday = false;
    try {
      if (device['last_active'] != null) {
        final lastActive = DateTime.tryParse(device['last_active'].toString());
        if (lastActive != null) {
          final now = DateTime.now();
          isToday = lastActive.year == now.year &&
              lastActive.month == now.month &&
              lastActive.day == now.day;
        }
      }
    } catch (_) {
      isToday = false;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3), // dim background
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent, // make dialog itself transparent
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // blur effect
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color:
                    Colors.black.withOpacity(0.2), // semi-transparent overlay
                borderRadius: BorderRadius.circular(16),
              ),
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isToday ? Colors.green : Colors.red,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Device $deviceId',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Latitude: ${device['latitude']}',
                    style: TextStyle(color: Colors.white),
                  ),
                  Text(
                    'Longitude: ${device['longitude']}',
                    style: TextStyle(color: Colors.white),
                  ),
                  Text(
                    'Location: ${device['place']}, ${device['state']}, ${device['country']}',
                    style: TextStyle(color: Colors.white),
                  ),
                  Text(
                    'Last Active: ${device['last_active']}',
                    style: TextStyle(color: Colors.white),
                  ),
                  Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: TextButton(
                      child: Text(
                        'Close',
                        style: TextStyle(color: Colors.white),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _geocode(String query) async {
    try {
      final url =
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'CloudSenseApp/1.0 (contact@example.com)'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.isNotEmpty &&
            data[0]['lat'] != null &&
            data[0]['lon'] != null) {
          double lat = double.parse(data[0]['lat']);
          double lon = double.parse(data[0]['lon']);
          LatLng searchCoordinates = LatLng(lat, lon);
          setState(() {
            centerCoordinates = searchCoordinates;
            zoomLevel = 10.0;
            searchPin = Marker(
              width: 80.0,
              height: 80.0,
              point: searchCoordinates,
              child: GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text('Searched Location'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Location: $query'),
                          Text('Latitude: $lat'),
                          Text('Longitude: $lon'),
                        ],
                      ),
                      actions: [
                        TextButton(
                          child: Text('Close'),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  );
                },
                child: Icon(Icons.location_pin, size: 40, color: Colors.blue),
              ),
            );
          });
          mapController.move(searchCoordinates, zoomLevel);
        } else {
          _showError(
              "No results found for '$query'. Try a more specific query.");
        }
      } else {
        _showError("Failed to fetch location: ${response.statusCode}");
      }
    } catch (e) {
      _showError('Error during geocoding: $e');
    }
  }

  void _searchDevices(String query) async {
    setState(() {
      searchQuery = query.toLowerCase();
      searchPin = null;
    });

    final filteredDevices = deviceLocations.where((device) {
      return device['place']?.toLowerCase().contains(searchQuery) == true ||
          device['state']?.toLowerCase().contains(searchQuery) == true ||
          device['country']?.toLowerCase().contains(searchQuery) == true ||
          device['name']?.toLowerCase().contains(searchQuery) == true;
    }).toList();

    if (query.isEmpty) {
      setState(() {
        centerCoordinates = LatLng(22.9734, 78.6569);
        zoomLevel = 5.5;
        searchPin = null;
      });
      mapController.move(centerCoordinates, zoomLevel);
      return;
    }

    if (filteredDevices.isNotEmpty) {
      final device = filteredDevices.first;
      setState(() {
        centerCoordinates = LatLng(device['latitude'], device['longitude']);
        zoomLevel = 10.0;
        searchPin = null;
      });
      mapController.move(centerCoordinates, zoomLevel);
    } else {
      await _geocode(query);
    }
  }

  void _updateSuggestions(String query) {
    if (query.isEmpty) {
      setState(() {
        suggestions = [];
        searchPin = null;
      });
      return;
    }

    setState(() {
      suggestions = deviceLocations
          .where((device) =>
              device['name'].toLowerCase().contains(query.toLowerCase()) ||
              device['place'].toLowerCase().contains(query.toLowerCase()) ||
              device['state'].toLowerCase().contains(query.toLowerCase()) ||
              device['country'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    _searchController.text = suggestion['place'];
    _searchDevices(suggestion['place']);
    setState(() {
      suggestions = [];
    });
  }

  TileLayer _getSatelliteTileLayer() {
    return TileLayer(
      urlTemplate:
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      userAgentPackageName: 'com.CloudSenseVis',
      tileProvider: NetworkTileProvider(),
    );
  }

  TileLayer _getLabelOverlayLayer() {
    return TileLayer(
      urlTemplate:
          'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
      userAgentPackageName: 'com.CloudSenseVis',
      tileProvider: NetworkTileProvider(), // Make sure this is explicitly set
    );
  }

  void _reloadDevices() {
    setState(() {
      _loadDeviceDataFromApi();

      centerCoordinates = LatLng(22.9734, 78.6569);
      zoomLevel = 5.5;
      searchPin = null;
      suggestions = [];
      _searchController.clear();
    });
    mapController.move(centerCoordinates, zoomLevel);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Colors.black, // Set back arrow to black
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Reload Devices',
            onPressed: _reloadDevices,
          ),
          IconButton(
            icon: Icon(Icons.list, color: Colors.white),
            tooltip: 'Device List',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DeviceActivityPage()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: centerCoordinates,
              initialZoom: zoomLevel,
              minZoom: 2.0,
              maxZoom: 19.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              keepAlive: true,
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(
                  LatLng(-85.05112878, -180),
                  LatLng(85.05112878, 180),
                ),
              ),
            ),
            children: [
              _getSatelliteTileLayer(),
              Opacity(
                opacity: 0.8,
                child: _getLabelOverlayLayer(),
              ),
              MarkerLayer(
                markers: [
                  ...deviceLocations.map((device) {
                    // Parse last_active date
                    bool isToday = false;
                    try {
                      if (device['last_active'] != null) {
                        final lastActive =
                            DateTime.tryParse(device['last_active'].toString());
                        if (lastActive != null) {
                          final now = DateTime.now();
                          isToday = lastActive.year == now.year &&
                              lastActive.month == now.month &&
                              lastActive.day == now.day;
                        }
                      }
                    } catch (_) {
                      isToday = false;
                    }

                    return Marker(
                      point: LatLng(
                        (device['latitude'] as num).toDouble(),
                        (device['longitude'] as num).toDouble(),
                      ),
                      width: 80,
                      height: 80,
                      child: GestureDetector(
                        onTap: () => _showDeviceInfoDialog(context, device),
                        child: Icon(
                          Icons.location_on,
                          size: 40,
                          color: Colors.red,
                        ),
                      ),
                    );
                  }).toList(),
                  if (searchPin != null) searchPin!,
                ],
              )
            ],
          ),
          Positioned(
            top: 80.0,
            left: 16.0,
            right: 16.0,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4.0,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search City, Country, or Lat,Lng',
                      hintStyle: TextStyle(
                        color: Colors.black,
                      ),
                      prefixIcon: Icon(Icons.search, color: Colors.black),
                      filled: false, // ← do not fill background again
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 10.0),
                    ),
                    onChanged: _updateSuggestions,
                    onSubmitted: _searchDevices,
                  ),
                ),
                if (suggestions.isNotEmpty)
                  Container(
                    constraints: BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4.0,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = suggestions[index];
                        return ListTile(
                          title: Text(suggestion['place']),
                          subtitle: Text(
                              '${suggestion['state']}, ${suggestion['country']}'),
                          onTap: () => _selectSuggestion(suggestion),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
