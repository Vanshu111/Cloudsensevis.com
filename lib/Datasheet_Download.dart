import 'dart:io' show File, Directory, Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;

class DownloadManager {
  static final Map<String, Map<String, String>> sensorFiles = {
    "WindSensor": {
      "manual": "assets/windSensor.pdf",
      "datasheet": "assets/ULTRASONIC_DATASHEET.pdf",
    },
    "ARTH": {
      "manual": "assets/windSensor.pdf",
      "datasheet": "assets/RADIATION_SHIELD_DATASHEET.pdf",
    },
    "RainGauge": {
      "manual": "assets/rainGauge.pdf",
      "datasheet": "assets/RAIN_GAUGE_DATASHEET.pdf",
    },
    "Gateway": {
      "manual": "assets/windSensor.pdf",
      "datasheet": "assets/BLE_GATEWAY_Datasheet.pdf",
    },
    "TempHumidityProbe": {
      "manual": "assets/windSensor.pdf",
      "datasheet": "assets/PROBE_DATASHEET.pdf",
    },
    "DataLogger": {
      "manual": "assets/dataLogger.pdf",
      "datasheet": "assets/Data_logger_datasheet.pdf",
    },
  };

  static Future<void> downloadFile({
    required BuildContext context,
    required String sensorKey,
    required String fileType,
  }) async {
    final filePath = sensorFiles[sensorKey]?[fileType];
    if (filePath == null) {
      _toast(context, "File not found");
      return;
    }

    if (kIsWeb) {
      final webPath = filePath.startsWith("assets/")
          ? filePath.replaceFirst("assets/", "assets/assets/")
          : filePath;
      final fullUrl = Uri.base.resolve(webPath).toString();

      if (await canLaunchUrl(Uri.parse(fullUrl))) {
        await launchUrl(Uri.parse(fullUrl));
      } else {
        _toast(context, "Could not open file in browser");
      }
      return;
    }

    try {
      final byteData = await rootBundle.load(filePath);
      final bytes = byteData.buffer.asUint8List();

      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory("/storage/emulated/0/Download");
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final file = File('${dir.path}/${sensorKey}_$fileType.pdf');
      await file.writeAsBytes(bytes);

      _toast(context, "Saved to ${file.path}");
    } catch (e) {
      _toast(context, "Error: $e");
    }
  }

  static void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}
