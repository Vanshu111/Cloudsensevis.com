import 'dart:convert';

import 'package:cloud_sense_webapp/main.dart';
import 'package:cloud_sense_webapp/src/utils/DeleteDevice.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class AccountInfoPage extends StatefulWidget {
  @override
  _AccountInfoPageState createState() => _AccountInfoPageState();
}

class _AccountInfoPageState extends State<AccountInfoPage> {
  String? userId;
  String? userEmail;
  String? device_id;
  bool _isLoading = true;
  Map<String, List<String>> deviceCategories = {};
  TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      userEmail = prefs.getString('email') ?? 'Unknown';
      _emailController.text = userEmail ?? '';

      await _fetchData();

      setState(() {});
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _fetchData() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please enter a valid email."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      deviceCategories.clear();
    });

    final url =
        'https://ln8b1r7ld9.execute-api.us-east-1.amazonaws.com/default/Cloudsense_user_devices?email_id=$email';
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        setState(() {
          deviceCategories = {
            for (var key in result.keys)
              if (key != 'device_id' && key != 'email_id')
                key: List<String>.from(result[key] ?? [])
          };
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to load devices. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
        print('Failed to load devices. Status Code: ${response.statusCode}');
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error fetching data."),
          backgroundColor: Colors.red,
        ),
      );
      print('Error fetching data: $error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(
            color: isDarkMode ? Colors.white : Colors.black,
            size: MediaQuery.of(context).size.width < 800 ? 16 : 32),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [
                        const Color.fromARGB(255, 57, 57, 57)!,
                        const Color.fromARGB(255, 2, 54, 76)!,
                      ]
                    : [
                        const Color.fromARGB(255, 191, 242, 237)!,
                        const Color.fromARGB(255, 79, 106, 112)!,
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 60),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Enter Email ID',
                    labelStyle: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: isDarkMode ? Colors.redAccent : Colors.red,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _fetchData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDarkMode
                        ? const Color.fromARGB(255, 6, 94, 138)
                        : Colors.white,
                    foregroundColor: Colors.white,
                  ),
                  child: Text("Fetch Devices",
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                      )),
                ),
                SizedBox(height: 40),
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : deviceCategories.isNotEmpty
                        ? Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Center(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isDarkMode
                                            ? Colors.black
                                            : Colors.white,
                                        width: 2.0,
                                      ),
                                    ),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight: constraints.maxHeight,
                                      ),
                                      child: SingleChildScrollView(
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: DataTable(
                                            headingRowColor:
                                                MaterialStateProperty.all(
                                                    isDarkMode
                                                        ? const Color.fromARGB(
                                                            255, 6, 94, 138)
                                                        : Colors.white),
                                            dataRowColor:
                                                MaterialStateProperty.all(
                                                    isDarkMode
                                                        ? const Color.fromARGB(
                                                            255, 5, 35, 49)
                                                        : const Color.fromARGB(
                                                            255,
                                                            129,
                                                            173,
                                                            166)),
                                            columnSpacing: 20.0,
                                            columns: deviceCategories.keys
                                                .map((sensorKey) => DataColumn(
                                                      label: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8.0),
                                                        child: Text(
                                                          sensorKey.trim(),
                                                          style: TextStyle(
                                                            color: isDarkMode
                                                                ? Colors.white
                                                                : Colors.black,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: MediaQuery.of(
                                                                            context)
                                                                        .size
                                                                        .width <
                                                                    400
                                                                ? 10
                                                                : MediaQuery.of(context)
                                                                            .size
                                                                            .width <
                                                                        800
                                                                    ? 13
                                                                    : 22,
                                                          ),
                                                        ),
                                                      ),
                                                    ))
                                                .toList(),
                                            rows: List.generate(
                                              deviceCategories.values
                                                  .map((list) => list.length)
                                                  .reduce(
                                                      (a, b) => a > b ? a : b),
                                              (index) => DataRow(
                                                cells: deviceCategories.keys
                                                    .map((sensorKey) {
                                                  final devices =
                                                      deviceCategories[
                                                          sensorKey]!;
                                                  final device =
                                                      index < devices.length
                                                          ? devices[index]
                                                          : '';
                                                  return DataCell(
                                                    Text(
                                                      device.isNotEmpty
                                                          ? '• $device'
                                                          : '',
                                                      style: TextStyle(
                                                        color: isDarkMode
                                                            ? Colors.white
                                                            : Colors.black,
                                                        fontSize: MediaQuery.of(
                                                                        context)
                                                                    .size
                                                                    .width <
                                                                400
                                                            ? 7
                                                            : MediaQuery.of(context)
                                                                        .size
                                                                        .width <
                                                                    800
                                                                ? 10
                                                                : 20,
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : Text(
                            'No devices found',
                            style: TextStyle(
                              fontSize: 18,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                Spacer(),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () => DeleteDeviceUtils.deleteDevices(
                          context,
                          userEmail ?? '',
                          deviceCategories,
                          (updatedCategories) {
                            setState(() {
                              deviceCategories = updatedCategories;
                              // Trigger notification subscription management
                              checkAndUpdateNotificationSubscription();
                            });
                          },
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: Text("Delete Devices"),
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => DeleteDeviceUtils.deleteAccount(
                          context,
                          _emailController.text.trim(),
                          userEmail,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: Text("Delete Account"),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
