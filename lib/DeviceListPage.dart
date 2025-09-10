import 'dart:ui';
import 'package:cloud_sense_webapp/LoginPage.dart';
import 'package:cloud_sense_webapp/appbar.dart';
import 'package:cloud_sense_webapp/buffalodata.dart';
import 'package:cloud_sense_webapp/cowdata.dart';
import 'package:cloud_sense_webapp/drawer.dart';

import 'package:cloud_sense_webapp/GPS.dart';
import 'package:cloud_sense_webapp/Manually_Add_Device.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'AddDevice.dart';
import 'DeviceGraphPage.dart';
import 'HomePage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

class DataDisplayPage extends StatefulWidget {
  @override
  _DataDisplayPageState createState() => _DataDisplayPageState();
}

class _DataDisplayPageState extends State<DataDisplayPage> {
  bool _isLoading = true;
  Map<String, List<String>> _deviceCategories = {};
  String? _email;
  late ScrollController _scrollController;
  String? _selectedCategory; // Track the selected category for the dialog
  bool _shouldRestoreDialog = false; // Flag to control dialog restoration

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadEmail();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedEmail = prefs.getString('email');

    try {
      var currentUser = await Amplify.Auth.getCurrentUser();
      if (currentUser.username.trim().toLowerCase() ==
          "05agriculture.05@gmail.com") {
        // Redirect to DeviceInfoPage if this is the special user
        Navigator.pushReplacementNamed(context, '/deviceinfo');
        return; // Exit further execution
      }
      // Else continue on DeviceListPage normally
      setState(() {
        _email = savedEmail ?? currentUser.username;
      });
      _fetchData();
    } catch (e) {
      // No signed-in user — clear prefs & navigate to login screen
      await Amplify.Auth.signOut();
      await prefs.clear();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => SignInSignUpScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _fetchData() async {
    if (_email == null) return;

    final url =
        'https://ln8b1r7ld9.execute-api.us-east-1.amazonaws.com/default/Cloudsense_user_devices?email_id=$_email';
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        // Group LU, TE, and AC sensors under a single "CPS Lab Sensors" category
        Map<String, List<String>> groupedDevices = {};

        result.forEach((key, value) {
          if (key != 'device_id' && key != 'email_id') {
            String category = _mapCategory(key);

            // Group LU, TE, and AC sensors under "CPS Lab Sensors"
            if (key == 'LU' || key == 'TE' || key == 'AC') {
              category = 'CPS Lab Sensors';
            }

            if (groupedDevices[category] == null) {
              groupedDevices[category] = [];
            }

            groupedDevices[category]?.addAll(List<String>.from(value ?? []));
          }
        });

        setState(() {
          _deviceCategories = groupedDevices;
        });
      }
    } catch (error) {
      // Handle errors appropriately
      print('Error fetching data: $error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

// Restore dialog only when explicitly needed (e.g., after popping back)
  void _restoreDialog() {
    if (_shouldRestoreDialog &&
        _selectedCategory != null &&
        _deviceCategories.containsKey(_selectedCategory)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _shouldRestoreDialog) {
          // Ensure widget is mounted and restoration is still needed
          _showSensorsPopup(
              _selectedCategory!, _deviceCategories[_selectedCategory]!);
        }
      });
    }
  }

  String _mapCategory(String key) {
    switch (key) {
      case 'CL':
      case 'BD':
        return 'Chlorine Sensors';
      case 'WD':
        return 'Weather Sensors';
      case 'SS':
        return 'Soil Sensors';
      case 'WQ':
        return 'Water Quality Sensors';
      case 'DO':
        return 'DO Sensors';
      case 'IT':
        return 'IIT Bombay\nWeather Sensors';
      case 'WS':
        return 'Water Sensors';
      case 'LU':
      case 'TE':
      case 'AC':
        return 'CPS Lab Sensors'; // All grouped under CPS Lab Sensors
      case 'BF':
        return 'Buffalo Sensors';
      case 'CS':
        return 'Cow Sensors';
      case 'TH':
        return 'Temperature Sensors';
      case 'NH':
        return 'Ammonia Sensors';
      case 'FS':
        return 'Forest Sensors\n(Bhopal)';
      case 'SM':
        return 'SSMET Sensors';
      case 'CF':
        return 'Sekhon Biotech Pvt\nLtd Farm Sensors';
      case 'SV':
        return 'Sardar Vallabhbhai Patel University of Agriculture\nand Technology Sensors (Meerut)';
      case 'CB':
        return 'COD/BOD Sensors';
      case 'WF':
        return 'WF Sensors';
      case 'KD':
        return 'Kargil Sensors';
      case 'VD':
        return 'Vanix Sensors';
      case 'NA':
        return 'National Atmospheric Research Labortary\nSensors';
      case 'CP':
        return 'IIT Ropar Campus\nSensors';
      case 'KJ':
        return 'KJ Somaiya College of Engineering Sensors';
      case 'MY':
        return 'Mysuru NIE Sensors';
      default:
        return 'Rain Sensors';
    }
  }

  Future<void> _handleLogout() async {
    try {
      print("[Logout] Starting logout process.");

      await Amplify.Auth.signOut();
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print("[Logout] User signed out and preferences cleared.");

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      print("[Logout] Primary logout failed: $e");
      // Fallback logout
      try {
        await Amplify.Auth.signOut();
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        print("[Logout] Fallback logout success.");

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
          (Route<dynamic> route) => false,
        );
      } catch (logoutError) {
        print("[Logout] Fallback logout failed: $logoutError");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    final isWideScreen = screenWidth > 1024; // Desktop
    // Restore dialog after build
    _restoreDialog();
    return Scaffold(
      appBar: AppBarWidget(),
      endDrawer: !isWideScreen ? const EndDrawerWidget() : null,
      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode
                ? [
                    const Color.fromARGB(255, 57, 57, 57),
                    const Color.fromARGB(255, 2, 54, 76),
                  ]
                : [
                    const Color.fromARGB(255, 191, 242, 237),
                    const Color.fromARGB(255, 79, 106, 112),
                  ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // IconButton(
                    //   icon: Icon(
                    //     Icons.arrow_back,
                    //     color: isDarkMode ? Colors.white : Colors.black,
                    //     size: MediaQuery.of(context).size.width < 800 ? 20 : 28,
                    //   ),
                    //   onPressed: () => Navigator.pop(context),
                    // ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Center(
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 16.0, right: 16.0),
                                    child: Text(
                                      "Select a device to unlock insights into data.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'OpenSans',
                                        fontSize:
                                            MediaQuery.of(context).size.width <
                                                    800
                                                ? 30
                                                : 45,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 50),
                                  _deviceCategories.isNotEmpty ||
                                          _email == 'sharmasejal2701@gmail.com'
                                      ? _buildCategoryCards()
                                      : _buildNoDevicesCard(),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCards() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Create the list of categories, including "AddDevice" and conditionally "GPS"
    final categories = [
      ..._deviceCategories.keys,
      if (_email == 'sharmasejal2701@gmail.com') 'GPS',
      "AddDevice"
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(32),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: 1.1,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        String category = categories[index];

        return _HoverableCard(
          isDarkMode: isDarkMode,
          category: category,
          onTap: () {
            if (category == "AddDevice") {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Center(
                      child: Text(
                        "Add New Device",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) =>
                                  QRScannerPopup(devices: _deviceCategories),
                            );
                          },
                          child: Text(" Scan QR Code"),
                        ),
                        SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            showDialog(
                              context: context,
                              builder: (context) =>
                                  ManualEntryPopup(devices: _deviceCategories),
                            );
                          },
                          child: Text(" Add Manually"),
                        ),
                      ],
                    ),
                  );
                },
              );
            } else if (category == "GPS") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MapPage()),
              );
            } else {
              setState(() {
                _selectedCategory = category; // Save the category
                _shouldRestoreDialog =
                    true; // Enable restoration for this category
              });
              _showSensorsPopup(category, _deviceCategories[category]!);
            }
          },
          getCardColor: _getCardColor,
          getCardTextColor: _getCardTextColor,
        );
      },
    );
  }

  void _showSensorsPopup(String category, List<String> sensors) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    int luxSensorCount = 0;
    int tempSensorCount = 0;
    int accelerometerSensorCount = 0;

    showDialog(
      context: context,
      builder: (context) {
        double screenWidth = MediaQuery.of(context).size.width;
        double screenHeight = MediaQuery.of(context).size.height;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            width: screenWidth * 0.6,
            height: screenHeight * 0.6,
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [
                        const Color.fromARGB(255, 57, 57, 57),
                        const Color.fromARGB(255, 2, 54, 76),
                      ]
                    : [
                        const Color.fromARGB(255, 191, 242, 237),
                        const Color.fromARGB(255, 79, 106, 112),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Title
                Text(
                  category,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                    shadows: [
                      Shadow(
                        color: Colors.black45,
                        offset: Offset(2, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                // Sensor List
                Expanded(
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: ListView.builder(
                      itemCount: sensors.length,
                      itemBuilder: (context, index) {
                        String sensorName = sensors[index];
                        String sequentialName = '';

                        if (category == 'CPS Lab Sensors') {
                          if (sensorName.contains('LU')) {
                            luxSensorCount++;
                            sequentialName = 'Lux Sensor $luxSensorCount';
                          } else if (sensorName.contains('TE')) {
                            tempSensorCount++;
                            sequentialName =
                                'Temperature Sensor $tempSensorCount';
                          } else if (sensorName.contains('AC')) {
                            accelerometerSensorCount++;
                            sequentialName =
                                'Accelerometer Sensor $accelerometerSensorCount';
                          }
                        } else if (category == 'IIT Bombay Sensors') {
                          sequentialName = 'IIT Bombay Sensor ${index + 1}';
                        } else if (category == 'IIT Ropar Sensors') {
                          sequentialName = 'IIT Ropar Sensor ${index + 1}';
                        } else if (category == 'Forest Sensors\n(Bhopal)') {
                          sequentialName = 'Forest Sensor ${index + 1}';
                        } else if (category == 'SSMET Sensors') {
                          sequentialName = 'SSMET Sensor ${index + 1}';
                        } else if (category ==
                            'Sekhon Biotech Pvt\nLtd Farm Sensors') {
                          sequentialName = 'Sekhon Farm Sensor ${index + 1}';
                        } else if (category ==
                            'Sardar Vallabhbhai Patel University of Agriculture\nand Technology Sensors (Meerut)') {
                          sequentialName = 'SVPU Sensor ${index + 1}';
                        } else if (category ==
                            'National Atmospheric Research Labortary\nSensors') {
                          sequentialName = 'NARL Sensor ${index + 1}';
                        } else {
                          sequentialName =
                              '${category.split(" ").first} Sensor ${index + 1}';
                        }

                        String buttonLabel = '$sequentialName ($sensorName)';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  colors: isDarkMode
                                      ? [Color(0xFF3B6A7F), Color(0xFF8C6C8E)]
                                      : [
                                          Color.fromARGB(255, 92, 129, 123),
                                          Color.fromARGB(255, 40, 53, 70)
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(2, 2),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(context); // Close the dialog
                                  setState(() {
                                    _shouldRestoreDialog =
                                        false; // Prevent immediate restoration
                                  });
                                  // Store the category to restore later
                                  String currentCategory = _selectedCategory!;
                                  if (sensorName.startsWith('BF')) {
                                    String numericNodeId = sensorName
                                        .replaceAll(RegExp(r'\D'), '');
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => BuffaloData(
                                          startDateTime: DateTime.now(),
                                          endDateTime: DateTime.now()
                                              .add(Duration(days: 1)),
                                          nodeId: numericNodeId,
                                        ),
                                      ),
                                    ).then((_) {
                                      setState(() {
                                        _selectedCategory = currentCategory;
                                        _shouldRestoreDialog = true;
                                      });
                                    });
                                  } else if (sensorName.startsWith('CS')) {
                                    String numericNodeId = sensorName
                                        .replaceAll(RegExp(r'\D'), '');
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CowData(
                                          startDateTime: DateTime.now(),
                                          endDateTime: DateTime.now()
                                              .add(Duration(days: 1)),
                                          nodeId: numericNodeId,
                                        ),
                                      ),
                                    ).then((_) {
                                      setState(() {
                                        _selectedCategory = currentCategory;
                                        _shouldRestoreDialog = true;
                                      });
                                    });
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DeviceGraphPage(
                                          deviceName: sensorName,
                                          sequentialName: sequentialName,
                                          backgroundImagePath:
                                              'assets/backgroundd.jpg',
                                        ),
                                      ),
                                    ).then((_) {
                                      // Restore dialog after popping back
                                      setState(() {
                                        _selectedCategory = currentCategory;
                                        _shouldRestoreDialog = true;
                                      });
                                    });
                                  }
                                },
                                child: Text(
                                  buttonLabel,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(height: 16),

                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedCategory = null; // Clear the selected category
                      _shouldRestoreDialog = false; // Prevent restoration
                    });
                    Navigator.pop(context); // Close the dialog
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    "Close",
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoDevicesCard() {
    return Center(
      child: Container(
        width: 300,
        height: 300,
        margin: EdgeInsets.all(10),
        child: Card(
          color: Colors.grey[200],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // "No devices found." message
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No Device Found',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(255, 235, 28, 28),
                  ),
                ),
              ),
              SizedBox(height: 10),
              // "Add New Device" heading
              Text(
                'Add New Device',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                    backgroundColor: Colors.black),
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) =>
                        QRScannerPopup(devices: _deviceCategories),
                  );
                },
                child: Text(
                  'Scan QR Code',
                  style: TextStyle(fontSize: 16),
                ),
              ),

              SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                  backgroundColor: Colors.black,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) =>
                        ManualEntryPopup(devices: _deviceCategories),
                  );
                },
                child: Text(
                  'Add Manually',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Color _getCardColor(String category) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode ? Colors.white : Colors.grey[200]!;
  }

  Color _getCardTextColor() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return isDarkMode ? Colors.white : Colors.black;
  }
}

class _HoverableCard extends StatefulWidget {
  final bool isDarkMode;
  final String category;
  final VoidCallback onTap;
  final Color Function(String) getCardColor;
  final Color Function() getCardTextColor;

  const _HoverableCard({
    required this.isDarkMode,
    required this.category,
    required this.onTap,
    required this.getCardColor,
    required this.getCardTextColor,
  });

  @override
  State<_HoverableCard> createState() => _HoverableCardState();
}

class _HoverableCardState extends State<_HoverableCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedScale(
        scale: _isHovering ? 1.15 : 1.0,
        duration: Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: widget.isDarkMode
                    ? (_isHovering
                        ? [const Color(0xFF3B6A7F), const Color(0xFF8C6C8E)]
                        : [
                            const Color.fromARGB(255, 59, 138, 171),
                            const Color.fromARGB(228, 69, 59, 71)
                          ])
                    : (_isHovering
                        ? [const Color(0xFF5BAA9D), const Color(0xFFA7DCA1)]
                        : [
                            const Color.fromARGB(255, 73, 117, 121),
                            const Color(0xFF81C784)
                          ]),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: _isHovering ? 10 : 4,
                  offset: Offset(2, 2),
                ),
              ],
            ),
            child: Center(
              child: widget.category == "AddDevice"
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add,
                          size: 24, // Adjust size as needed
                          color:
                              widget.isDarkMode ? Colors.white : Colors.black,
                        ),
                        const SizedBox(
                            height: 8), // Space between icon and text
                        Text(
                          "Add Device",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width < 800
                                ? 12
                                : 14,
                            fontWeight: FontWeight.bold,
                            color:
                                widget.isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      widget.category,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize:
                            MediaQuery.of(context).size.width < 800 ? 10 : 14,
                        fontWeight: FontWeight.bold,
                        color: widget.getCardTextColor(),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
