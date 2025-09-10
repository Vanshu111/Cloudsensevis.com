import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:cloud_sense_webapp/HomePage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'main.dart';

class EndDrawerWidget extends StatefulWidget {
  const EndDrawerWidget({super.key});

  @override
  State<EndDrawerWidget> createState() => _EndDrawerWidgetState();
}

class _EndDrawerWidgetState extends State<EndDrawerWidget> {
  bool _isProductsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // 🔹 Drawer Header
            DrawerHeader(
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.blueGrey[900] : Colors.grey[200],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildUserIcon(context),
                      const SizedBox(width: 8),
                      Text(
                        userProvider.userEmail ?? 'Guest User',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userProvider.userEmail != null
                        ? 'Welcome back!'
                        : 'Please login to access all features',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // 🔹 Logged-in user options
            if (userProvider.userEmail != null) ...[
              ListTile(
                leading: const Icon(Icons.devices),
                title: const Text('My Devices'),
                onTap: () async {
                  Navigator.pop(context);
                  await Future.delayed(const Duration(milliseconds: 200));
                  Navigator.of(context, rootNavigator: true)
                      .pushNamed('/devicelist');
                },
              ),
              if (userProvider.userEmail?.trim().toLowerCase() !=
                  '05agriculture.05@gmail.com')
                ListTile(
                  leading: const Icon(Icons.account_circle),
                  title: const Text('Account Info'),
                  onTap: () async {
                    Navigator.pop(context);
                    await Future.delayed(const Duration(milliseconds: 200));
                    Navigator.of(context, rootNavigator: true)
                        .pushNamed('/accountinfo');
                  },
                ),
              ListTile(
                leading: Icon(themeProvider.isDarkMode
                    ? Icons.light_mode
                    : Icons.dark_mode),
                title: const Text('Theme'),
                onTap: () {
                  // theme toggling doesn't need delayed root navigation
                  themeProvider.toggleTheme();
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share'),
                onTap: () async {
                  Share.share(
                    'Check out our app on Google Play Store: https://play.google.com/store/apps/details?id=com.CloudSenseVis',
                    subject: 'Download Our App',
                  );
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () async {
                  // Close drawer first and wait for the close animation to finish (important on mobile)
                  Navigator.pop(context);
                  await Future.delayed(const Duration(milliseconds: 250));

                  // Use root navigator context for logout to ensure top-level navigation
                  final rootCtx =
                      Navigator.of(context, rootNavigator: true).context;
                  await _handleLogout(rootCtx);
                },
              ),
              const Divider(),
            ],

            // 🔹 Products expandable section
            ListTile(
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory,
                      color: isDarkMode ? Colors.white : Colors.black),
                  const SizedBox(width: 8),
                  Icon(
                    _isProductsExpanded
                        ? Icons.arrow_drop_up
                        : Icons.arrow_drop_down,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ],
              ),
              title: const Text('Products'),
              onTap: () {
                setState(() {
                  _isProductsExpanded = !_isProductsExpanded;
                });
              },
            ),

            if (_isProductsExpanded) _buildProductsList(context),

            // 🔹 Guest user options
            if (userProvider.userEmail == null) ...[
              const Divider(),
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
                onTap: () async {
                  Share.share(
                    'Check out our app on Google Play Store: https://play.google.com/store/apps/details?id=com.CloudSenseVis',
                    subject: 'Download Our App',
                  );
                  Navigator.pop(context);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 🔹 Helper to build Products list
  Widget _buildProductsList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.thermostat, size: 20),
            title: const Text('ATRH Sensor', style: TextStyle(fontSize: 14)),
            onTap: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.thermostat, size: 18),
                  title: const Text(
                    'Temperature and Humidity\nProbe',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await Future.delayed(const Duration(milliseconds: 200));
                    Navigator.of(context, rootNavigator: true)
                        .pushNamed('/probe');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.thermostat, size: 18),
                  title: const Text(
                    'Temperature Humidity\nLight Intensity and\nPressure Radiation Shield',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await Future.delayed(const Duration(milliseconds: 200));
                    Navigator.of(context, rootNavigator: true)
                        .pushNamed('/atrh');
                  },
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.air, size: 20),
            title: const Text('Ultrasonic Anemometer',
                style: TextStyle(fontSize: 14)),
            onTap: () async {
              Navigator.pop(context);
              await Future.delayed(const Duration(milliseconds: 200));
              Navigator.of(context, rootNavigator: true)
                  .pushNamed('/windsensor');
            },
          ),
          ListTile(
            leading: const Icon(Icons.water_drop, size: 20),
            title: const Text('Rain Gauge', style: TextStyle(fontSize: 14)),
            onTap: () async {
              Navigator.pop(context);
              await Future.delayed(const Duration(milliseconds: 200));
              Navigator.of(context, rootNavigator: true)
                  .pushNamed('/raingauge');
            },
          ),
          ListTile(
            leading: const Icon(Icons.storage, size: 20),
            title: const Text('Data Logger', style: TextStyle(fontSize: 14)),
            onTap: () async {
              Navigator.pop(context);
              await Future.delayed(const Duration(milliseconds: 200));
              Navigator.of(context, rootNavigator: true)
                  .pushNamed('/datalogger');
            },
          ),
          ListTile(
            leading: const Icon(Icons.router, size: 20),
            title: const Text('BLE Gateway', style: TextStyle(fontSize: 14)),
            onTap: () async {
              Navigator.pop(context);
              await Future.delayed(const Duration(milliseconds: 200));
              Navigator.of(context, rootNavigator: true).pushNamed('/gateway');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserIcon(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final userProvider = Provider.of<UserProvider>(context);
    final userEmail = userProvider.userEmail;

    if (userEmail == null || userEmail.isEmpty) {
      return Icon(
        Icons.person,
        color: isDarkMode ? Colors.white : Colors.black,
        size: 20, // Reduced icon size
      );
    }
    return CircleAvatar(
      radius: 12, // Reduced from 14
      backgroundColor: isDarkMode ? Colors.white : Colors.black,
      child: Text(
        userEmail[0].toUpperCase(),
        style: TextStyle(
          color: isDarkMode ? Colors.black : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12, // Reduced from 14
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await Amplify.Auth.signOut();
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await unsubscribeFromGpsSnsTopic(fcmToken);
        await unsubscribeFromSnsTopic(fcmToken);
      }
      userProvider.setUser(null);

      // Show snackbar using root context so it appears on top-level scaffold
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out successfully')),
      );

      // Use root navigator to clear stack and send to login
      Navigator.of(context, rootNavigator: true)
          .pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      print('Error during logout: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error logging out')),
      );
      Navigator.of(context, rootNavigator: true)
          .pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  void _showLoginPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Login Required'),
          content:
              const Text('Please log in or sign up to access your devices.'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await Navigator.of(context, rootNavigator: true)
                    .pushNamed('/login');
              },
              child: const Text('Login/Signup'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}
