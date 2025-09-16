import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // Import the intl package

/// A data model to hold the results of the device activity fetch.
class DeviceActivitySummary {
  final List<Map<String, dynamic>> allDevices;
  final int totalDevices;
  final int totalActive;
  final int totalInactive;

  DeviceActivitySummary({
    required this.allDevices,
    required this.totalDevices,
    required this.totalActive,
    required this.totalInactive,
  });
}

/// A service class to handle fetching and processing device activity data.
class DeviceService {
  final String _apiUrl =
      "https://d1b09mxwt0ho4j.cloudfront.net/default/WS_Device_Activity";

  /// Fetches device data from the API and processes it.
  /// Returns a [DeviceActivitySummary] on success, or null on failure.
  Future<DeviceActivitySummary?> fetchDeviceActivity() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic>? devicesList = data['devices'];

        if (devicesList == null || devicesList.isEmpty) {
          return DeviceActivitySummary(
              allDevices: [],
              totalDevices: 0,
              totalActive: 0,
              totalInactive: 0);
        }

        List<Map<String, dynamic>> devices = [];
        for (var deviceData in devicesList) {
          final deviceIdTopic = deviceData['deviceid#topic']?.toString() ?? "";
          if (deviceIdTopic.isEmpty) continue;

          final parts = deviceIdTopic.split('#');
          if (parts.length < 2) continue;

          final deviceId = parts[0];
          final topic = parts.sublist(1).join('#');

          if (topic.startsWith('BF/') || topic.startsWith('CS/')) {
            continue;
          }

          DateTime? lastTime = _parseDate(deviceData['TimeStamp_IST']);
          bool isActive = false;
          if (lastTime != null) {
            final diff = DateTime.now().difference(lastTime);
            // Device is active if it sent data within the last 24 hours
            isActive = diff.inHours <= 24;
          }

          devices.add({
            "DeviceId": deviceId,
            "lastReceivedTime": lastTime?.toIso8601String() ?? "N/A",
            "isActive": isActive,
            "Group": topic.split('/')[0],
            "Topic": topic,
            "LastKnownLongitude":
                deviceData['LastKnownLongitude']?.toString() ?? "0",
            "LastKnownLatitude":
                deviceData['LastKnownLatitude']?.toString() ?? "0",
          });
        }

        // Sort by active status first, then by DeviceId
        devices.sort((a, b) {
          if (a['isActive'] != b['isActive']) {
            return (a['isActive'] as bool) ? -1 : 1;
          }
          return (a['DeviceId'] as String).compareTo(b['DeviceId'] as String);
        });

        int activeCount = devices.where((d) => d['isActive'] as bool).length;
        int inactiveCount = devices.length - activeCount;

        return DeviceActivitySummary(
          allDevices: devices,
          totalDevices: devices.length,
          totalActive: activeCount,
          totalInactive: inactiveCount,
        );
      } else {
        debugPrint("DeviceService API error: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("DeviceService fetch failed: $e");
      return null;
    }
  }

  /// Private helper to parse various date formats.
  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr.toLowerCase() == "n/a") {
      return null;
    }

    // A list of common date formats to try
    final formats = [
      "yyyy-MM-dd HH:mm:ss", // e.g., 2025-09-16 10:30:00
      "dd-MM-yyyy HH:mm:ss", // e.g., 16-09-2025 10:30:00
      "MM/dd/yyyy HH:mm:ss", // e.g., 09/16/2025 10:30:00
    ];

    dateStr = dateStr.trim();

    // First, try the standard ISO 8601 parser which is very common
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      // It's not an ISO string, so we'll try our other formats.
    }

    // If that fails, iterate through our list of custom formats
    for (var formatString in formats) {
      try {
        return DateFormat(formatString).parse(dateStr);
      } catch (_) {
        // Ignore and try the next format
      }
    }

    debugPrint("Failed to parse date with any known format: $dateStr");
    return null;
  }
}
