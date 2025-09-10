import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_sense_webapp/DeviceListPage.dart';
import 'Shared_Add_Device.dart';

class ManualEntryPopup extends StatefulWidget {
  final Map<String, List<String>> devices;

  ManualEntryPopup({required this.devices});

  @override
  _ManualEntryPopupState createState() => _ManualEntryPopupState();
}

class _ManualEntryPopupState extends State<ManualEntryPopup> {
  TextEditingController deviceIdController = TextEditingController();
  String? _email;
  String message = "";
  Color messageColor = Colors.teal;
  bool _canClose = true;

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  @override
  void dispose() {
    deviceIdController.dispose();
    super.dispose();
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
                Navigator.pop(context); // success/error dialog close
                Navigator.pop(context); // manual entry popup close
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
              'Add Device Manually',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: deviceIdController,
              decoration: InputDecoration(
                labelText: 'Enter Device ID',
                labelStyle: TextStyle(
                  color: isDarkMode ? Colors.black : Colors.white,
                ),
                border: OutlineInputBorder(),
                helperText: 'Enter the device ID (e.g., WD101, CL102, TH200)',
                helperStyle: TextStyle(
                  color: isDarkMode ? Colors.black : Colors.white,
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                String deviceId = deviceIdController.text.trim();
                if (deviceId.isNotEmpty) {
                  DeviceUtils.showConfirmationDialog(
                    context: context,
                    deviceId: deviceId,
                    devices: widget.devices,
                    onConfirm: () async {
                      await _addDevice(deviceId);
                      await _showSuccessMessage();
                    },
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid device ID'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: isDarkMode ? Colors.black : Colors.white,
                backgroundColor:
                    isDarkMode ? Colors.blueGrey[900] : Colors.grey[200],
              ),
              child: Text(
                'Add Device',
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
