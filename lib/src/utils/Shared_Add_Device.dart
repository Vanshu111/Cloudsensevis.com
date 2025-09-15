import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DeviceUtils {
  // ✅ NEW: The centralized function to add a device via API call
  static Future<bool> addDeviceToUser({
    required BuildContext context,
    required String? email,
    required String deviceId,
    required List<Map<String, dynamic>> allDevices,
  }) async {
    // --- 1. Validate Inputs using YOUR existing functions ---
    if (email == null || email.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("User email is not available."),
              backgroundColor: Colors.orange),
        );
      }
      return false;
    }
    // Note: We use your more detailed isValidDeviceId function here
    if (!isValidDeviceId(deviceId)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid Device ID format or prefix.")),
        );
      }
      return false;
    }

    // --- 2. Check if device is already registered in the system ---
    // This is crucial for the Admin Page to prevent re-assigning an existing device
    if (allDevices.any((d) => d['DeviceId'] == deviceId)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Device $deviceId is already registered in the system.")),
        );
      }
      return false;
    }

    // --- 3. Make the API Call ---
    final String apiUrl =
        "https://ymfmk699j5.execute-api.us-east-1.amazonaws.com/default/Cloudsense_user_add_devices?email_id=$email&device_id=$deviceId";

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (!context.mounted) return false;

      if (response.statusCode == 200) {
        String message = "Device $deviceId added successfully to $email.";
        bool success = false;
        try {
          final responseBody = json.decode(response.body);
          if (responseBody['message']
                  ?.toString()
                  .toLowerCase()
                  .contains('success') ==
              true) {
            success = true;
          } else {
            message =
                "Failed to add device: ${responseBody['message'] ?? 'Unknown error'}";
          }
        } on FormatException {
          if (response.body.toLowerCase().contains('success')) {
            success = true;
          } else {
            message = "Failed to add device: ${response.body}";
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        return success;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "API Error: Failed to add device (Status ${response.statusCode})"),
              backgroundColor: Colors.red),
        );
        return false;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("An error occurred: $e"),
              backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  // --- YOUR ORIGINAL FUNCTIONS (UNCHANGED) ---

  static String getSensorType(String deviceId) {
    if (deviceId.startsWith('WD')) return 'Weather Sensor';
    if (deviceId.startsWith('CL') || deviceId.startsWith('BD'))
      return 'Chlorine Sensor';
    if (deviceId.startsWith('SS')) return 'Soil Sensor';
    if (deviceId.startsWith('WQ')) return 'Water Quality Sensor';
    if (deviceId.startsWith('WS')) return 'Water Sensor';
    if (deviceId.startsWith('IT')) return 'IIT Bombay Sensor';
    if (deviceId.startsWith('DO')) return 'DO Sensor';
    if (deviceId.startsWith('LU')) return 'LU Sensor';
    if (deviceId.startsWith('TE')) return 'TE Sensor';
    if (deviceId.startsWith('AC')) return 'AC Sensor';
    if (deviceId.startsWith('BF')) return 'BF Sensor';
    if (deviceId.startsWith('CS')) return 'Cow Sensor';
    if (deviceId.startsWith('TH')) return 'Temperature Sensor';
    if (deviceId.startsWith('NH')) return 'Ammonia Sensor';
    if (deviceId.startsWith('FS')) return 'Forest Sensor (Bhopal)';
    if (deviceId.startsWith('SM')) return 'SSMET Sensor';
    if (deviceId.startsWith('CF')) return 'Sekhon Biotech Pvt Ltd Farm Sensor';
    if (deviceId.startsWith('SV'))
      return 'Sardar Vallabhbhai Patel University of Agriculture and TechnologySensor';
    if (deviceId.startsWith('CB')) return 'COD/BOD Sensor';
    if (deviceId.startsWith('WF')) return 'WF Sensor';
    if (deviceId.startsWith('KD')) return 'Kargil Sensor';
    if (deviceId.startsWith('VD')) return 'Vanix Sensor';
    if (deviceId.startsWith('NA'))
      return 'National Atmospheric Research Labortary Sensor';
    if (deviceId.startsWith('KJ')) return 'KJ Somaiya College of Engineering';
    if (deviceId.startsWith('MY')) return 'Mysuru NIE';
    if (deviceId.startsWith('CP')) return 'IIT Ropar Campus Sensor';
    return 'Rain Sensor';
  }

  static String getSensorPrefix(String deviceId) {
    if (deviceId.length < 2) return '';
    String prefix = deviceId.substring(0, 2);
    return validPrefixes.contains(prefix) ? prefix : 'RS';
  }

  static bool isValidDeviceId(String deviceId) {
    final RegExp deviceIdPattern = RegExp(r'^[A-Z]{2}\d{3}$');
    if (!deviceIdPattern.hasMatch(deviceId)) {
      return false;
    }
    String prefix = deviceId.substring(0, 2);
    return validPrefixes.contains(prefix);
  }

  static Future<void> showConfirmationDialog({
    required BuildContext context,
    required String deviceId,
    required Map<String, List<String>> devices,
    required Function onConfirm,
  }) async {
    if (!isValidDeviceId(deviceId)) {
      _showDialog(
        context: context,
        title: 'Invalid Device ID',
        content: 'Enter Valid Device ID.',
      );
      return;
    }
    String sensorType = getSensorType(deviceId);
    String sensorPrefix = getSensorPrefix(deviceId);

    final categoryDevices = devices.values
        .expand((deviceList) => deviceList)
        .where((device) => sensorPrefix == 'RS'
            ? !validPrefixes.any((prefix) => device.startsWith(prefix))
            : device.startsWith(sensorPrefix))
        .toList();
    int sensorNumber = categoryDevices.length + 1;

    bool deviceExists =
        devices.values.any((deviceList) => deviceList.contains(deviceId));

    if (deviceExists) {
      _showDialog(
        context: context,
        title: 'Device Already Exists',
        content: 'This $sensorType is already added to your account.',
      );
    } else {
      _showDialog(
        context: context,
        title: 'Confirm Device Addition',
        content:
            'Do you want to add $sensorType $sensorNumber to your account?',
        actions: [
          TextButton(
            child: Text('No'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('Yes'),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
          ),
        ],
      );
    }
  }

  static void _showDialog({
    required BuildContext context,
    required String title,
    required String content,
    List<Widget>? actions,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: actions ??
              [
                TextButton(
                  child: Text('OK'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
        );
      },
    );
  }

  static final List<String> validPrefixes = [
    'WD',
    'CL',
    'BD',
    'SS',
    'WQ',
    'WS',
    'DO',
    'LU',
    'TE',
    'AC',
    'BF',
    'CS',
    'TH',
    'NH',
    'IT',
    'FS',
    'SM',
    'CF',
    'SV',
    'CB',
    'WF',
    'KD',
    'VD',
    'NA',
    'CP',
    'KJ',
    'MY',
  ];
}
