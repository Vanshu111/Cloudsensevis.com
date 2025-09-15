import 'dart:convert';
import 'dart:math';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:cloud_sense_webapp/appbar.dart';
import 'package:cloud_sense_webapp/devicelocationinfo.dart';
import 'package:cloud_sense_webapp/drawer.dart';
import 'package:cloud_sense_webapp/footer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
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

// Helper function to determine a GRADIENT based on temperature
Gradient _getTemperatureGradient(dynamic tempValue) {
  // Default gradient for null or invalid values
  const defaultGradient = LinearGradient(
    colors: [Color(0xFF868F96), Color(0xFF596164)], // A nice grey gradient
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  if (tempValue == null) {
    return defaultGradient;
  }

  final double? temp = double.tryParse(tempValue.toString());

  if (temp == null) {
    return defaultGradient;
  }

  // Define gradients inspired by weather visuals 🌡️
  if (temp > 35) {
    // Very Hot: Deep red to a fiery orange
    return const LinearGradient(
      colors: [Color(0xffc1121f), Color(0xfffca311)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  } else if (temp > 30) {
    // Hot: Reddish to a warm orange
    return const LinearGradient(
      colors: [Color(0xffe63946), Color(0xfff77f00)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  } else if (temp > 20) {
    // Warm: Sunny orange to a bright yellow
    return const LinearGradient(
      colors: [Color(0xffffa62b), Color(0xffffd700)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  } else if (temp > 10) {
    // Mild: Light green to a soft yellow
    return const LinearGradient(
      colors: [Color(0xffa7c957), Color(0xfff2e8cf)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  } else {
    // Cool: Sky blue to a gentle cyan
    return const LinearGradient(
      colors: [Color(0xff72ddf7), Color(0xffa2d2ff)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}

class AnimatedLightCard extends StatefulWidget {
  final dynamic luxValue;
  final String name;
  final String unit;

  const AnimatedLightCard({
    Key? key,
    required this.luxValue,
    required this.name,
    required this.unit,
  }) : super(key: key);

  @override
  _AnimatedLightCardState createState() => _AnimatedLightCardState();
}

class _AnimatedLightCardState extends State<AnimatedLightCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _starController;
  late List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // Speed of the twinkle
    )..repeat();

    // Create a list of 40 stars with random positions and sizes
    _stars = List.generate(40, (index) => _Star());
  }

  @override
  void dispose() {
    _starController.dispose();
    super.dispose();
  }

  // You can keep your _getLightGradient function as is.
  Gradient _getLightGradient(dynamic luxValue) {
    final double lux = double.tryParse(luxValue.toString()) ?? 0.0;
    if (lux > 100) {
      return const LinearGradient(
          colors: [Color(0xffFDC830), Color(0xffF37335)],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight);
    } else {
      return const LinearGradient(
          colors: [Color(0xff0f2027), Color(0xff2c5364)],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight);
    }
  }

  // REPLACE your old build method with this new one
  @override
  Widget build(BuildContext context) {
    final double lux = double.tryParse(widget.luxValue.toString()) ?? 0.0;
    final bool isDay = lux > 100;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: _getLightGradient(widget.luxValue),
        borderRadius: BorderRadius.circular(8),
      ),
      // Use ClipRRect to make sure the star animation stays inside the rounded corners
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // LAYER 1: The Starfield Background (only visible at night)
            if (!isDay)
              Positioned.fill(
                child: CustomPaint(
                  painter: _StarPainter(
                    stars: _stars,
                    animation: _starController,
                  ),
                ),
              ),

            // LAYER 2: The Main Content (Icon, Name, Value)
            // This Column sits on top of the starfield background.
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 700),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: isDay
                          ? // --- Sun Icon for Day ---
                          const Icon(
                              Icons.wb_sunny_rounded,
                              key: ValueKey('sun'),
                              color: Colors.white,
                              size: 18,
                            )
                          : // --- Moon Icon for Night ---
                          const Icon(
                              Icons.nightlight_round,
                              key: ValueKey('moon'),
                              color: Colors.white,
                              size: 18,
                            ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.name,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "${widget.luxValue} ${widget.unit}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// This is the custom painter that draws each star
class _StarPainter extends CustomPainter {
  final List<_Star> stars;
  final Animation<double> animation;

  _StarPainter({required this.stars, required this.animation})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;

    for (var star in stars) {
      // Get the current opacity of the star from its animation phase
      final opacity = star.getOpacity(animation.value);
      if (opacity > 0) {
        paint.color = Colors.white.withOpacity(opacity);
        // Draw the star at its random position within the canvas
        canvas.drawCircle(Offset(star.x * size.width, star.y * size.height),
            star.radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) => false;
}

// A helper class to hold the properties of a single star
class _Star {
  final double x; // X position (0.0 to 1.0)
  final double y; // Y position (0.0 to 1.0)
  final double radius;
  final double phase; // Random offset for twinkling

  _Star()
      : x = Random().nextDouble(),
        y = Random().nextDouble(),
        radius = Random().nextDouble() * 0.8 + 0.2, // Star size from 0.2 to 1.0
        phase = Random().nextDouble();

  // Calculate opacity using a sine wave to create a smooth twinkle effect
  double getOpacity(double animationValue) {
    return (0.5 * (sin(2 * pi * (animationValue + phase)) + 1)).clamp(0.0, 1.0);
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _totalDevices = 0;
  bool _isHoveredMyDevicesButton = false;
  bool _isPressedMyDevicesButton = false;
  bool _isHoveredbutton = false;
  bool _isPressed = false;

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

  DateTime? lastLocationCheck;
  Duration cacheDuration = const Duration(seconds: 300);
  Map<String, dynamic>? cachedNearest;

  Future<void> fetchDevicesAndNearest({bool silent = false}) async {
    try {
      const url =
          "https://d1b09mxwt0ho4j.cloudfront.net/default/WS_Device_Activity";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        devices = data["devices"] ?? [];

        // 🔹 Total devices count
        _totalDevices = devices.length;

        if (devices.isEmpty) {
          if (mounted) {
            setState(() {
              errorMessage = "No devices found.";
              isLoading = false;
            });
          }
          return;
        }

        final demoDevice = devices.cast<Map<String, dynamic>>().firstWhere(
              (d) => d["deviceid#topic"].toString() == "1#WS/Campus/1",
              orElse: () => devices.first,
            );

        if (mounted) {
          setState(() {
            // update selected device
            if (selectedDevice == null) {
              selectedDevice = demoDevice;
            } else {
              final updated = devices.firstWhere(
                (d) =>
                    d["deviceid#topic"].toString() ==
                    selectedDevice?["deviceid#topic"].toString(),
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
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<bool> _getUserLocationAndFindNearest() async {
    if (lastLocationCheck != null &&
        DateTime.now().difference(lastLocationCheck!) < cacheDuration &&
        cachedNearest != null) {
      // debugPrint("Using cached nearest device");
      if (mounted) {
        setState(() {
          nearestDevice = cachedNearest;
          selectedDevice = cachedNearest;
          errorMessage = null;
        });
      }
      return true;
    }

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
          errorMessage = null;
        });

        lastLocationCheck = DateTime.now();
        cachedNearest = nearest;
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

    // Special case for RainfallHourly to display as "Rainfall"
    if (paramName == 'RainfallHourly') return 'Rainfall';

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
    Provider.of<UserProvider>(context);
    final currentDate = DateFormat("EEEE, dd MMMM yyyy").format(DateTime.now());
    DateFormat("hh:mm a").format(DateTime.now());

    // GlobalKeys for positioning dropdowns

    double paragraphFont = screenWidth < 800
        ? 14
        : screenWidth < 1024
            ? 18
            : 18;

    return LayoutBuilder(builder: (context, constraints) {
      final isWideScreen = screenWidth > 1024; // Desktop

      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        appBar: AppBarWidget(),
        endDrawer: !isWideScreen ? const EndDrawerWidget() : null,
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
                                            style: (selectedDevice?[
                                                            "deviceid#topic"]
                                                        .toString() ==
                                                    "1#WS/Campus/1")
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
                                              if (selectedDevice?[
                                                          "deviceid#topic"]
                                                      .toString() ==
                                                  "1#WS/Campus/1") {
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
                                                              d["deviceid#topic"]
                                                                  .toString() ==
                                                              "1#WS/Campus/1",
                                                          orElse: () =>
                                                              devices.first);
                                                  errorMessage = null;
                                                });
                                              }
                                            },
                                            child: selectedDevice?[
                                                            "deviceid#topic"]
                                                        .toString() ==
                                                    "1#WS/Campus/1"
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
                                                                      // AFTER
                                                                      decoration: BoxDecoration(
                                                                          gradient: _getTemperatureGradient(selectedDevice?["CurrentTemperature"]), // <-- Use the new gradient function here
                                                                          borderRadius: BorderRadius.circular(8)),
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
                                                                            "TimeStamp_IST",
                                                                            "CurrentTemperature",
                                                                            "deviceid#topic",
                                                                            "ExpiresAt",
                                                                            "IMEINumber",
                                                                            "LastUpdated",
                                                                            "Topic",
                                                                            "SignalStrength",
                                                                            "BatteryVoltage",
                                                                            "RainfallDaily",
                                                                            "RainfallWeekly"
                                                                          }.contains(e.key))
                                                                      .map((e) {
                                                                    // ADD: Check for WindSpeed key first (before LightIntensity)

                                                                    if (e.key ==
                                                                        "LightIntensity") {
                                                                      // This call remains the same, but it will now use the new animation code
                                                                      return AnimatedLightCard(
                                                                        luxValue:
                                                                            _formatValue(e.value),
                                                                        name: _getNameForKey(
                                                                            e.key),
                                                                        unit: _getUnitForKey(
                                                                            e.key),
                                                                      );
                                                                    } else {
                                                                      // --- Build the default widget for all other items ---
                                                                      return Container(
                                                                        padding: const EdgeInsets
                                                                            .all(
                                                                            2),
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          color: Colors
                                                                              .white
                                                                              .withOpacity(0.1),
                                                                          borderRadius:
                                                                              BorderRadius.circular(8),
                                                                        ),
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
                                                                            Text("${_formatValue(e.value)} ${_getUnitForKey(e.key)}",
                                                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                                                                textAlign: TextAlign.center),
                                                                          ],
                                                                        ),
                                                                      );
                                                                    }
                                                                  }).toList(),
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
                                                                // AFTER
                                                                decoration:
                                                                    BoxDecoration(
                                                                        gradient:
                                                                            _getTemperatureGradient(selectedDevice?[
                                                                                "CurrentTemperature"]), // <-- Use the new gradient function here
                                                                        borderRadius:
                                                                            BorderRadius.circular(8)),
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
                                                                      "TimeStamp_IST",
                                                                      "CurrentTemperature",
                                                                      "deviceid#topic",
                                                                      "ExpiresAt",
                                                                      "IMEINumber",
                                                                      "LastUpdated",
                                                                      "Topic",
                                                                      "SignalStrength",
                                                                      "BatteryVoltage",
                                                                      "RainfallDaily",
                                                                      "RainfallWeekly"
                                                                    }.contains(
                                                                        e.key))
                                                                .map((e) {
                                                              // ADD: Check for WindSpeed key first (before LightIntensity)

                                                              if (e.key ==
                                                                  "LightIntensity") {
                                                                // This call remains the same, but it will now use the new animation code
                                                                return AnimatedLightCard(
                                                                  luxValue:
                                                                      _formatValue(
                                                                          e.value),
                                                                  name:
                                                                      _getNameForKey(
                                                                          e.key),
                                                                  unit:
                                                                      _getUnitForKey(
                                                                          e.key),
                                                                );
                                                              } else {
                                                                // --- Build the default widget for all other items ---
                                                                return Container(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .all(
                                                                          2),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: Colors
                                                                        .white
                                                                        .withOpacity(
                                                                            0.1),
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(8),
                                                                  ),
                                                                  child: Column(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .center,
                                                                    children: [
                                                                      Row(
                                                                          mainAxisAlignment:
                                                                              MainAxisAlignment.center,
                                                                          children: [
                                                                            Icon(_getIconForKey(e.key),
                                                                                color: Colors.white,
                                                                                size: 14),
                                                                            const SizedBox(width: 4),
                                                                            Text("${_getNameForKey(e.key)}",
                                                                                style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
                                                                );
                                                              }
                                                            }).toList(),
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
                                                          "Last Updated: ${_formatValue(selectedDevice?["TimeStamp_IST"])}",
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
                      gradient: LinearGradient(
                        colors: isDarkMode
                            ? [
                                Colors.blueGrey.shade800,
                                const Color.fromARGB(137, 49, 47, 47)
                              ]
                            : [
                                const Color.fromARGB(255, 255, 255, 255)
                                    .withOpacity(0.3),
                                const Color.fromARGB(255, 94, 211, 162)
                                    .withOpacity(0.3)
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
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
                  Footer(),
                ],
              ),
            )
          ],
        ),
      );
    });
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
              color: isDarkMode
                  ? Colors.grey[800]
                  : const Color.fromARGB(255, 224, 220, 220),
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
