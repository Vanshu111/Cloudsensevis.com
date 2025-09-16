import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // Added for date formatting

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
          // Return a summary with empty data
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
            isActive = diff.inHours <= 24;
          }

          // Format the lastReceivedTime to a readable string
          String formattedTime = lastTime != null
              ? DateFormat('yyyy-MM-dd HH:mm:ss').format(lastTime)
              : "N/A";

          devices.add({
            "DeviceId": deviceId,
            "lastReceivedTime": formattedTime,
            "isActive": isActive,
            "Group": topic.split('/')[0],
            "Topic": topic,
            // Ensure Lat/Lng are available for the map
            "LastKnownLongitude":
                deviceData['LastKnownLongitude']?.toString() ?? "0",
            "LastKnownLatitude":
                deviceData['LastKnownLatitude']?.toString() ?? "0",
          });
        }

        devices.sort((a, b) {
          if (a['isActive'] == b['isActive']) return 0;
          return (a['isActive'] as bool) ? -1 : 1;
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
        // API returned an error status code
        debugPrint("DeviceService API error: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      // General error (network issue, etc.)
      debugPrint("DeviceService fetch failed: $e");
      return null;
    }
  }

  /// Private helper to parse various date formats.
  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == "N/A") return null;
    try {
      // Remove any extra spaces
      dateStr = dateStr.trim().replaceAll(RegExp(r'\s+'), ' ');

      // Handle compact format: yyyyMMddTHHmmss
      final compactRegex = RegExp(r'^\d{8}T\d{6}$');
      if (compactRegex.hasMatch(dateStr)) {
        final y = int.parse(dateStr.substring(0, 4));
        final m = int.parse(dateStr.substring(4, 6));
        final d = int.parse(dateStr.substring(6, 8));
        final H = int.parse(dateStr.substring(9, 11));
        final M = int.parse(dateStr.substring(11, 13));
        final S = int.parse(dateStr.substring(13, 15));
        return DateTime(y, m, d, H, M, S);
      }

      // Try parsing yyyy-MM-dd HH:mm:ss
      final standardRegex = RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$');
      if (standardRegex.hasMatch(dateStr)) {
        return DateTime.parse(dateStr);
      }

      // Try parsing dd-MM-yyyy HH:mm:ss
      final customRegex = RegExp(r'^\d{2}-\d{2}-\d{4} \d{2}:\d{2}:\d{2}$');
      if (customRegex.hasMatch(dateStr)) {
        final parts = dateStr.split(' ');
        final dateParts = parts[0].split('-');
        final timeParts = parts[1].split(':');
        final d = int.parse(dateParts[0]);
        final m = int.parse(dateParts[1]);
        final y = int.parse(dateParts[2]);
        final H = int.parse(timeParts[0]);
        final M = int.parse(timeParts[1]);
        final S = int.parse(timeParts[2]);
        return DateTime(y, m, d, H, M, S);
      }

      // Fallback to DateTime.tryParse for other formats
      return DateTime.tryParse(dateStr);
    } catch (e) {
      if (kDebugMode) {
        print("Failed to parse date: $dateStr, error: $e");
      }
      return null;
    }
  }
}
