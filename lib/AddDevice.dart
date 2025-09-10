import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_sense_webapp/DeviceListPage.dart';
import 'Shared_Add_Device.dart'; // Shared utilities file

class QRScannerPopup extends StatefulWidget {
  final Map<String, List<String>> devices;

  QRScannerPopup({required this.devices});

  @override
  _QRScannerPopupState createState() => _QRScannerPopupState();
}

class _QRScannerPopupState extends State<QRScannerPopup> {
  String? scannedQRCode;
  String message = "Position the QR code inside the scanner";
  late MobileScannerController _controller;
  String? _email;
  Color messageColor = Colors.teal;
  bool _canClose = true;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
    _loadEmail();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void resetScanner() {
    setState(() {
      scannedQRCode = null;
      message = "Position the QR code inside the scanner";
      _controller.stop();
      _controller.start();
    });
  }

  Future<void> _loadEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('email');

    setState(() {
      _email = email;
    });
  }

  Future<void> _showSuccessMessage() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Text(
            message,
            style: TextStyle(
              color: messageColor,
              fontSize: 16,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => DataDisplayPage()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _addDevice(String deviceID) async {
    setState(() {
      _canClose = false;
    });

    final String apiUrl =
        "https://ymfmk699j5.execute-api.us-east-1.amazonaws.com/default/Cloudsense_user_add_devices?email_id=$_email&device_id=$deviceID";

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        setState(() {
          message = "Device added successfully.";
          messageColor = Colors.green;
        });
      } else {
        setState(() {
          message = "Failed to add device. Please try again.";
          messageColor = Colors.red;
        });
      }
    } catch (e) {
      setState(() {
        message = "An error occurred: $e";
        messageColor = Colors.red;
      });
    }

    await _showSuccessMessage();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode
                ? [Color(0xFFC0B9B9), Color(0xFF7B9FAE)]
                : [Color(0xFF7EABA6), Color(0xFF363A3B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'QR Scanner',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDarkMode ? Colors.blueGrey[900]! : Colors.grey[200]!,
                  width: 4,
                ),
              ),
              child: MobileScanner(
                controller: _controller,
                onDetect: (BarcodeCapture capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    final String? code = barcode.rawValue;
                    if (code != null && code != scannedQRCode) {
                      setState(() {
                        scannedQRCode = code;
                        message = "Detected QR Code";
                      });
                      _controller.stop();
                      DeviceUtils.showConfirmationDialog(
                        context: context,
                        deviceId: code,
                        devices: widget.devices,
                        onConfirm: () async {
                          await _addDevice(code);
                        },
                      );
                      break;
                    }
                  }
                },
              ),
            ),
            SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(color: messageColor),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: resetScanner,
              style: ElevatedButton.styleFrom(
                foregroundColor: isDarkMode ? Colors.black : Colors.white,
                backgroundColor:
                    isDarkMode ? Colors.blueGrey[900] : Colors.grey[200],
              ),
              child: Text(
                'Scan Again',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
            SizedBox(height: 10),
            if (_canClose)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Close",
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
