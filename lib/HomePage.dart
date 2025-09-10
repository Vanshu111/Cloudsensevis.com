import 'dart:convert';
import 'dart:math';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:cloud_sense_webapp/devicelocationinfo.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'main.dart';
import 'dart:async';
import 'package:universal_html/html.dart' as html;

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadTheme();
  }

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  void _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Color _aboutUsColor = const Color.fromARGB(255, 235, 232, 232);
  Color _accountinfoColor = const Color.fromARGB(255, 235, 232, 232);
  Color _devicemapinfoColor = const Color.fromARGB(255, 235, 232, 232);
  int _totalDevices = 0;
  bool _isHovered = false;
  bool _isHoveredMyDevicesButton = false;
  bool _isPressedMyDevicesButton = false;
  bool _isHoveredbutton = false;
  bool _isPressed = false;
  bool _isProductsExpanded = false; // For mobile drawer products expansion
  // Add a GlobalKey for the Scaffold
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? nearestDevice;
  String? errorMessage;
  bool isLoading = true;
  String locationName = "Fetching location...";
  List devices = [];
  Map<String, dynamic>? selectedDevice;
  Timer? _pollingTimer;

  // Calculate responsive values based on screen width
  int getCrossAxisCount(double screenWidth) {
    if (screenWidth < 600) {
      return 1; // Mobile: 1 card per row
    } else if (screenWidth < 1300) {
      return 2; // Tablet: 2 cards per row
    } else {
      return 3; // Desktop: 3 cards per row
    }
  }

  double getCardAspectRatio(double screenWidth) {
    if (screenWidth < 600) {
      return 0.6; // Mobile: slightly taller cards
    } else if (screenWidth < 1300) {
      return 0.8; // Tablet: balanced aspect ratio
    } else {
      return 1.3; // Desktop: original aspect ratio
    }
  }

  double getHorizontalPadding(double screenWidth) {
    if (screenWidth < 600) {
      return 10; // Mobile: minimal padding
    } else if (screenWidth < 1300) {
      return 40; // Tablet: moderate padding
    } else {
      return 70; // Desktop: no extra padding (uses main container padding)
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchDeviceData();
    fetchDevicesAndNearest();
    _pollingTimer = Timer.periodic(const Duration(seconds: 59), (timer) {
      fetchDevicesAndNearest(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchDeviceData() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://xa9ry8sls0.execute-api.us-east-1.amazonaws.com/CloudSense_device_activity_api_function',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final wsDevices = data['WS_Device_Activity'] ?? [];
        final awadhDevices = data['Awadh_Jio_Device_Activity'] ?? [];
        final weatherDevices = data['weather_Device_Activity'] ?? [];
        final totalCount =
            wsDevices.length + awadhDevices.length + weatherDevices.length;

        if (mounted) {
          setState(() {
            _totalDevices = totalCount;
          });
        }
      } else {
        print('Failed to load device data. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching device data: $e');
    }
  }

  Future<void> _handleLogout() async {
    try {
      await Amplify.Auth.signOut();
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await unsubscribeFromGpsSnsTopic(fcmToken);
        await unsubscribeFromSnsTopic(fcmToken);
      }
      userProvider.setUser(null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logged out successfully')),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      print('Error during logout: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging out')),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  Future<void> _handleDeviceNavigation() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final email = userProvider.userEmail;
    if (email == null) {
      _showLoginPopup(context);
      return;
    }
    try {
      print('Navigating for user: $email'); // Debug log
      if ([
        'sejalsankhyan2001@gmail.com',
        'pallavikrishnan01@gmail.com',
        'officeharsh25@gmail.com'
      ].contains(email.trim().toLowerCase())) {
        print('Navigating to /admin for super admin');
        Navigator.pushNamed(context, '/admin');
      } else if (email.trim().toLowerCase() == '05agriculture.05@gmail.com') {
        print('Navigating to /graph for agriculture user');
        Navigator.pushNamed(context, '/graph');
      } else {
        print('Navigating to /devicelist for other users');
        await manageNotificationSubscription();
        Navigator.pushNamed(context, '/devicelist');
      }
    } catch (e) {
      print('Error checking user: $e');
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  void _showLoginPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Login Required'),
          content: Text('Please log in or sign up to access your devices.'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await Navigator.pushNamed(context, '/login');
              },
              child: Text('Login/Signup'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showSensorPopup(BuildContext context, {GlobalKey? buttonKey}) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    RelativeRect position;

    if (buttonKey != null) {
      final RenderBox button =
          buttonKey.currentContext!.findRenderObject() as RenderBox;
      final buttonPosition =
          button.localToGlobal(Offset.zero, ancestor: overlay);

      position = RelativeRect.fromLTRB(
        buttonPosition.dx,
        buttonPosition.dy + button.size.height,
        buttonPosition.dx + 200,
        0,
      );
    } else {
      position = RelativeRect.fromLTRB(
        overlay.size.width - 200,
        kToolbarHeight,
        0,
        0,
      );
    }

    bool isAtrhExpanded = false;

    final selected = await showMenu<String>(
      context: context,
      position: position,
      color: isDarkMode ? Colors.grey[800] : Colors.white,
      items: [
        PopupMenuItem<String>(
          value: 'atrh_sensor',
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        isAtrhExpanded = !isAtrhExpanded;
                      });
                    },
                    child: Row(
                      children: [
                        Icon(Icons.thermostat,
                            color: isDarkMode ? Colors.white : Colors.black),
                        SizedBox(width: 8),
                        Text('ATRH Sensor'),
                        SizedBox(width: 8),
                        Icon(
                          isAtrhExpanded
                              ? Icons.arrow_drop_up
                              : Icons.arrow_drop_down,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ],
                    ),
                  ),
                  if (isAtrhExpanded) ...[
                    Padding(
                      padding: EdgeInsets.only(left: 16.0),
                      child: InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, '/probe');
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              Icon(Icons.thermostat,
                                  color:
                                      isDarkMode ? Colors.white : Colors.black),
                              SizedBox(width: 8),
                              Text('Temperature and Humidity\nProbe'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(left: 16.0),
                      child: InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, '/atrh');
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              Icon(Icons.thermostat,
                                  color:
                                      isDarkMode ? Colors.white : Colors.black),
                              SizedBox(width: 8),
                              Text(
                                  'Temperature Humidity\nLight Intensity and\nPressure Sensor'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        PopupMenuItem(
          value: 'wind_speed',
          child: Row(
            children: [
              Icon(Icons.air, color: isDarkMode ? Colors.white : Colors.black),
              SizedBox(width: 8),
              Text('Ultrasonic Anemometer'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'rain_gauge',
          child: Row(
            children: [
              Icon(Icons.water_drop,
                  color: isDarkMode ? Colors.white : Colors.black),
              SizedBox(width: 8),
              Text('Rain Gauge'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'data_logger',
          child: Row(
            children: [
              Icon(Icons.storage,
                  color: isDarkMode ? Colors.white : Colors.black),
              SizedBox(width: 8),
              Text('Data Logger'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'gateway',
          child: Row(
            children: [
              Icon(Icons.router,
                  color: isDarkMode ? Colors.white : Colors.black),
              SizedBox(width: 8),
              Text('BLE Gateway'),
            ],
          ),
        ),
      ],
    );

    if (selected != null && selected != 'atrh_sensor') {
      switch (selected) {
        case 'wind_speed':
          Navigator.pushNamed(context, '/windsensor');
          break;
        case 'rain_gauge':
          Navigator.pushNamed(context, '/raingauge');
          break;
        case 'data_logger':
          Navigator.pushNamed(context, '/datalogger');
          break;
        case 'gateway':
          Navigator.pushNamed(context, '/gateway');
          break;
      }
    }
  }

  Widget _buildUserIcon() {
    final isDotDarkMode = Theme.of(context).brightness == Brightness.dark;
    final userProvider = Provider.of<UserProvider>(context);
    final userEmail = userProvider.userEmail;

    if (userEmail == null || userEmail.isEmpty) {
      return Icon(
        Icons.person,
        color: isDotDarkMode ? Colors.white : Colors.black,
      );
    }
    return CircleAvatar(
      radius: 14,
      backgroundColor: isDotDarkMode ? Colors.white : Colors.black,
      child: Text(
        userEmail[0].toUpperCase(),
        style: TextStyle(
          color: isDotDarkMode ? Colors.black : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Future<void> fetchDevicesAndNearest({bool silent = false}) async {
    try {
      const url =
          "https://xa9ry8sls0.execute-api.us-east-1.amazonaws.com/CloudSense_device_activity_api_function";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        devices = data["Current_Values"] ?? [];

        if (devices.isEmpty) {
          if (mounted) {
            setState(() {
              // errorMessage = "No devices found.";
              isLoading = false;
            });
          }
          return;
        }

        final demoDevice = devices.cast<Map<String, dynamic>>().firstWhere(
              (d) => d["DeviceId"].toString() == "11",
              orElse: () => devices.first,
            );

        if (mounted) {
          setState(() {
            if (selectedDevice == null) {
              selectedDevice = demoDevice;
            } else {
              final updated = devices.firstWhere(
                (d) =>
                    d["DeviceId"].toString() ==
                    selectedDevice?["DeviceId"].toString(),
                orElse: () => demoDevice,
              );
              selectedDevice = Map<String, dynamic>.from(updated);
            }

            if (!silent) {
              isLoading = false;
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            // errorMessage = "API error: ${response.statusCode}";
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // errorMessage = "Error: $e";
          isLoading = false;
        });
      }
    }
  }

  Future<bool> _getUserLocationAndFindNearest() async {
    try {
      double userLat = 0, userLon = 0;

      if (kIsWeb) {
        final completer = Completer<Position>();
        try {
          html.window.navigator.geolocation?.getCurrentPosition().then((pos) {
            final coords = pos.coords;
            completer.complete(Position(
              latitude: coords?.latitude?.toDouble() ?? 0,
              longitude: coords?.longitude?.toDouble() ?? 0,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              heading: 0,
              speed: 0,
              speedAccuracy: 0,
              altitudeAccuracy: 0,
              headingAccuracy: 0,
            ));
          }).catchError((e) {
            completer.completeError("Location blocked");
          });
          final position = await completer.future;
          userLat = position.latitude;
          userLon = position.longitude;
        } catch (_) {
          return false;
        }
      } else {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied ||
              permission == LocationPermission.deniedForever) {
            return false;
          }
        }
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        userLat = position.latitude;
        userLon = position.longitude;
      }

      Map<String, dynamic>? nearest;
      double minDist = double.infinity;

      for (var device in devices) {
        double lat = double.tryParse(device["Latitude"]?.toString() ?? "") ?? 0;
        double lon =
            double.tryParse(device["Longitude"]?.toString() ?? "") ?? 0;
        if (lat == 0 && lon == 0) continue;

        double distance = _calculateDistance(userLat, userLon, lat, lon);
        if (distance < minDist) {
          minDist = distance;
          nearest = Map<String, dynamic>.from(device);
        }
      }

      if (mounted && nearest != null) {
        setState(() {
          nearestDevice = nearest;
          selectedDevice = nearestDevice;
          // errorMessage = null;
        });
      }
      return true;
    } catch (e) {
      debugPrint("Error in location/nearest: $e");
      return false;
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    double dLat = (lat2 - lat1) * pi / 180;
    double dLon = (lon2 - lon1) * pi / 180;

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static String _formatValue(dynamic val) {
    if (val == null) return "--";
    final str = val.toString().trim();
    if (str.isEmpty || str.toLowerCase() == "null") return "--";

    final num? number = num.tryParse(str);
    if (number != null) {
      double rounded = double.parse(number.toStringAsFixed(4));

      return rounded.toString();
    }
    return str;
  }

  bool _isNullOrEmpty(dynamic val) {
    if (val == null) return true;
    final str = val.toString().trim();
    if (str.isEmpty || str.toLowerCase() == "null") return true;
    return false;
  }

  IconData _getIconForKey(String key) {
    key = key.toLowerCase();

    if (key.contains("humidity")) return Icons.water_drop;
    if (key.contains("pressure")) return Icons.speed;
    if (key.contains("light")) return Icons.light_mode;
    if (key.contains("battery")) return Icons.battery_full;
    if (key.contains("temperature")) return Icons.thermostat;
    if (key.contains("device")) return Icons.memory;
    if (key.contains("voltage")) return Icons.bolt;
    if (key.contains("soil")) return Icons.grass;
    if (key.contains("rain")) return Icons.cloudy_snowing;
    if (key.contains("wind")) return Icons.wind_power;

    return Icons.circle;
  }

  Widget _windDial(dynamic direction, dynamic speed) {
    double angle = double.tryParse(direction?.toString() ?? "") ?? 0.0;
    double velocity = double.tryParse(speed?.toString() ?? "") ?? 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white70, width: 2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(top: 6, child: Text("N", style: _dirStyle())),
                  Positioned(bottom: 6, child: Text("S", style: _dirStyle())),
                  Positioned(left: 6, child: Text("W", style: _dirStyle())),
                  Positioned(right: 6, child: Text("E", style: _dirStyle())),
                ],
              ),
            ),
            Transform.rotate(
              angle: angle * pi / 180,
              child: const Icon(Icons.navigation,
                  size: 50, color: Colors.redAccent),
            ),
          ],
        ),
      ],
    );
  }

  TextStyle _dirStyle() =>
      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold);

  String _getNameForKey(String paramName) {
    if (paramName.startsWith("Current")) {
      paramName = paramName.replaceFirst("Current", "");
    }
    String result = paramName.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );

    return result[0].toUpperCase() + result.substring(1);
  }

  String _getUnitForKey(String paramName) {
    if (paramName.contains('Rainfall')) return 'mm';
    if (paramName.contains('Voltage')) return 'V';
    if (paramName.contains('SignalStrength')) return 'dBm';
    if (paramName.contains('Latitude') || paramName.contains('Longitude'))
      return '°';
    if (paramName.contains('Temperature')) return '°C';
    if (paramName.contains('Humidity')) return '%';
    if (paramName.contains('Pressure')) return 'hPa';
    if (paramName.contains('LightIntensity')) return 'Lux';
    if (paramName.contains('WindSpeed')) return 'm/s';
    if (paramName.contains('WindDirection')) return '°';
    if (paramName.contains('Potassium')) return 'mg/Kg';
    if (paramName.contains('Nitrogen')) return 'mg/Kg';
    if (paramName.contains('Salinity')) return 'mg/L';
    if (paramName.contains('ElectricalConductivity')) return 'µS/cm';
    if (paramName.contains('Phosphorus')) return 'mg/Kg';
    if (paramName.contains('pH')) return 'pH';
    if (paramName.contains('Irradiance') || paramName.contains('Radiation'))
      return 'W/m²';
    if (paramName.contains('Chlorine') ||
        paramName.contains('COD') ||
        paramName.contains('BOD') ||
        paramName.contains('DO')) return 'mg/L';
    if (paramName.contains('TDS')) return 'ppm';
    if (paramName.contains('EC')) return 'mS/cm';
    if (paramName.contains('Ammonia')) return 'PPM';
    if (paramName.contains('Visibility')) return 'm';
    if (paramName.contains('ElectrodeSignal')) return 'mV';

    return '';
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final currentDate = DateFormat("EEEE, dd MMMM yyyy").format(DateTime.now());
    final currentTime = DateFormat("hh:mm a").format(DateTime.now());

    // GlobalKeys for positioning dropdowns
    final GlobalKey productsButtonKey = GlobalKey();
    final GlobalKey userButtonKey = GlobalKey();

    double titleFont = screenWidth < 800
        ? 28
        : screenWidth < 1024
            ? 48
            : 60;
    double subtitleFont = screenWidth < 800
        ? 18
        : screenWidth < 1024
            ? 22
            : 30;
    double paragraphFont = screenWidth < 800
        ? 14
        : screenWidth < 1024
            ? 18
            : 18;

    return LayoutBuilder(builder: (context, constraints) {
      bool isMobile = constraints.maxWidth < 800;
      bool isTablet =
          constraints.maxWidth >= 800 && constraints.maxWidth <= 1024;

      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0, // remove shadow
          scrolledUnderElevation:
              0, // NEW: disables the lighter overlay effect when scrolled
          surfaceTintColor: Colors.transparent, // prevents automatic tint
          iconTheme: IconThemeData(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          backgroundColor: isDarkMode ? Colors.blueGrey[900] : Colors.white,
          toolbarHeight: 70,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: EdgeInsets.only(left: screenWidth < 800 ? 8 : 26),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud,
                      color: isDarkMode ? Colors.white : Colors.black,
                      size: screenWidth < 800
                          ? 24
                          : screenWidth <= 1024
                              ? 32
                              : 46,
                    ),
                    SizedBox(width: isMobile ? 10 : (isTablet ? 15 : 20)),
                    Text(
                      'Cloud Sense Vis',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: screenWidth < 800
                            ? 20
                            : screenWidth <= 1024
                                ? 26
                                : 46,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile)
                Padding(
                  padding: EdgeInsets.only(right: screenWidth < 800 ? 8 : 26),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        key: productsButtonKey,
                        onPressed: () => _showSensorPopup(context,
                            buttonKey: productsButtonKey),
                        child: Row(
                          children: [
                            SizedBox(width: 4),
                            Text(
                              'Products',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: isTablet ? 14 : 16,
                              ),
                            ),
                            Icon(Icons.arrow_drop_down,
                                color: isDarkMode ? Colors.white : Colors.black,
                                size: isTablet ? 18 : 20),
                          ],
                        ),
                      ),
                      SizedBox(width: screenWidth <= 1024 ? 12 : 24),
                      userProvider.userEmail != null
                          ? Row(
                              key: userButtonKey,
                              children: [
                                _buildUserIcon(),
                                SizedBox(width: 8),
                                _buildUserDropdown(
                                    isDarkMode, isTablet, userButtonKey),
                              ],
                            )
                          : TextButton(
                              key: userButtonKey,
                              onPressed: () => _showLoginPopup(context),
                              child: Row(
                                children: [
                                  Text(
                                    'Login/Signup',
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isTablet ? 14 : 16,
                                    ),
                                  ),
                                  Icon(Icons.arrow_drop_down,
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                      size: isTablet ? 18 : 20),
                                ],
                              ),
                            ),
                      SizedBox(width: screenWidth <= 1024 ? 12 : 24),
                      TextButton(
                        onPressed: () {
                          themeProvider.toggleTheme();
                        },
                        child: Row(
                          children: [
                            Icon(
                              themeProvider.isDarkMode
                                  ? Icons.light_mode
                                  : Icons.dark_mode,
                              color: isDarkMode ? Colors.white : Colors.black,
                              size: isTablet ? 18 : 20,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Theme',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: isTablet ? 14 : 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: isMobile
              ? [
                  Builder(
                    builder: (context) => IconButton(
                      icon: Icon(
                        Icons.menu,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      onPressed: () {
                        Scaffold.of(context).openEndDrawer();
                      },
                    ),
                  ),
                ]
              : [],
        ),
        endDrawer: isMobile
            ? Drawer(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    DrawerHeader(
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.blueGrey[900]
                            : Colors.grey[200],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 8),
                          Row(
                            children: [
                              _buildUserIcon(),
                              SizedBox(width: 8),
                              Text(
                                userProvider.userEmail ?? 'Guest User',
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            userProvider.userEmail != null
                                ? 'Welcome back!'
                                : 'Please login to access all features',
                            style: TextStyle(
                              color:
                                  isDarkMode ? Colors.white70 : Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (userProvider.userEmail != null) ...[
                      if ([
                        'sejalsankhyan2001@gmail.com',
                        'pallavikrishnan01@gmail.com',
                        'officeharsh25@gmail.com'
                      ].contains(
                          userProvider.userEmail?.trim().toLowerCase())) ...[
                        ListTile(
                          leading: Icon(Icons.data_usage),
                          title: Text('My Data'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/admin');
                          },
                        ),
                        ListTile(
                          leading: Icon(themeProvider.isDarkMode
                              ? Icons.light_mode
                              : Icons.dark_mode),
                          title: const Text('Theme'),
                          onTap: () {
                            themeProvider.toggleTheme();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.share),
                          title: const Text('Share'),
                          onTap: () {
                            Share.share(
                              'Check out our app on Google Play Store: https://play.google.com/store/apps/details?id=com.CloudSenseVis',
                              subject: 'Download Our App',
                            );
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.logout),
                          title: Text('Logout'),
                          onTap: () {
                            Navigator.pop(context);
                            _handleLogout();
                          },
                        ),
                      ] else ...[
                        ListTile(
                          leading: Icon(Icons.devices),
                          title: Text('My Devices'),
                          onTap: () {
                            Navigator.pop(context);
                            if ([
                              'sejalsankhyan2001@gmail.com',
                              'pallavikrishnan01@gmail.com',
                              'officeharsh25@gmail.com'
                            ].contains(
                                userProvider.userEmail?.trim().toLowerCase())) {
                              Navigator.pushNamed(context, '/admin');
                            } else if (userProvider.userEmail
                                    ?.trim()
                                    .toLowerCase() ==
                                '05agriculture.05@gmail.com') {
                              Navigator.pushNamed(context, '/deviceinfo');
                            } else {
                              Navigator.pushNamed(context, '/devicelist');
                            }
                          },
                        ),
                        if (userProvider.userEmail?.trim().toLowerCase() !=
                            '05agriculture.05@gmail.com')
                          ListTile(
                            leading: Icon(Icons.account_circle),
                            title: Text('Account Info'),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/accountinfo');
                            },
                          ),
                        ListTile(
                          leading: Icon(themeProvider.isDarkMode
                              ? Icons.light_mode
                              : Icons.dark_mode),
                          title: const Text('Theme'),
                          onTap: () {
                            themeProvider.toggleTheme();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.share),
                          title: const Text('Share'),
                          onTap: () {
                            Share.share(
                              'Check out our app on Google Play Store: https://play.google.com/store/apps/details?id=com.CloudSenseVis',
                              subject: 'Download Our App',
                            );
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.logout),
                          title: Text('Logout'),
                          onTap: () {
                            Navigator.pop(context);
                            _handleLogout();
                          },
                        ),
                      ],
                      Divider(),
                    ],
                    ListTile(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory,
                              color: isDarkMode ? Colors.white : Colors.black),
                          SizedBox(width: 8),
                          Icon(
                              _isProductsExpanded
                                  ? Icons.arrow_drop_up
                                  : Icons.arrow_drop_down,
                              color: isDarkMode ? Colors.white : Colors.black),
                        ],
                      ),
                      title: Text('Products'),
                      onTap: () {
                        setState(() {
                          _isProductsExpanded = !_isProductsExpanded;
                        });
                      },
                    ),
                    if (_isProductsExpanded)
                      Padding(
                        padding: EdgeInsets.only(left: 16),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.thermostat, size: 20),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_drop_down, size: 20),
                                ],
                              ),
                              title: Text('ATRH Sensor',
                                  style: TextStyle(fontSize: 14)),
                              onTap: () {
                                setState(() {
                                  _isProductsExpanded = true;
                                });
                              },
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 16),
                              child: Column(
                                children: [
                                  ListTile(
                                    leading: Icon(Icons.thermostat, size: 18),
                                    title: Text(
                                        'Temperature and Humidity\nProbe',
                                        style: TextStyle(fontSize: 12)),
                                    onTap: () {
                                      Navigator.pop(context);
                                      Navigator.pushNamed(context, '/probe');
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.thermostat, size: 18),
                                    title: Text(
                                        'Temperature Humidity\nLight Intensity and\nPressure Sensor',
                                        style: TextStyle(fontSize: 12)),
                                    onTap: () {
                                      Navigator.pop(context);
                                      Navigator.pushNamed(context, '/atrh');
                                    },
                                  ),
                                ],
                              ),
                            ),
                            ListTile(
                              leading: Icon(Icons.air, size: 20),
                              title: Text('Ultrasonic Anemometer',
                                  style: TextStyle(fontSize: 14)),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, '/windsensor');
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.water_drop, size: 20),
                              title: Text('Rain Gauge',
                                  style: TextStyle(fontSize: 14)),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, '/raingauge');
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.storage, size: 20),
                              title: Text('Data Logger',
                                  style: TextStyle(fontSize: 14)),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, '/datalogger');
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.router, size: 20),
                              title: Text('BLE Gateway',
                                  style: TextStyle(fontSize: 14)),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, '/gateway');
                              },
                            ),
                          ],
                        ),
                      ),
                    if (userProvider.userEmail == null) ...[
                      Divider(),
                      ListTile(
                        leading: Icon(Icons.login),
                        title: Text('Login/Signup'),
                        onTap: () {
                          Navigator.pop(context);
                          _showLoginPopup(context);
                        },
                      ),
                      ListTile(
                        leading: Icon(themeProvider.isDarkMode
                            ? Icons.light_mode
                            : Icons.dark_mode),
                        title: const Text('Theme'),
                        onTap: () {
                          themeProvider.toggleTheme();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.share),
                        title: const Text('Share'),
                        onTap: () {
                          Share.share(
                            'Check out our app on Google Play Store:https://play.google.com/store/apps/details?id=com.CloudSenseVis',
                            subject: 'Download Our App',
                          );
                        },
                      ),
                    ],
                  ],
                ),
              )
            : null,
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: themeProvider.isDarkMode
                      ? [
                          const Color.fromARGB(255, 57, 57, 57)!,
                          const Color.fromARGB(255, 2, 54, 76)!,
                        ]
                      : [
                          const Color.fromARGB(255, 147, 214, 207)!,
                          const Color.fromARGB(255, 79, 106, 112)!,
                        ],
                ),
              ),
            ),
            SingleChildScrollView(
              child: Column(
                children: [
                  // Main content with padding
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth < 800
                          ? 15
                          : screenWidth <= 1024
                              ? 15
                              : 15,
                      vertical: 15,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SafeArea(
                          child: Center(
                            child: isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : selectedDevice == null
                                    ? const Text("No device found.",
                                        style: TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 18))
                                    : LayoutBuilder(
                                        builder: (context, constraints) {
                                          double screenWidth =
                                              constraints.maxWidth;
                                          int columns = screenWidth >= 1024
                                              ? 5
                                              : screenWidth >= 850
                                                  ? 4
                                                  : screenWidth >= 500
                                                      ? 3
                                                      : 2;
                                          bool isLargeScreen =
                                              screenWidth >= 800;
                                          bool isSmallScreen =
                                              screenWidth < 600;

                                          Widget deviceButton = TextButton(
                                            style: (selectedDevice?["DeviceId"]
                                                        .toString() ==
                                                    "11")
                                                ? TextButton.styleFrom(
                                                    backgroundColor: !isDarkMode
                                                        ? Colors.white
                                                        : const Color.fromARGB(
                                                            255, 10, 75, 100),
                                                    padding: isSmallScreen
                                                        ? const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 12,
                                                            vertical: 12)
                                                        : const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 16,
                                                            vertical: 16),
                                                    minimumSize: Size.zero,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        6)),
                                                  )
                                                : TextButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.transparent,
                                                    shadowColor:
                                                        Colors.transparent,
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    minimumSize: Size.zero,
                                                    shape: const CircleBorder(),
                                                  ),
                                            onPressed: () async {
                                              if (selectedDevice?["DeviceId"]
                                                      .toString() ==
                                                  "11") {
                                                // Check nearest
                                                bool gotLocation =
                                                    await _getUserLocationAndFindNearest();
                                                if (!gotLocation && mounted) {
                                                  setState(() {
                                                    errorMessage =
                                                        "Please enable location access to find nearest device.";
                                                  });
                                                  // Auto clear after 3 seconds
                                                  Future.delayed(
                                                      const Duration(
                                                          seconds: 3), () {
                                                    if (mounted) {
                                                      setState(() {
                                                        errorMessage = null;
                                                      });
                                                    }
                                                  });
                                                }
                                              } else {
                                                // Back to Device 11
                                                setState(() {
                                                  selectedDevice = devices
                                                      .cast<
                                                          Map<String,
                                                              dynamic>>()
                                                      .firstWhere(
                                                          (d) =>
                                                              d["DeviceId"]
                                                                  .toString() ==
                                                              "11",
                                                          orElse: () =>
                                                              devices.first);
                                                  errorMessage = null;
                                                });
                                              }
                                            },
                                            child: selectedDevice?["DeviceId"]
                                                        .toString() ==
                                                    "11"
                                                ? const Text(
                                                    "Check Nearest Device",
                                                    style: TextStyle(
                                                        color: Colors.black,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 10))
                                                : const Icon(Icons.arrow_back,
                                                    size: 20,
                                                    color: Colors.white),
                                          );

                                          return Padding(
                                            padding: const EdgeInsets.all(10),
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                  maxWidth: 1400),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  gradient: LinearGradient(
                                                    colors: isDarkMode
                                                        ? [
                                                            Colors.blueGrey
                                                                .shade800,
                                                            Colors.black54
                                                          ]
                                                        : [
                                                            const Color
                                                                    .fromARGB(
                                                                    255,
                                                                    255,
                                                                    255,
                                                                    255)
                                                                .withOpacity(
                                                                    0.3),
                                                            const Color
                                                                    .fromARGB(
                                                                    255,
                                                                    94,
                                                                    211,
                                                                    162)
                                                                .withOpacity(
                                                                    0.3)
                                                          ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.3),
                                                        blurRadius: 8,
                                                        offset:
                                                            const Offset(0, 4))
                                                  ],
                                                ),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(25),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .stretch,
                                                    children: [
                                                      if (isSmallScreen)
                                                        Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .end,
                                                            children: [
                                                              deviceButton
                                                            ]),
                                                      const SizedBox(height: 8),
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                "Latitude: ${_formatValue(selectedDevice?["Latitude"])} , Longitude: ${_formatValue(selectedDevice?["Longitude"])}",
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        screenWidth < 600
                                                                            ? 12
                                                                            : 16,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: Colors
                                                                        .white),
                                                              ),
                                                              const SizedBox(
                                                                  height: 2),
                                                              Text(currentDate,
                                                                  style: TextStyle(
                                                                      fontSize: screenWidth <
                                                                              600
                                                                          ? 10
                                                                          : 12,
                                                                      color: Colors
                                                                          .white70)),
                                                            ],
                                                          ),
                                                          if (!isSmallScreen)
                                                            deviceButton,
                                                        ],
                                                      ),
                                                      const SizedBox(
                                                          height: 12),
                                                      if (isLargeScreen)
                                                        Row(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .center,
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Expanded(
                                                              child: GridView
                                                                  .count(
                                                                crossAxisCount:
                                                                    columns,
                                                                crossAxisSpacing:
                                                                    10,
                                                                mainAxisSpacing:
                                                                    10,
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(4),
                                                                shrinkWrap:
                                                                    true,
                                                                physics:
                                                                    const NeverScrollableScrollPhysics(),
                                                                childAspectRatio:
                                                                    2,
                                                                children: [
                                                                  if (!_isNullOrEmpty(
                                                                      selectedDevice?[
                                                                          "CurrentTemperature"]))
                                                                    Container(
                                                                      padding:
                                                                          const EdgeInsets
                                                                              .all(
                                                                              4),
                                                                      decoration: BoxDecoration(
                                                                          color: Colors.redAccent.withOpacity(
                                                                              0.3),
                                                                          borderRadius:
                                                                              BorderRadius.circular(8)),
                                                                      child:
                                                                          Column(
                                                                        mainAxisAlignment:
                                                                            MainAxisAlignment.center,
                                                                        children: [
                                                                          Row(
                                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                                              children: [
                                                                                const Icon(Icons.thermostat, color: Colors.white, size: 18),
                                                                                const SizedBox(width: 4),
                                                                                Text("Temperature", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                                                              ]),
                                                                          const SizedBox(
                                                                              height: 4),
                                                                          Text(
                                                                              "${_formatValue(selectedDevice?["CurrentTemperature"])}°C",
                                                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ...(selectedDevice ??
                                                                          {})
                                                                      .entries
                                                                      .where((e) =>
                                                                          !_isNullOrEmpty(e.value) &&
                                                                          !{
                                                                            "Latitude",
                                                                            "Longitude",
                                                                            "WindDirection",
                                                                            "TimeStamp",
                                                                            "CurrentTemperature",
                                                                            "DeviceId",
                                                                            "IMEINumber",
                                                                            "LastUpdated",
                                                                            "Topic",
                                                                            "SignalStrength",
                                                                            "BatteryVoltage",
                                                                            "RainfallHourly"
                                                                          }.contains(e.key))
                                                                      .map(
                                                                        (e) =>
                                                                            Container(
                                                                          padding: const EdgeInsets
                                                                              .all(
                                                                              2),
                                                                          decoration: BoxDecoration(
                                                                              color: Colors.white.withOpacity(0.1),
                                                                              borderRadius: BorderRadius.circular(8)),
                                                                          child:
                                                                              Column(
                                                                            mainAxisAlignment:
                                                                                MainAxisAlignment.center,
                                                                            children: [
                                                                              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                                                                Icon(_getIconForKey(e.key), color: Colors.white, size: 18),
                                                                                const SizedBox(width: 4),
                                                                                Text("${_getNameForKey(e.key)}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                                                              ]),
                                                                              const SizedBox(height: 4),
                                                                              Text("${_formatValue(e.value)} ${_getUnitForKey(e.key)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                      )
                                                                      .toList(),
                                                                ],
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                width: 25),
                                                            if (!_isNullOrEmpty(
                                                                    selectedDevice?[
                                                                        "WindDirection"]) &&
                                                                !_isNullOrEmpty(
                                                                    selectedDevice?[
                                                                        "WindSpeed"]))
                                                              _windDial(
                                                                  selectedDevice?[
                                                                      "WindDirection"],
                                                                  selectedDevice?[
                                                                      "WindSpeed"]),
                                                          ],
                                                        )
                                                      else
                                                        GridView.count(
                                                          crossAxisCount:
                                                              columns,
                                                          crossAxisSpacing: 8,
                                                          mainAxisSpacing: 8,
                                                          shrinkWrap: true,
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(4),
                                                          physics:
                                                              const NeverScrollableScrollPhysics(),
                                                          childAspectRatio: 2,
                                                          children: [
                                                            if (!_isNullOrEmpty(
                                                                selectedDevice?[
                                                                    "CurrentTemperature"]))
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(4),
                                                                decoration: BoxDecoration(
                                                                    color: Colors
                                                                        .redAccent
                                                                        .withOpacity(
                                                                            0.3),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            8)),
                                                                child: Column(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    Row(
                                                                        mainAxisAlignment:
                                                                            MainAxisAlignment.center,
                                                                        children: [
                                                                          const Icon(
                                                                              Icons.thermostat,
                                                                              color: Colors.white,
                                                                              size: 14),
                                                                          const SizedBox(
                                                                              width: 4),
                                                                          Text(
                                                                              "Temperature",
                                                                              style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                                                        ]),
                                                                    const SizedBox(
                                                                        height:
                                                                            4),
                                                                    Text(
                                                                        "${_formatValue(selectedDevice?["CurrentTemperature"])}°C",
                                                                        style: const TextStyle(
                                                                            color:
                                                                                Colors.white,
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: 13)),
                                                                  ],
                                                                ),
                                                              ),
                                                            ...(selectedDevice ??
                                                                    {})
                                                                .entries
                                                                .where((e) =>
                                                                    !_isNullOrEmpty(e
                                                                        .value) &&
                                                                    !{
                                                                      "Latitude",
                                                                      "Longitude",
                                                                      "WindDirection",
                                                                      "TimeStamp",
                                                                      "CurrentTemperature",
                                                                      "DeviceId",
                                                                      "IMEINumber",
                                                                      "LastUpdated",
                                                                      "Topic",
                                                                      "SignalStrength",
                                                                      "BatteryVoltage",
                                                                      "RainfallHourly"
                                                                    }.contains(
                                                                        e.key))
                                                                .map(
                                                                  (e) =>
                                                                      Container(
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .all(
                                                                            8),
                                                                    decoration: BoxDecoration(
                                                                        color: Colors
                                                                            .white
                                                                            .withOpacity(
                                                                                0.3),
                                                                        borderRadius:
                                                                            BorderRadius.circular(8)),
                                                                    child:
                                                                        Column(
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .center,
                                                                      children: [
                                                                        Row(
                                                                            mainAxisAlignment:
                                                                                MainAxisAlignment.center,
                                                                            children: [
                                                                              Icon(_getIconForKey(e.key), color: Colors.white, size: 14),
                                                                              const SizedBox(width: 4),
                                                                              Text("${_getNameForKey(e.key)}", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                                                            ]),
                                                                        const SizedBox(
                                                                            height:
                                                                                4),
                                                                        Text(
                                                                            "${_formatValue(e.value)} ${_getUnitForKey(e.key)}",
                                                                            style: const TextStyle(
                                                                                color: Colors.white,
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 13),
                                                                            textAlign: TextAlign.center),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                )
                                                                .toList(),
                                                          ],
                                                        ),
                                                      const SizedBox(
                                                          height: 12),
                                                      if (!_isNullOrEmpty(
                                                              selectedDevice?[
                                                                  "WindDirection"]) &&
                                                          !_isNullOrEmpty(
                                                              selectedDevice?[
                                                                  "WindSpeed"]) &&
                                                          !isLargeScreen)
                                                        Center(
                                                            child: _windDial(
                                                                selectedDevice?[
                                                                    "WindDirection"],
                                                                selectedDevice?[
                                                                    "WindSpeed"])),
                                                      const SizedBox(height: 5),
                                                      Text(
                                                          "Last Updated: ${_formatValue(selectedDevice?["TimeStamp"])}",
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: const TextStyle(
                                                              fontSize: 11,
                                                              fontStyle:
                                                                  FontStyle
                                                                      .italic,
                                                              color: Color
                                                                  .fromARGB(
                                                                      255,
                                                                      245,
                                                                      240,
                                                                      240))),
                                                      if (errorMessage !=
                                                          null) ...[
                                                        const SizedBox(
                                                            height: 6),
                                                        Text(errorMessage!,
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: const TextStyle(
                                                                color: Colors
                                                                    .redAccent,
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold)),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        screenWidth < 800
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 40,
                                    runSpacing: 20,
                                    children: [
                                      _buildAnimatedStatCard(
                                        statValue: _totalDevices.toString(),
                                        label: "Devices",
                                        themeProvider: themeProvider,
                                        context: context,
                                      ),
                                      _buildAnimatedStatCard(
                                        statValue: "500K",
                                        label: "Data Points",
                                        themeProvider: themeProvider,
                                        context: context,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 60),
                                  MouseRegion(
                                    onEnter: (_) => setState(
                                        () => _isHoveredMyDevicesButton = true),
                                    onExit: (_) => setState(() =>
                                        _isHoveredMyDevicesButton = false),
                                    child: GestureDetector(
                                      onTapDown: (_) => setState(() =>
                                          _isPressedMyDevicesButton = true),
                                      onTapUp: (_) => setState(() =>
                                          _isPressedMyDevicesButton = false),
                                      onTapCancel: () => setState(() =>
                                          _isPressedMyDevicesButton = false),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        transform: Matrix4.identity()
                                          ..scale(_isPressedMyDevicesButton
                                              ? 0.95
                                              : (_isHoveredMyDevicesButton
                                                  ? 1.05
                                                  : 0.85)),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _isHoveredMyDevicesButton
                                                  ? Colors.black
                                                      .withOpacity(0.4)
                                                  : Colors.black
                                                      .withOpacity(0.2),
                                              blurRadius:
                                                  _isHoveredMyDevicesButton
                                                      ? 12
                                                      : 6,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: () {
                                            _handleDeviceNavigation();
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                themeProvider.isDarkMode
                                                    ? const Color.fromARGB(
                                                        255, 18, 16, 16)
                                                    : Colors.white,
                                            foregroundColor:
                                                themeProvider.isDarkMode
                                                    ? Colors.white
                                                    : Colors.black,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 32,
                                              vertical: 18,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                "My Devices",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: paragraphFont,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Icon(
                                                Icons.arrow_forward,
                                                size: paragraphFont + 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  MouseRegion(
                                    onEnter: (_) =>
                                        setState(() => _isHoveredbutton = true),
                                    onExit: (_) => setState(
                                        () => _isHoveredbutton = false),
                                    child: GestureDetector(
                                      onTapDown: (_) =>
                                          setState(() => _isPressed = true),
                                      onTapUp: (_) =>
                                          setState(() => _isPressed = false),
                                      onTapCancel: () =>
                                          setState(() => _isPressed = false),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        transform: Matrix4.identity()
                                          ..scale(_isPressed
                                              ? 0.95
                                              : (_isHoveredbutton
                                                  ? 1.05
                                                  : 0.85)),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _isHoveredbutton
                                                  ? Colors.black
                                                      .withOpacity(0.4)
                                                  : Colors.black
                                                      .withOpacity(0.2),
                                              blurRadius:
                                                  _isHoveredbutton ? 12 : 6,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    DeviceActivityPage(),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                themeProvider.isDarkMode
                                                    ? const Color.fromARGB(
                                                        255, 18, 16, 16)
                                                    : Colors.white,
                                            foregroundColor:
                                                themeProvider.isDarkMode
                                                    ? Colors.white
                                                    : Colors.black,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 32,
                                              vertical: 18,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                "Total Devices",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: paragraphFont,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Icon(
                                                Icons.arrow_forward,
                                                size: paragraphFont + 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _buildAnimatedStatCard(
                                    statValue: _totalDevices.toString(),
                                    label: "Devices",
                                    themeProvider: themeProvider,
                                    context: context,
                                  ),
                                  const SizedBox(width: 40),
                                  _buildAnimatedStatCard(
                                    statValue: "500K",
                                    label: "Data Points",
                                    themeProvider: themeProvider,
                                    context: context,
                                  ),
                                  const SizedBox(width: 40),
                                  Column(
                                    children: [
                                      MouseRegion(
                                        onEnter: (_) => setState(() =>
                                            _isHoveredMyDevicesButton = true),
                                        onExit: (_) => setState(() =>
                                            _isHoveredMyDevicesButton = false),
                                        child: GestureDetector(
                                          onTapDown: (_) => setState(() =>
                                              _isPressedMyDevicesButton = true),
                                          onTapUp: (_) => setState(() =>
                                              _isPressedMyDevicesButton =
                                                  false),
                                          onTapCancel: () => setState(() =>
                                              _isPressedMyDevicesButton =
                                                  false),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 200),
                                            transform: Matrix4.identity()
                                              ..scale(_isPressedMyDevicesButton
                                                  ? 0.95
                                                  : (_isHoveredMyDevicesButton
                                                      ? 1.05
                                                      : 1.0)),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color:
                                                      _isHoveredMyDevicesButton
                                                          ? Colors.black
                                                              .withOpacity(0.4)
                                                          : Colors.black
                                                              .withOpacity(0.2),
                                                  blurRadius:
                                                      _isHoveredMyDevicesButton
                                                          ? 12
                                                          : 6,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: ElevatedButton(
                                              onPressed: () {
                                                _handleDeviceNavigation();
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    themeProvider.isDarkMode
                                                        ? const Color.fromARGB(
                                                            255, 18, 16, 16)
                                                        : Colors.white,
                                                foregroundColor:
                                                    themeProvider.isDarkMode
                                                        ? Colors.white
                                                        : Colors.black,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 32,
                                                  vertical: 18,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    "My Devices",
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize:
                                                          paragraphFont - 4,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Icon(
                                                    Icons.arrow_forward,
                                                    size: paragraphFont + 2,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      MouseRegion(
                                        onEnter: (_) => setState(
                                            () => _isHoveredbutton = true),
                                        onExit: (_) => setState(
                                            () => _isHoveredbutton = false),
                                        child: GestureDetector(
                                          onTapDown: (_) =>
                                              setState(() => _isPressed = true),
                                          onTapUp: (_) => setState(
                                              () => _isPressed = false),
                                          onTapCancel: () => setState(
                                              () => _isPressed = false),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 200),
                                            transform: Matrix4.identity()
                                              ..scale(_isPressed
                                                  ? 0.95
                                                  : (_isHoveredbutton
                                                      ? 1.05
                                                      : 1.0)),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: _isHoveredbutton
                                                      ? Colors.black
                                                          .withOpacity(0.4)
                                                      : Colors.black
                                                          .withOpacity(0.2),
                                                  blurRadius:
                                                      _isHoveredbutton ? 12 : 6,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: ElevatedButton(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        DeviceActivityPage(),
                                                  ),
                                                );
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    themeProvider.isDarkMode
                                                        ? const Color.fromARGB(
                                                            255, 18, 16, 16)
                                                        : Colors.white,
                                                foregroundColor:
                                                    themeProvider.isDarkMode
                                                        ? Colors.white
                                                        : Colors.black,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 32,
                                                  vertical: 18,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    "Total Devices",
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize:
                                                          paragraphFont - 4,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Icon(
                                                    Icons.arrow_forward,
                                                    size: paragraphFont + 2,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  // Full-width products section (outside of padding)
                  // ✅ Usage
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode
                          ? Colors.blueGrey[900]
                          : const Color.fromARGB(255, 112, 163, 161),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 20),
                      child: Column(
                        children: [
                          Text(
                            "Our Products",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.isDarkMode
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 30),

                          // ✅ Fixed Card Size Grid
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount:
                                  getResponsiveCrossAxisCount(screenWidth),
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 30,
                              mainAxisExtent:
                                  320, // ✅ Fix card ki height (har screen par same)
                            ),
                            itemCount: 6,
                            itemBuilder: (context, index) {
                              final items = [
                                {
                                  "image": "assets/thprobe.png",
                                  "title": "Temperature and Humidity Probe",
                                  "desc":
                                      "Accurate measurements for temperature and humidity.",
                                  "route": "/probe"
                                },
                                {
                                  "image": "assets/luxpressure.png",
                                  "title":
                                      "Temperature Humidity Light Intensity and Pressure Sensor",
                                  "desc":
                                      "Compact environmental sensing unit for precise measurements.",
                                  "route": "/atrh"
                                },
                                {
                                  "image": "assets/ultrasonic.png",
                                  "title": "Ultrasonic Anemometer",
                                  "desc":
                                      "Ultrasonic Anemometer for precise wind speed and wind direction.",
                                  "route": "/windsensor"
                                },
                                {
                                  "image": "assets/gauge.png",
                                  "title": "Rain Gauge",
                                  "desc": "Tipping Bucket rain Gauge.",
                                  "route": "/raingauge"
                                },
                                {
                                  "image": "assets/dataloggerrender.png",
                                  "title": "Data Logger",
                                  "desc":
                                      "Reliable Data Logging & seamless Connectivity.",
                                  "route": "/datalogger"
                                },
                                {
                                  "image": "assets/blegateway.png",
                                  "title": "BLE Gateway",
                                  "desc":
                                      "BLE Gateway For industrial IOT Applications.",
                                  "route": "/gateway"
                                },
                              ];

                              final item = items[index];
                              return _buildSensorCard(
                                imageAsset: item["image"]!,
                                title: item["title"]!,
                                description: item["desc"]!,
                                onReadMore: () => Navigator.pushNamed(
                                    context, item["route"]!),
                                screenWidth: screenWidth,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      );
    });
  }

  Widget _buildNavButton(
    String text,
    Color color,
    VoidCallback onPressed, {
    double fontSize = 14,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Flexible(
      child: MouseRegion(
        onEnter: (_) => setState(() {
          if (text == 'ABOUT US') _aboutUsColor = Colors.blue;
          if (text == 'ACCOUNT INFO') _accountinfoColor = Colors.blue;
          if (text == 'DEVICE STATUS') _devicemapinfoColor = Colors.blue;
        }),
        onExit: (_) => setState(() {
          if (text == 'ABOUT US')
            _aboutUsColor = const Color.fromARGB(255, 235, 232, 232);
          if (text == 'ACCOUNT INFO')
            _accountinfoColor = const Color.fromARGB(255, 235, 232, 232);
          if (text == 'DEVICE STATUS')
            _devicemapinfoColor = const Color.fromARGB(255, 235, 232, 232);
        }),
        child: TextButton(
          onPressed: onPressed,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              style: TextStyle(
                fontSize: fontSize,
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserDropdown(
      bool isDarkMode, bool isTablet, GlobalKey userButtonKey) {
    final userProvider = Provider.of<UserProvider>(context);
    final isAdmin = userProvider.userEmail?.trim().toLowerCase() ==
        '05agriculture.05@gmail.com';
    final isSuperAdmin = [
      'sejalsankhyan2001@gmail.com',
      'pallavikrishnan01@gmail.com',
      'officeharsh25@gmail.com'
    ].contains(userProvider.userEmail?.trim().toLowerCase());

    return GestureDetector(
      onTap: () async {
        final RenderBox overlay =
            Overlay.of(context).context.findRenderObject() as RenderBox;
        final RenderBox button =
            userButtonKey.currentContext!.findRenderObject() as RenderBox;
        final buttonPosition =
            button.localToGlobal(Offset.zero, ancestor: overlay);

        final selected = await showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(
            buttonPosition.dx,
            buttonPosition.dy + button.size.height,
            buttonPosition.dx + 200,
            0,
          ),
          color: isDarkMode ? Colors.grey[800] : Colors.white,
          items: userProvider.userEmail != null
              ? isSuperAdmin
                  ? [
                      PopupMenuItem(
                        value: 'data',
                        child: Row(
                          children: [
                            Icon(Icons.data_usage,
                                color:
                                    isDarkMode ? Colors.white : Colors.black),
                            SizedBox(width: 8),
                            Text('My Data'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout,
                                color:
                                    isDarkMode ? Colors.white : Colors.black),
                            SizedBox(width: 8),
                            Text('Logout'),
                          ],
                        ),
                      ),
                    ]
                  : [
                      PopupMenuItem(
                        value: 'devices',
                        child: Row(
                          children: [
                            Icon(Icons.devices,
                                color:
                                    isDarkMode ? Colors.white : Colors.black),
                            SizedBox(width: 8),
                            Text('My Devices'),
                          ],
                        ),
                      ),
                      if (!isAdmin)
                        PopupMenuItem(
                          value: 'account',
                          child: Row(
                            children: [
                              Icon(Icons.account_circle,
                                  color:
                                      isDarkMode ? Colors.white : Colors.black),
                              SizedBox(width: 8),
                              Text('Account Info'),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout,
                                color:
                                    isDarkMode ? Colors.white : Colors.black),
                            SizedBox(width: 8),
                            Text('Logout'),
                          ],
                        ),
                      ),
                    ]
              : [
                  PopupMenuItem(
                    value: 'login',
                    child: Row(
                      children: [
                        Icon(Icons.login,
                            color: isDarkMode ? Colors.white : Colors.black),
                        SizedBox(width: 8),
                        Text('Login/Signup'),
                      ],
                    ),
                  ),
                ],
        );

        if (selected == 'data' && isSuperAdmin) {
          Navigator.pushNamed(context, '/admin');
        } else if (selected == 'devices') {
          if ([
            'sejalsankhyan2001@gmail.com',
            'pallavikrishnan01@gmail.com',
            'officeharsh25@gmail.com'
          ].contains(userProvider.userEmail?.trim().toLowerCase())) {
            Navigator.pushNamed(context, '/admin');
          } else if (userProvider.userEmail?.trim().toLowerCase() ==
              '05agriculture.05@gmail.com') {
            Navigator.pushNamed(context, '/deviceinfo');
          } else {
            Navigator.pushNamed(context, '/devicelist');
          }
        } else if (selected == 'account' && !isAdmin) {
          Navigator.pushNamed(context, '/accountinfo');
        } else if (selected == 'logout') {
          _handleLogout();
        } else if (selected == 'login') {
          _showLoginPopup(context);
        }
      },
      child: Row(
        children: [
          Text(
            userProvider.userEmail ?? 'Guest',
            style: TextStyle(
              fontSize: isTablet ? 14 : 16,
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          Icon(
            Icons.arrow_drop_down,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedStatCard({
    required String statValue,
    required String label,
    required ThemeProvider themeProvider,
    required BuildContext context,
  }) {
    double screenWidth = MediaQuery.of(context).size.width;

    // ⬆️ Slightly increased cardSize to allow padding
    double cardSize = screenWidth < 500
        ? 100
        : screenWidth < 850
            ? 150
            : 180;

    double valueFontSize = cardSize * 0.10;
    double labelFontSize = cardSize * 0.08;

    return Container(
      width: cardSize,
      // height: cardSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: themeProvider.isDarkMode
              ? [
                  const Color.fromARGB(255, 29, 56, 68),
                  const Color.fromARGB(228, 69, 59, 71)
                ]
              : [
                  const Color.fromARGB(255, 73, 117, 121),
                  const Color(0xFF81C784)
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0), // 👈 Added padding inside the box
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(seconds: 1),
              builder: (context, progressValue, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: cardSize * 0.5,
                      height: cardSize * 0.5,
                      child: CircularProgressIndicator(
                        value: progressValue,
                        strokeWidth: 6,
                        color: themeProvider.isDarkMode
                            ? const Color.fromARGB(255, 95, 154, 172)
                            : Colors.white,
                        backgroundColor: themeProvider.isDarkMode
                            ? Colors.white10
                            : Colors.white24,
                      ),
                    ),
                    Text(
                      statValue,
                      style: TextStyle(
                        fontSize: valueFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: labelFontSize,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorCard({
    required String imageAsset,
    required String title,
    required String description,
    required VoidCallback onReadMore,
    required double screenWidth,
  }) {
    double titleFontSize =
        screenWidth < 600 ? 12 : (screenWidth < 1300 ? 12 : 14);
    double descriptionFontSize =
        screenWidth < 600 ? 10 : (screenWidth < 1300 ? 10 : 12);
    double buttonFontSize =
        screenWidth < 600 ? 8.0 : (screenWidth < 1300 ? 10.0 : 12.0);

    EdgeInsets cardPadding = EdgeInsets.all(screenWidth < 600 ? 12.0 : 0.0);

    double titleDescriptionSpacing =
        screenWidth < 600 ? 16 : (screenWidth < 1300 ? 7.0 : 5.0);

    bool isCardHovered = false;

    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return MouseRegion(
          onEnter: (_) => setState(() => isCardHovered = true),
          onExit: (_) => setState(() => isCardHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.identity()..scale(isCardHovered ? 1.03 : 1.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isCardHovered
                      ? Colors.black.withOpacity(0.4)
                      : Colors.black.withOpacity(0.2),
                  blurRadius: isCardHovered ? 10 : 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              color: isDarkMode ? Colors.grey[800] : Colors.white,
              child: Padding(
                padding: cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Image.asset(
                        imageAsset,
                        width: screenWidth < 600
                            ? 150
                            : 200, // 📱 smaller on mobile
                        height: screenWidth < 600 ? 150 : 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                              color: const Color.fromARGB(255, 20, 8, 8),
                              height: 80);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ✅ Title
                    Text(
                      title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: titleDescriptionSpacing),

                    // const Spacer(),

                    // ✅ Button
                    // ✅ Button
                    ElevatedButton(
                      onPressed: onReadMore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      child: Text(
                        "READ MORE >",
                        style: TextStyle(
                          fontSize: buttonFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  int getResponsiveCrossAxisCount(double screenWidth) {
    if (screenWidth < 700) return 1;
    if (screenWidth < 1000) return 2;
    return 3;
  }
}
