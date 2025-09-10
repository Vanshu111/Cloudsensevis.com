import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:cloud_sense_webapp/HomePage.dart';
import 'package:cloud_sense_webapp/main.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

class AppBarWidget extends StatefulWidget implements PreferredSizeWidget {
  const AppBarWidget({super.key});

  @override
  _AppBarWidgetState createState() => _AppBarWidgetState();

  @override
  Size get preferredSize => const Size.fromHeight(56); // Reduced from 70 to 56
}

class _AppBarWidgetState extends State<AppBarWidget> {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out successfully')),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      print('Error during logout: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error logging out')),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  Future<void> _handleDeviceNavigation(BuildContext context) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final email = userProvider.userEmail;
    if (email == null) {
      _showLoginPopup(context);
      return;
    }
    try {
      if (email.trim().toLowerCase() == '05agriculture.05@gmail.com') {
        Navigator.pushNamed(context, '/deviceinfo');
      } else {
        await manageNotificationSubscription();
        Navigator.pushNamed(context, '/devicelist');
      }
    } catch (e) {
      print('Error checking user: $e');
      Navigator.pushNamed(context, '/login');
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
                await Navigator.pushNamed(context, '/login');
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
                            color: isDarkMode ? Colors.white : Colors.black,
                            size: 20), // Reduced icon size
                        const SizedBox(width: 8),
                        const Text('ATRH Sensor'),
                        const SizedBox(width: 8),
                        Icon(
                          isAtrhExpanded
                              ? Icons.arrow_drop_up
                              : Icons.arrow_drop_down,
                          color: isDarkMode ? Colors.white : Colors.black,
                          size: 20, // Reduced icon size
                        ),
                      ],
                    ),
                  ),
                  if (isAtrhExpanded) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, '/probe');
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              Icon(Icons.thermostat,
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                  size: 20), // Reduced icon size
                              const SizedBox(width: 8),
                              const Text('Temperature and Humidity\nProbe'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, '/atrh');
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              Icon(Icons.thermostat,
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                  size: 20), // Reduced icon size
                              const SizedBox(width: 8),
                              const Text(
                                  'Temperature Humidity\nLight Intensity and\nPressure Radiation Shield'),
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
              Icon(Icons.air,
                  color: isDarkMode ? Colors.white : Colors.black,
                  size: 20), // Reduced icon size
              const SizedBox(width: 8),
              const Text('Ultrasonic Anemometer'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'rain_gauge',
          child: Row(
            children: [
              Icon(Icons.water_drop,
                  color: isDarkMode ? Colors.white : Colors.black,
                  size: 20), // Reduced icon size
              const SizedBox(width: 8),
              const Text('Rain Gauge'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'data_logger',
          child: Row(
            children: [
              Icon(Icons.storage,
                  color: isDarkMode ? Colors.white : Colors.black,
                  size: 20), // Reduced icon size
              const SizedBox(width: 8),
              const Text('Data Logger'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'gateway',
          child: Row(
            children: [
              Icon(Icons.router,
                  color: isDarkMode ? Colors.white : Colors.black,
                  size: 20), // Reduced icon size
              const SizedBox(width: 8),
              const Text('BLE Gateway'),
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

  Widget _buildUserDropdown(BuildContext context, bool isDarkMode,
      bool isTablet, GlobalKey userButtonKey) {
    final userProvider = Provider.of<UserProvider>(context);
    final isAdmin = userProvider.userEmail?.trim().toLowerCase() ==
        '05agriculture.05@gmail.com';

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
              ? [
                  PopupMenuItem(
                    value: 'devices',
                    child: Row(
                      children: [
                        Icon(Icons.devices,
                            color: isDarkMode ? Colors.white : Colors.black,
                            size: 20), // Reduced icon size
                        const SizedBox(width: 8),
                        const Text('My Devices'),
                      ],
                    ),
                  ),
                  if (!isAdmin)
                    PopupMenuItem(
                      value: 'account',
                      child: Row(
                        children: [
                          Icon(Icons.account_circle,
                              color: isDarkMode ? Colors.white : Colors.black,
                              size: 20), // Reduced icon size
                          const SizedBox(width: 8),
                          const Text('Account Info'),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout,
                            color: isDarkMode ? Colors.white : Colors.black,
                            size: 20), // Reduced icon size
                        const SizedBox(width: 8),
                        const Text('Logout'),
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
                            color: isDarkMode ? Colors.white : Colors.black,
                            size: 20), // Reduced icon size
                        const SizedBox(width: 8),
                        const Text('Login/Signup'),
                      ],
                    ),
                  ),
                ],
        );

        if (selected == 'devices') {
          Navigator.pushNamed(context, '/devicelist');
        } else if (selected == 'account' && !isAdmin) {
          Navigator.pushNamed(context, '/accountinfo');
        } else if (selected == 'logout') {
          _handleLogout(context);
        } else if (selected == 'login') {
          _showLoginPopup(context);
        }
      },
      child: Row(
        children: [
          Text(
            userProvider.userEmail ?? 'Guest',
            style: TextStyle(
              fontSize: isTablet ? 12 : 14, // Reduced from 14/16
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          Icon(
            Icons.arrow_drop_down,
            color: isDarkMode ? Colors.white : Colors.black,
            size: 18, // Reduced from 20
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);

    final GlobalKey productsButtonKey = GlobalKey();
    final GlobalKey userButtonKey = GlobalKey();

    bool isMobile = screenWidth < 800;
    bool isTablet = screenWidth >= 800 && screenWidth <= 1024;

    return AppBar(
      elevation: 0, // remove shadow
      scrolledUnderElevation:
          0, // NEW: disables the lighter overlay effect when scrolled
      surfaceTintColor: Colors.transparent, // prevents automatic tint
      iconTheme: IconThemeData(
        color: isDarkMode ? Colors.white : Colors.black,
      ),
      backgroundColor: isDarkMode ? Colors.blueGrey[900] : Colors.white,
      toolbarHeight: 56, // Reduced from 70 to 56
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: EdgeInsets.only(
                left: screenWidth < 800 ? 6 : 20), // Adjusted padding
            child: GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/');
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud,
                    color: isDarkMode ? Colors.white : Colors.black,
                    size: screenWidth < 800
                        ? 20 // Reduced from 24
                        : screenWidth <= 1024
                            ? 28 // Reduced from 32
                            : 40, // Reduced from 46
                  ),
                  SizedBox(
                      width: isMobile
                          ? 8
                          : (isTablet ? 12 : 16)), // Adjusted spacing
                  Text(
                    'Cloud Sense Vis',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: screenWidth < 800
                          ? 18 // Reduced from 20
                          : screenWidth <= 1024
                              ? 22 // Reduced from 26
                              : 40, // Reduced from 46
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isMobile)
            Padding(
              padding: EdgeInsets.only(
                  right: screenWidth < 800 ? 6 : 20), // Adjusted padding
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    key: productsButtonKey,
                    onPressed: () =>
                        _showSensorPopup(context, buttonKey: productsButtonKey),
                    child: Row(
                      children: [
                        const SizedBox(width: 4),
                        Text(
                          'Products',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: isTablet ? 12 : 14, // Reduced from 14/16
                          ),
                        ),
                        Icon(Icons.arrow_drop_down,
                            color: isDarkMode ? Colors.white : Colors.black,
                            size: isTablet ? 16 : 18), // Reduced from 18/20
                      ],
                    ),
                  ),
                  SizedBox(
                      width: screenWidth <= 1024 ? 10 : 20), // Adjusted spacing
                  userProvider.userEmail != null
                      ? Row(
                          key: userButtonKey,
                          children: [
                            _buildUserIcon(context),
                            const SizedBox(width: 6), // Reduced from 8
                            _buildUserDropdown(
                                context, isDarkMode, isTablet, userButtonKey),
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
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize:
                                      isTablet ? 12 : 14, // Reduced from 14/16
                                ),
                              ),
                              Icon(Icons.arrow_drop_down,
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                  size:
                                      isTablet ? 16 : 18), // Reduced from 18/20
                            ],
                          ),
                        ),
                  SizedBox(
                      width: screenWidth <= 1024 ? 10 : 20), // Adjusted spacing
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
                          size: isTablet ? 16 : 18, // Reduced from 18/20
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Theme',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: isTablet ? 12 : 14, // Reduced from 14/16
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
                    size: 20, // Reduced from default
                  ),
                  onPressed: () {
                    Scaffold.of(context).openEndDrawer();
                  },
                ),
              ),
            ]
          : [],
    );
  }
}
