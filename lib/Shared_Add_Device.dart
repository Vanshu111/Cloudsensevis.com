import 'package:flutter/material.dart';

class DeviceUtils {
  // Determine the sensor type based on the device ID prefix
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

  // Extract the sensor prefix from the device ID
  static String getSensorPrefix(String deviceId) {
    if (deviceId.length < 2) return '';
    String prefix = deviceId.substring(0, 2);
    return validPrefixes.contains(prefix) ? prefix : 'RS';
  }

  // Validate device ID format (2 uppercase letters + 3 digits)
  static bool isValidDeviceId(String deviceId) {
    // Check if deviceId matches the pattern: 2 uppercase letters followed by 3 digits
    final RegExp deviceIdPattern = RegExp(r'^[A-Z]{2}\d{3}$');
    if (!deviceIdPattern.hasMatch(deviceId)) {
      return false;
    }
    // Check if the prefix is in the validPrefixes list
    String prefix = deviceId.substring(0, 2);
    return validPrefixes.contains(prefix);
  }

  // Display a confirmation dialog for adding a device
  static Future<void> showConfirmationDialog({
    required BuildContext context,
    required String deviceId,
    required Map<String, List<String>> devices,
    required Function onConfirm,
  }) async {
    // Validate device ID
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

    // Count existing devices of the same type
    final categoryDevices = devices.values
        .expand((deviceList) => deviceList)
        .where((device) => sensorPrefix == 'RS'
            ? !validPrefixes.any(
                (prefix) => device.startsWith(prefix)) // Unknown sensor check
            : device.startsWith(sensorPrefix))
        .toList();
    int sensorNumber = categoryDevices.length + 1;

    // Check if the device already exists
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

  // Generic function to display dialogs
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

  // List of valid sensor prefixes
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
