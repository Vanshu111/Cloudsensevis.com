import 'dart:async';
import 'dart:convert';
import 'package:cloud_sense_webapp/src/utils/Shared_Add_Device.dart';
import 'package:cloud_sense_webapp/src/views/dashboard/device_graph.dart';
import 'package:cloud_sense_webapp/src/utils/device_activity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_sense_webapp/src/utils/DeleteDevice.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({Key? key}) : super(key: key);

  @override
  State<AdminPage> createState() => _AdminPageState();
}

double getResponsiveFontSize(
    BuildContext context, double mobileSize, double desktopSize) {
  final width = MediaQuery.of(context).size.width;
  return width <= 600 ? mobileSize : desktopSize;
}

class _AdminPageState extends State<AdminPage> {
  // ✅ Create an instance of the service
  final DeviceService _deviceService = DeviceService();
  // API URLs still in use by this page

  final String userApiUrl =
      "https://25e5bsdhwd.execute-api.us-east-1.amazonaws.com/default/CloudSense_users_delete_function"; // Used by fetchUsers
  final String flaggingApiUrl =
      "https://hmnrva928j.execute-api.us-east-1.amazonaws.com/default/WS_Flag_API";
  final String userDevicesApiUrl =
      "https://ln8b1r7ld9.execute-api.us-east-1.amazonaws.com/default/Cloudsense_user_devices";

  bool isLoading = true;
  List<Map<String, dynamic>> allDevices = [];
  int totalActive = 0;
  int totalInactive = 0;
  String filter = "All";
  String searchQuery = "";
  List<Map<String, String>> users = [];
  bool isUsersLoading = true;
  Map<String, Map<String, String>> latestAnomalies = {};
  List<Map<String, String>> notifications = [];
  List<Map<String, String>> dismissedNotifications = [];
  Timer? _anomalyTimer;
  FlutterLocalNotificationsPlugin? _notificationsPlugin;

  int devicesToShow = 4;
  int usersToShow = 4;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadDeviceData();
    fetchUsers();
    if (!kIsWeb) {
      _initializeNotifications();
    }
    fetchAnomalies();
    _anomalyTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => fetchAnomalies());
  }

  // ✅ New method to load data using the service
  Future<void> _loadDeviceData() async {
    setState(() => isLoading = true);
    final summary = await _deviceService.fetchDeviceActivity();

    if (mounted) {
      if (summary != null) {
        setState(() {
          allDevices = summary.allDevices;
          totalActive = summary.totalActive;
          totalInactive = summary.totalInactive;
        });
      } else {
        _toast("Failed to fetch device data.");
      }
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final notifsJson = prefs.getString('notifications');
    if (notifsJson != null) {
      final decoded = json.decode(notifsJson) as List;
      notifications =
          decoded.map((item) => Map<String, String>.from(item)).toList();
    }
    final dismissedJson = prefs.getString('dismissedNotifications');
    if (dismissedJson != null) {
      final decoded = json.decode(dismissedJson) as List;
      dismissedNotifications =
          decoded.map((item) => Map<String, String>.from(item)).toList();
    }
    setState(() {});
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('notifications', json.encode(notifications));
    prefs.setString(
        'dismissedNotifications', json.encode(dismissedNotifications));
  }

  @override
  void dispose() {
    _anomalyTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);
    await _notificationsPlugin!.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          _handleNotificationTap(response.payload!);
        }
      },
    );
  }

  // ... (All other methods like fetchAnomalies, _showNotification, fetchDevices, etc., remain unchanged)

  Future<void> fetchAnomalies() async {
    final newNotifications = <Map<String, String>>[];
    final failedDevices = <String, int>{}; // Track failed attempts per device
    const int batchSize = 5;
    final devicesToFetch = allDevices.where((d) {
      final deviceId = d['DeviceId'] ?? "";
      final topic = d['Topic'] ?? "Unknown";
      return deviceId.isNotEmpty && topic.contains('WS/Campus');
    }).toList();

    for (int i = 0; i < devicesToFetch.length; i += batchSize) {
      final end = (i + batchSize < devicesToFetch.length)
          ? i + batchSize
          : devicesToFetch.length;
      final batch = devicesToFetch.sublist(i, end);

      await Future.wait(batch.map((d) async {
        final deviceId = d['DeviceId'] ?? "";
        final topic = d['Topic'] ?? "Unknown";
        final deviceIdTopic = "$deviceId#$topic";

        failedDevices[deviceId] = failedDevices[deviceId] ?? 0;

        if (failedDevices[deviceId]! >= 5) {
          return;
        }

        try {
          final response = await http
              .get(Uri.parse("$flaggingApiUrl?DeviceID=$deviceId"))
              .timeout(
            const Duration(seconds: 200),
            onTimeout: () {
              throw TimeoutException(
                  "Request to $flaggingApiUrl timed out for device $deviceId");
            },
          );
          if (response.statusCode == 200) {
            failedDevices[deviceId] = 0; // Reset failure count on success
            final data = json.decode(response.body);
            if (data is List && data.isNotEmpty) {
              final anomalies = data
                  .map((item) => item as Map<String, dynamic>)
                  .where((item) =>
                      item['Anomaly'] != null && item['Timestamp'] != null)
                  .toList()
                ..sort((a, b) {
                  final dtA =
                      parseDate(a['Timestamp']?.toString()) ?? DateTime(0);
                  final dtB =
                      parseDate(b['Timestamp']?.toString()) ?? DateTime(0);
                  return dtB.compareTo(dtA);
                });

              final groupedAnomalies = <String, List<Map<String, String>>>{};
              for (var item in anomalies) {
                final anomaly = item['Anomaly']?.toString() ?? "";
                final timestamp = item['Timestamp']?.toString() ?? "";
                if (anomaly.isNotEmpty && timestamp.isNotEmpty) {
                  groupedAnomalies
                      .putIfAbsent(anomaly, () => [])
                      .add({'timestamp': timestamp});
                }
              }

              for (var anomaly in groupedAnomalies.keys) {
                final timestamps = groupedAnomalies[anomaly]!;
                if (timestamps.length > 2) {
                  timestamps.sort((a, b) {
                    final dtA = parseDate(a['timestamp']) ?? DateTime(0);
                    final dtB = parseDate(b['timestamp']) ?? DateTime(0);
                    return dtA.compareTo(dtB);
                  });
                  final startTime = timestamps.first['timestamp']!;
                  final endTime = timestamps.last['timestamp']!;
                  final period = (startTime == endTime)
                      ? "at $startTime"
                      : "from $startTime to $endTime";
                  final message =
                      _buildNotificationMessage(deviceIdTopic, anomaly, period);

                  final isAlreadyNotified = notifications.any(
                    (n) =>
                        n['deviceIdTopic'] == deviceIdTopic &&
                        n['anomaly'] == anomaly &&
                        n['period'] == period,
                  );
                  final isDismissed = dismissedNotifications.any(
                    (dn) =>
                        dn['deviceIdTopic'] == deviceIdTopic &&
                        dn['anomaly'] == anomaly &&
                        dn['period'] == period,
                  );

                  if (!isAlreadyNotified && !isDismissed) {
                    newNotifications.add({
                      'deviceIdTopic': deviceIdTopic,
                      'message': message,
                      'anomaly': anomaly,
                      'timestamp': endTime,
                      'period': period,
                    });
                    final uniqueId = "$deviceIdTopic#$anomaly#$endTime";
                    _showNotification(uniqueId, message);
                  }

                  final latestTimestamp = timestamps.last['timestamp']!;
                  latestAnomalies[deviceIdTopic] = {
                    'anomaly': anomaly,
                    'timestamp': latestTimestamp,
                  };
                } else if (timestamps.length <= 2) {
                  for (var ts in timestamps) {
                    final timestamp = ts['timestamp']!;
                    final message = _buildNotificationMessage(
                        deviceIdTopic, anomaly, timestamp);
                    final isAlreadyNotified = notifications.any(
                      (n) =>
                          n['deviceIdTopic'] == deviceIdTopic &&
                          n['timestamp'] == timestamp,
                    );
                    final isDismissed = dismissedNotifications.any(
                      (dn) =>
                          dn['deviceIdTopic'] == deviceIdTopic &&
                          dn['timestamp'] == timestamp,
                    );

                    if (!isAlreadyNotified && !isDismissed) {
                      newNotifications.add({
                        'deviceIdTopic': deviceIdTopic,
                        'message': message,
                        'anomaly': anomaly,
                        'timestamp': timestamp,
                        'period': timestamp,
                      });
                      final uniqueId = "$deviceIdTopic#$timestamp";
                      _showNotification(uniqueId, message);
                    }

                    final currentLatest = latestAnomalies[deviceIdTopic];
                    if (currentLatest == null ||
                        (parseDate(timestamp)?.isAfter(
                                parseDate(currentLatest['timestamp']) ??
                                    DateTime(0)) ??
                            false)) {
                      latestAnomalies[deviceIdTopic] = {
                        'anomaly': anomaly,
                        'timestamp': timestamp,
                      };
                    }
                  }
                }
              }
            }
          } else {
            failedDevices[deviceId] = (failedDevices[deviceId] ?? 0) + 1;
          }
        } catch (e) {
          failedDevices[deviceId] = (failedDevices[deviceId] ?? 0) + 1;
          if ((failedDevices[deviceId] ?? 0) >= 5) {
            _toast(
                "Persistent error fetching anomalies for device $deviceId. Skipping further attempts.");
          }
        }
      }));
    }

    if (newNotifications.isNotEmpty) {
      setState(() {
        notifications.addAll(newNotifications);
        notifications.sort((a, b) {
          final da = parseDate(a['timestamp']) ?? DateTime(0);
          final db = parseDate(b['timestamp']) ?? DateTime(0);
          return db.compareTo(da);
        });
      });
      await _savePrefs();
    } else {
      setState(() {});
    }
  }

  String _buildNotificationMessage(
      String deviceIdTopic, String anomaly, String timeInfo) {
    final deviceId = deviceIdTopic.split('#')[0];
    final topic = deviceIdTopic.split('#').length > 1
        ? deviceIdTopic.split('#')[1]
        : "Unknown";
    final mapped = _mapCategoryAndPrefix(topic);
    final sensorName = mapped.prefix.isNotEmpty
        ? "${mapped.prefix}${deviceId.padLeft(3, '0')}"
        : deviceId;
    return "Anomaly in Device $sensorName: $anomaly $timeInfo";
  }

  Future<void> _showNotification(String uniqueId, String message) async {
    if (kIsWeb) {
      return;
    }
    const androidDetails = AndroidNotificationDetails(
      'anomaly_channel',
      'Anomaly Alerts',
      channelDescription: 'Notifications for device anomalies',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const platformDetails =
        NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _notificationsPlugin?.show(
      uniqueId.hashCode,
      'Device Anomaly',
      message,
      platformDetails,
      payload: uniqueId,
    );
  }

  void _handleNotificationTap(String payload) {
    final parts = payload.split('#');
    if (parts.length < 3) {
      _toast("Invalid notification data");
      return;
    }
    final deviceId = parts[0];
    final topic = parts[1];
    final timestampOrAnomaly = parts[2];
    final deviceIdTopic = '$deviceId#$topic';

    final notification = notifications.firstWhere(
      (n) =>
          n['deviceIdTopic'] == deviceIdTopic &&
          (n['timestamp'] == timestampOrAnomaly ||
              n['anomaly'] == timestampOrAnomaly),
      orElse: () => {},
    );
    if (notification.isEmpty) {
      _toast("Notification not found");
      return;
    }

    final device = filteredDevices.asMap().entries.firstWhere(
          (entry) =>
              entry.value['DeviceId'] == deviceId &&
              entry.value['Topic'] == topic,
          orElse: () => const MapEntry(-1, {}),
        );
    if (device.key != -1) {
      final mapped = _mapCategoryAndPrefix(topic);
      final sensorName = mapped.prefix.isNotEmpty
          ? "${mapped.prefix}${deviceId.padLeft(3, '0')}"
          : deviceId;
      final sequentialName = mapped.category;
      final anomalyMessage =
          notification['anomaly'] ?? "No anomaly data available";
      final period =
          notification['period'] ?? notification['timestamp'] ?? "N/A";

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text("Anomaly Details for $sensorName"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Device ID: $deviceId"),
              const SizedBox(height: 6),
              Text("Topic: $topic"),
              const SizedBox(height: 6),
              Text("Anomaly: $anomalyMessage"),
              const SizedBox(height: 6),
              Text("Time: $period"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeviceGraphPage(
                      deviceName: sensorName,
                      sequentialName: sequentialName,
                      backgroundImagePath: 'assets/backgroundd.jpg',
                    ),
                  ),
                );
              },
              child: const Text("View Device"),
            ),
          ],
        ),
      );
    } else {
      _toast("Device not found for $deviceIdTopic");
    }
  }

  void _dismissNotification(
      String deviceIdTopic, String timestamp, String anomaly) {
    setState(() {
      final notificationIndex = notifications.indexWhere(
        (n) =>
            n['deviceIdTopic'] == deviceIdTopic &&
            (n['timestamp'] == timestamp || n['anomaly'] == anomaly),
      );
      if (notificationIndex != -1) {
        final notification = notifications[notificationIndex];
        dismissedNotifications.add({
          'deviceIdTopic': deviceIdTopic,
          'anomaly': notification['anomaly'] ?? "",
          'timestamp': notification['timestamp'] ?? "",
          'period': notification['period'] ?? "",
        });
        notifications.removeAt(notificationIndex);
        if (!kIsWeb) {
          final uniqueId = "$deviceIdTopic#$anomaly#$timestamp";
          _notificationsPlugin?.cancel(uniqueId.hashCode);
        }
      }
    });
    _savePrefs();
  }

  void _showNotificationsDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtle = isDark ? Colors.white70 : Colors.black54;
    final strong = isDark ? Colors.white : Colors.black;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, dialogSetState) {
          final ScrollController scrollController = ScrollController();

          Map<String, List<Map<String, String>>> groupedNotifications = {};
          for (var n in notifications) {
            final key = n['deviceIdTopic']!;
            groupedNotifications.putIfAbsent(key, () => []).add(n);
          }

          groupedNotifications.forEach((key, list) {
            list.sort((a, b) {
              final da = parseDate(a['timestamp']) ?? DateTime(0);
              final db = parseDate(b['timestamp']) ?? DateTime(0);
              return db.compareTo(da);
            });
          });

          final sortedKeys = groupedNotifications.keys.toList();
          sortedKeys.sort((a, b) {
            final ta = parseDate(groupedNotifications[a]![0]['timestamp']) ??
                DateTime(0);
            final tb = parseDate(groupedNotifications[b]![0]['timestamp']) ??
                DateTime(0);
            return tb.compareTo(ta);
          });

          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 400),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Notifications (${notifications.length})",
                        style: TextStyle(
                          color: strong,
                          fontSize: getResponsiveFontSize(context, 14, 16),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Row(
                        children: [
                          if (notifications.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.delete_sweep,
                                  color: Colors.red,
                                  size: getResponsiveFontSize(context, 16, 24)),
                              onPressed: () {
                                dialogSetState(() {
                                  notifications.clear();
                                });
                                _savePrefs();
                                if (!kIsWeb) {
                                  _notificationsPlugin?.cancelAll();
                                }
                              },
                              tooltip: 'Clear All',
                            ),
                          IconButton(
                            icon: Icon(Icons.close,
                                color: subtle,
                                size: getResponsiveFontSize(context, 16, 24)),
                            onPressed: () => Navigator.pop(dialogContext),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 1, thickness: 1),
                  const SizedBox(height: 12),
                  Expanded(
                    child: notifications.isEmpty
                        ? Center(
                            child: Text(
                              "No notifications",
                              style: TextStyle(
                                  color: subtle,
                                  fontSize:
                                      getResponsiveFontSize(context, 12, 14)),
                            ),
                          )
                        : Scrollbar(
                            thumbVisibility: true,
                            controller: scrollController,
                            child: ListView.separated(
                              controller: scrollController,
                              itemCount: sortedKeys.length,
                              separatorBuilder: (_, __) => Divider(
                                  color: subtle.withOpacity(0.12), height: 1),
                              itemBuilder: (_, i) {
                                final key = sortedKeys[i];
                                final deviceNotifs = groupedNotifications[key]!;
                                final latest = deviceNotifs[0];
                                final hasMore = deviceNotifs.length > 1;

                                final deviceParts = key.split('#');
                                final deviceId = deviceParts[0];
                                final topic = deviceParts.length > 1
                                    ? deviceParts[1]
                                    : "Unknown";
                                final mapped = _mapCategoryAndPrefix(topic);
                                final sensorName = mapped.prefix.isNotEmpty
                                    ? "${mapped.prefix}${deviceId.padLeft(3, '0')}"
                                    : deviceId;

                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.warning,
                                        color: Colors.orange,
                                        size: getResponsiveFontSize(
                                            context, 16, 24),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Anomaly in Device $sensorName: ${latest['anomaly']}",
                                              style: TextStyle(
                                                color: strong,
                                                fontSize: getResponsiveFontSize(
                                                    context, 10, 14),
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 4,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              latest['period']!,
                                              style: TextStyle(
                                                color: subtle,
                                                fontSize: getResponsiveFontSize(
                                                    context, 8, 14),
                                              ),
                                            ),
                                            if (hasMore)
                                              GestureDetector(
                                                onTap: () {
                                                  _showDeviceNotificationsDialog(
                                                      dialogContext,
                                                      key,
                                                      dialogSetState);
                                                },
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 4.0),
                                                  child: Text(
                                                    "+${deviceNotifs.length - 1} more",
                                                    style: TextStyle(
                                                      color: Colors.blue,
                                                      fontSize:
                                                          getResponsiveFontSize(
                                                              context, 10, 12),
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                          size: getResponsiveFontSize(
                                              context, 16, 24),
                                        ),
                                        onPressed: () {
                                          dialogSetState(() {
                                            _dismissNotification(
                                                key,
                                                latest['timestamp']!,
                                                latest['anomaly']!);
                                          });
                                        },
                                        tooltip: 'Dismiss',
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeviceNotificationsDialog(BuildContext dialogContext,
      String deviceIdTopic, StateSetter dialogSetState) {
    final deviceId = deviceIdTopic.split('#')[0];
    final topic = deviceIdTopic.split('#').length > 1
        ? deviceIdTopic.split('#')[1]
        : "Unknown";
    final mapped = _mapCategoryAndPrefix(topic);
    final sensorName = mapped.prefix.isNotEmpty
        ? "${mapped.prefix}${deviceId.padLeft(3, '0')}"
        : deviceId;

    showDialog(
      context: dialogContext,
      builder: (subContext) => StatefulBuilder(
        builder: (subContext, subSetState) {
          final deviceNotifs = notifications
              .where((n) => n['deviceIdTopic'] == deviceIdTopic)
              .toList()
            ..sort((a, b) {
              final da = parseDate(a['timestamp']) ?? DateTime(0);
              final db = parseDate(b['timestamp']) ?? DateTime(0);
              return db.compareTo(da);
            });

          if (deviceNotifs.isEmpty) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => Navigator.pop(subContext));
            return const SizedBox.shrink();
          }

          final theme = Theme.of(subContext);
          final isDark = theme.brightness == Brightness.dark;
          final subtle = isDark ? Colors.white70 : Colors.black54;
          final strong = isDark ? Colors.white : Colors.black;

          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 400),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Notifications for $sensorName (${deviceNotifs.length})",
                          style: TextStyle(
                            color: strong,
                            fontSize: getResponsiveFontSize(context, 14, 16),
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close,
                            color: subtle,
                            size: getResponsiveFontSize(context, 16, 24)),
                        onPressed: () => Navigator.pop(subContext),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: deviceNotifs.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: subtle.withOpacity(.12)),
                      itemBuilder: (_, i) {
                        final n = deviceNotifs[i];
                        return ListTile(
                          title: Row(
                            children: [
                              Icon(Icons.warning,
                                  color: Colors.orange,
                                  size: getResponsiveFontSize(context, 16, 24)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  n['message']!,
                                  style: TextStyle(
                                    color: strong,
                                    fontSize:
                                        getResponsiveFontSize(context, 8, 12),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete,
                                    color: Colors.red,
                                    size:
                                        getResponsiveFontSize(context, 16, 24)),
                                onPressed: () {
                                  _dismissNotification(deviceIdTopic,
                                      n['timestamp']!, n['anomaly']!);
                                  subSetState(() {});
                                  dialogSetState(() {});
                                },
                                tooltip: 'Dismiss',
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.pop(subContext);
                            Navigator.pop(dialogContext);
                            _handleNotificationTap(
                                "$deviceIdTopic#${n['anomaly']}#${n['timestamp']}");
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> fetchUsers() async {
    if (!mounted) return;
    setState(() => isUsersLoading = true);
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final response = await http
            .get(Uri.parse("$userApiUrl?action=list"))
            .timeout(const Duration(seconds: 10));
        if (mounted) {
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            List<Map<String, String>> userList = [];

            if (data is Map &&
                data.containsKey('users') &&
                data['users'] is List) {
              userList =
                  (data['users'] as List).map<Map<String, String>>((email) {
                return {"email": email.toString(), "role": "User"};
              }).toList();
            }

            setState(() {
              users = userList;
              isUsersLoading = false;
            });

            if (users.isEmpty) {
              _toast("No valid user data received");
            }
            return;
          } else {
            if (attempt == 3) {
              setState(() => isUsersLoading = false);
              _toast("User API error: ${response.statusCode}");
              return;
            }
          }
        }
      } catch (e) {
        if (attempt == 3 && mounted) {
          setState(() => isUsersLoading = false);
          _toast("User fetch failed: $e");
        }
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> _showUserDevices(String email) async {
    Map<String, List<String>> deviceCategories = {};
    bool isLoadingDevices = true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, dialogSetState) {
          Future<void> _refreshDevices() async {
            dialogSetState(() => isLoadingDevices = true);
            try {
              final response = await http
                  .get(Uri.parse("$userDevicesApiUrl?email_id=$email"));
              if (dialogContext.mounted) {
                if (response.statusCode == 200) {
                  final result = json.decode(response.body);
                  dialogSetState(() {
                    deviceCategories = {
                      for (var key in result.keys)
                        if (key != 'device_id' && key != 'email_id')
                          key: List<String>.from(result[key] ?? [])
                    };
                  });
                } else {
                  _toast(
                      "Failed to load devices: Status ${response.statusCode}");
                }
              }
            } catch (e) {
              _toast("Error fetching devices: $e");
            }
            if (dialogContext.mounted) {
              dialogSetState(() => isLoadingDevices = false);
            }
          }

          if (isLoadingDevices) {
            _refreshDevices();
          }

          final isDark = Theme.of(context).brightness == Brightness.dark;
          final subtle = isDark ? Colors.white70 : Colors.black54;
          final strong = isDark ? Colors.white : Colors.black;

          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 400),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Devices for $email",
                          style: TextStyle(
                              color: strong,
                              fontSize: 16,
                              fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () async {
                              await DeleteDeviceUtils.deleteDevices(
                                dialogContext,
                                email,
                                deviceCategories,
                                (updatedCategories) {
                                  dialogSetState(() {
                                    deviceCategories = updatedCategories;
                                  });
                                },
                              );
                            },
                            tooltip: 'Delete Devices',
                          ),
                          IconButton(
                            icon: Icon(Icons.refresh, color: subtle),
                            onPressed: _refreshDevices,
                            tooltip: 'Refresh',
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: subtle),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Expanded(
                    child: isLoadingDevices
                        ? const Center(child: CircularProgressIndicator())
                        : deviceCategories.isEmpty
                            ? Center(
                                child: Text("No devices found",
                                    style: TextStyle(color: subtle)))
                            : ListView.builder(
                                itemCount: deviceCategories.keys.length,
                                itemBuilder: (ctx, index) {
                                  final category =
                                      deviceCategories.keys.elementAt(index);
                                  final devices = deviceCategories[category]!;
                                  return ExpansionTile(
                                    title: Text(
                                      category.trim(),
                                      style: TextStyle(
                                        color: strong,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    children: devices.map((device) {
                                      return ListTile(
                                        title: Text(
                                          '• $device',
                                          style: TextStyle(
                                              color: strong, fontSize: 14),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addDeviceToUser(String email, String deviceId) async {
    bool success = await DeviceUtils.addDeviceToUser(
      context: context,
      email: email,
      deviceId: deviceId,
      allDevices: allDevices,
    );

    if (success) {
      await _loadDeviceData();
    }
  }

  void _showAddDeviceDialog(String email) {
    final TextEditingController deviceIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text("Add Device to $email"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: deviceIdController,
                  decoration: const InputDecoration(
                    labelText: "Enter Device ID (e.g., CP001)",
                    border: OutlineInputBorder(),
                    helperText: "Use 2 uppercase letters + 3 digits",
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: deviceIdController.text.trim().isEmpty
                    ? null
                    : () {
                        final deviceId =
                            deviceIdController.text.trim().toUpperCase();
                        Navigator.pop(context);
                        _addDeviceToUser(email, deviceId);
                      },
                child: const Text("Add"),
              ),
            ],
          );
        },
      ),
    );
  }

  DateTime? parseDate(String? dateStr) {
    if (dateStr == null || dateStr == "N/A" || dateStr.isEmpty) return null;
    try {
      dateStr = dateStr.trim().replaceAll(RegExp(r'\s+'), ' ');

      final compactRegex = RegExp(r'^\d{8}T\d{6}$');
      if (compactRegex.hasMatch(dateStr)) {
        final y = int.parse(dateStr.substring(0, 4));
        final m = int.parse(dateStr.substring(4, 6));
        final d = int.parse(dateStr.substring(6, 8));
        final H = int.parse(dateStr.substring(9, 11));
        final M = int.parse(dateStr.substring(11, 13));
        final S = int.parse(dateStr.substring(13, 15));
        return DateTime(y, m, d, H, M, S);
      }

      final standardRegex = RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$');
      if (standardRegex.hasMatch(dateStr)) {
        return DateTime.parse(dateStr);
      }

      final customRegex = RegExp(r'^\d{2}-\d{2}-\d{4} \d{2}:\d{2}:\d{2}$');
      if (customRegex.hasMatch(dateStr)) {
        final parts = dateStr.split(' ');
        final dateParts = parts[0].split('-');
        final timeParts = parts[1].split(':');
        final d = int.parse(dateParts[0]);
        final m = int.parse(dateParts[1]);
        final y = int.parse(dateParts[2]);
        final H = int.parse(timeParts[0]);
        final M = int.parse(timeParts[1]);
        final S = int.parse(timeParts[2]);
        return DateTime(y, m, d, H, M, S);
      }
      return DateTime.tryParse(dateStr);
    } catch (e) {
      if (kDebugMode) {
        print("Failed to parse date: $dateStr, error: $e");
      }
      return null;
    }
  }

  List<Map<String, dynamic>> get filteredDevices {
    Iterable<Map<String, dynamic>> list = allDevices;
    if (filter == "Active") {
      list = list.where((d) => d['isActive'] == true);
    } else if (filter == "Inactive") {
      list = list.where((d) => d['isActive'] == false);
    }
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((d) =>
          d['DeviceId'].toString().toLowerCase().contains(q) ||
          d['group'].toString().toLowerCase().contains(q) ||
          d['Topic'].toString().toLowerCase().contains(q));
    }
    final sorted = list.toList()
      ..sort((a, b) {
        if (a['isActive'] == b['isActive']) {
          return a['DeviceId'].toString().compareTo(b['DeviceId'].toString());
        }
        return (a['isActive'] as bool) ? -1 : 1;
      });
    return sorted;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  ({String category, String prefix}) _mapCategoryAndPrefix(String topic) {
    if (topic == 'WS/Campus/2') {
      return (category: 'Sekhon Farm Sensor', prefix: 'CF');
    }
    if (topic.contains('WS/Campus')) {
      return (category: 'IIT Ropar Sensor', prefix: 'CP');
    }
    if (topic.contains('WS/SSMet/NARL')) {
      return (category: 'NARL Sensor', prefix: 'NA');
    }
    if (topic.contains('WS/SSMet/KJSCE')) {
      return (category: 'KJ Sensor', prefix: 'KJ');
    }
    if (topic.contains('WS/SSMet')) {
      return (category: 'SSMET Sensor', prefix: 'SM');
    }
    if (topic.contains('WS/SVPU')) {
      return (category: 'SVPU Sensor', prefix: 'SV');
    }
    if (topic.contains('WS/Mysuru')) {
      return (category: 'Mysuru NIE Sensor', prefix: 'MY');
    }
    if (topic.contains('WS/KARGIL')) {
      return (category: 'Kargil Sensor', prefix: 'KD');
    }
    if (topic.contains('IIT/WS')) {
      return (category: 'IIT Bombay Sensor', prefix: 'IT');
    }
    if (topic.contains('WS/Vanix')) {
      return (category: 'Vanix Sensor', prefix: 'VD');
    }
    return (category: 'Unknown Sensor', prefix: '');
  }

  Future<void> _deleteUser(String email) async {
    await DeleteDeviceUtils.deleteAccount(context, email, null);
    await fetchUsers();
  }

  @override
  Widget build(BuildContext context) {
    // ... Widget build method remains the same ...
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark
        ? [
            const Color.fromARGB(255, 4, 36, 49),
            const Color.fromARGB(255, 2, 54, 76),
          ]
        : [
            const Color.fromARGB(255, 191, 242, 237),
            const Color.fromARGB(255, 79, 106, 112),
          ];

    final card = isDark ? const Color(0xFF161A22) : Colors.white;
    final subtle = isDark ? Colors.white70 : Colors.black54;
    final strong = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bg.first,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: bg.first,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: strong),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Admin Dashboard',
          style: TextStyle(
            color: strong,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            fontSize: getResponsiveFontSize(context, 18, 26),
          ),
        ),
        actions: [
          if (kIsWeb)
            Stack(
              children: [
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: _showNotificationsDialog,
                  icon: Icon(Icons.notifications, color: strong),
                ),
                if (notifications.isNotEmpty)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${notifications.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          IconButton(
            tooltip: 'Refresh devices',
            onPressed: () {
              _loadDeviceData();
              fetchAnomalies();
            },
            icon: Icon(Icons.refresh, color: strong),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth <= 600;
          final statCrossAxisCount = isMobile ? 1 : 4;
          final statChildAspectRatio = isMobile ? 4.0 : 2.9;
          final padding = isMobile ? 12.0 : 18.0;

          return SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: Column(
              children: [
                GridView.count(
                  crossAxisCount: statCrossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: statChildAspectRatio,
                  children: [
                    _StatCard(
                      title: "Total Devices",
                      value: allDevices.length.toString(),
                      icon: Icons.devices,
                      iconBg: Colors.blue,
                      cardColor: card,
                      strong: strong,
                      subtle: subtle,
                    ),
                    _StatCard(
                      title: "Active",
                      value: totalActive.toString(),
                      icon: Icons.check_circle,
                      iconBg: Colors.green,
                      cardColor: card,
                      strong: strong,
                      subtle: subtle,
                    ),
                    _StatCard(
                      title: "Inactive",
                      value: totalInactive.toString(),
                      icon: Icons.cancel,
                      iconBg: Colors.red,
                      cardColor: card,
                      strong: strong,
                      subtle: subtle,
                    ),
                    _StatCard(
                      title: "Users",
                      value: users.length.toString(),
                      icon: Icons.people_alt,
                      iconBg: Colors.orange,
                      cardColor: card,
                      strong: strong,
                      subtle: subtle,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Column(
                  children: [
                    _SectionCard(
                      title: "Devices",
                      cardColor: card,
                      strong: strong,
                      subtle: subtle,
                      child: isLoading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : Column(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _SearchField(
                                      hint: "Search a device",
                                      strong: strong,
                                      subtle: subtle,
                                      isDark: isDark,
                                      onChanged: (value) {
                                        setState(() {
                                          searchQuery = value.trim();
                                          devicesToShow = 4;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        if (constraints.maxWidth < 600) {
                                          return Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              DropdownButton<String>(
                                                value: filter,
                                                items: [
                                                  "All",
                                                  "Active",
                                                  "Inactive"
                                                ]
                                                    .map((e) =>
                                                        DropdownMenuItem(
                                                            value: e,
                                                            child: Text(e)))
                                                    .toList(),
                                                onChanged: (v) {
                                                  if (v != null)
                                                    setState(() => filter = v);
                                                },
                                              ),
                                              IconButton(
                                                tooltip: "Refresh",
                                                onPressed: () {
                                                  _loadDeviceData();
                                                  fetchAnomalies();
                                                },
                                                icon: Icon(Icons.refresh,
                                                    color: strong),
                                              ),
                                            ],
                                          );
                                        } else {
                                          return Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              _ChipFilter(
                                                value: filter,
                                                onChanged: (v) =>
                                                    setState(() => filter = v),
                                                strong: strong,
                                                subtle: subtle,
                                                isDark: isDark,
                                              ),
                                              IconButton(
                                                tooltip: "Refresh",
                                                onPressed: () {
                                                  _loadDeviceData();
                                                  fetchAnomalies();
                                                },
                                                icon: Icon(Icons.refresh,
                                                    color: strong),
                                              ),
                                            ],
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                const Divider(height: 1),
                                const SizedBox(height: 8),
                                if (filteredDevices.isEmpty)
                                  Center(
                                    child: Text("No devices found",
                                        style: TextStyle(color: subtle)),
                                  )
                                else
                                  Column(
                                    children: [
                                      ...filteredDevices
                                          .take(devicesToShow)
                                          .map(
                                            (d) => Column(
                                              children: [
                                                InkWell(
                                                  hoverColor: isDark
                                                      ? const Color(0xFF2C3E50)
                                                          .withOpacity(0.6)
                                                      : const Color(0xFF5BAA9D)
                                                          .withOpacity(0.9),
                                                  onTap: () {
                                                    final deviceId =
                                                        d['DeviceId'] ??
                                                            "Unknown";
                                                    final topic =
                                                        d['Topic'] ?? "Unknown";
                                                    final mapped =
                                                        _mapCategoryAndPrefix(
                                                            topic);
                                                    final sensorName = mapped
                                                            .prefix.isNotEmpty
                                                        ? "${mapped.prefix}${deviceId.padLeft(3, '0')}"
                                                        : deviceId;
                                                    final sequentialName =
                                                        mapped.category;
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            DeviceGraphPage(
                                                          deviceName:
                                                              sensorName,
                                                          sequentialName:
                                                              sequentialName,
                                                          backgroundImagePath:
                                                              'assets/backgroundd.jpg',
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  child: ListTile(
                                                    leading: _StatusDot(
                                                      color:
                                                          d['isActive'] == true
                                                              ? Colors.green
                                                              : Colors.red,
                                                    ),
                                                    title: Text(
                                                      "ID: ${d['DeviceId'] != null && d['Topic'] != null ? (_mapCategoryAndPrefix(d['Topic']).prefix.isNotEmpty ? "${_mapCategoryAndPrefix(d['Topic']).prefix}${d['DeviceId'].padLeft(3, '0')}" : d['DeviceId']) : "Unknown"}",
                                                      style: TextStyle(
                                                        color: strong,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize:
                                                            getResponsiveFontSize(
                                                                context,
                                                                12,
                                                                14),
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    subtitle: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          "Name: ${d['Topic'] != null ? _mapCategoryAndPrefix(d['Topic']).category : "Unknown"}",
                                                          style: TextStyle(
                                                            color: subtle,
                                                            fontSize:
                                                                getResponsiveFontSize(
                                                                    context,
                                                                    10,
                                                                    14),
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        Text(
                                                          "Last: ${d['lastReceivedTime']}",
                                                          style: TextStyle(
                                                            color: subtle,
                                                            fontSize:
                                                                getResponsiveFontSize(
                                                                    context,
                                                                    10,
                                                                    14),
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                    trailing: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 10,
                                                          vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: (d['isActive'] ==
                                                                    true
                                                                ? Colors.green
                                                                : Colors.red)
                                                            .withOpacity(.12),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                      ),
                                                      child: Text(
                                                        d['isActive'] == true
                                                            ? "Active"
                                                            : "Inactive",
                                                        style: TextStyle(
                                                          color:
                                                              d['isActive'] ==
                                                                      true
                                                                  ? Colors.green
                                                                  : Colors.red,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Divider(
                                                    color: subtle
                                                        .withOpacity(.12)),
                                              ],
                                            ),
                                          ),
                                      if (devicesToShow <
                                          filteredDevices.length)
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              devicesToShow =
                                                  (devicesToShow + 4).clamp(0,
                                                      filteredDevices.length);
                                            });
                                          },
                                          child: const Text("Show More"),
                                        )
                                      else if (filteredDevices.length > 4)
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              devicesToShow = 4;
                                            });
                                          },
                                          child: const Text("Show Less"),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 18),
                    _SectionCard(
                      title: "User Accounts",
                      cardColor: card,
                      strong: strong,
                      subtle: subtle,
                      child: isUsersLoading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : users.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text("No users available",
                                          style: TextStyle(color: subtle)),
                                      const SizedBox(height: 8),
                                      ElevatedButton(
                                        onPressed: fetchUsers,
                                        child: const Text("Retry"),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  children: [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        "Total ${users.length}",
                                        style: TextStyle(color: subtle),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Divider(height: 1),
                                    const SizedBox(height: 8),
                                    Column(
                                      children: [
                                        ...users.take(usersToShow).map(
                                              (u) => Column(
                                                children: [
                                                  InkWell(
                                                    hoverColor: isDark
                                                        ? const Color(
                                                                0xFF2C3E50)
                                                            .withOpacity(0.6)
                                                        : const Color(
                                                                0xFF5BAA9D)
                                                            .withOpacity(0.9),
                                                    onTap: () =>
                                                        _showUserDevices(
                                                            u["email"]!),
                                                    child: ListTile(
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                        horizontal:
                                                            getResponsiveFontSize(
                                                                context, 8, 16),
                                                      ),
                                                      horizontalTitleGap:
                                                          getResponsiveFontSize(
                                                              context, 6, 16),
                                                      leading: CircleAvatar(
                                                        radius:
                                                            getResponsiveFontSize(
                                                                context,
                                                                12,
                                                                22),
                                                        backgroundColor: Colors
                                                            .blue
                                                            .withOpacity(.12),
                                                        child: Icon(
                                                          Icons.person,
                                                          color: Colors.blue,
                                                          size:
                                                              getResponsiveFontSize(
                                                                  context,
                                                                  14,
                                                                  24),
                                                        ),
                                                      ),
                                                      title: Text(
                                                        u["email"] ?? "",
                                                        style: TextStyle(
                                                          color: strong,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize:
                                                              getResponsiveFontSize(
                                                                  context,
                                                                  12,
                                                                  14),
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        maxLines: 2,
                                                      ),
                                                      trailing: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          IconButton(
                                                            tooltip:
                                                                "Add Device",
                                                            padding:
                                                                EdgeInsets.zero,
                                                            constraints:
                                                                const BoxConstraints(),
                                                            iconSize:
                                                                getResponsiveFontSize(
                                                                    context,
                                                                    14,
                                                                    28),
                                                            onPressed: () =>
                                                                _showAddDeviceDialog(
                                                                    u["email"]!),
                                                            icon: const Icon(
                                                                Icons.add,
                                                                color: Colors
                                                                    .blue),
                                                          ),
                                                          SizedBox(
                                                              width:
                                                                  getResponsiveFontSize(
                                                                      context,
                                                                      2,
                                                                      12)),
                                                          IconButton(
                                                            tooltip: "Delete",
                                                            padding:
                                                                EdgeInsets.zero,
                                                            constraints:
                                                                const BoxConstraints(),
                                                            iconSize:
                                                                getResponsiveFontSize(
                                                                    context,
                                                                    14,
                                                                    28),
                                                            onPressed: () =>
                                                                _deleteUser(u[
                                                                    "email"]!),
                                                            icon: const Icon(
                                                                Icons.delete,
                                                                color:
                                                                    Colors.red),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  Divider(
                                                      color: subtle
                                                          .withOpacity(.12)),
                                                ],
                                              ),
                                            ),
                                        if (usersToShow < users.length)
                                          TextButton(
                                            onPressed: () {
                                              setState(() {
                                                usersToShow = (usersToShow + 4)
                                                    .clamp(0, users.length);
                                              });
                                            },
                                            child: const Text("Show More"),
                                          )
                                        else if (users.length > 4)
                                          TextButton(
                                            onPressed: () {
                                              setState(() {
                                                usersToShow = 4;
                                              });
                                            },
                                            child: const Text("Show Less"),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconBg;
  final Color cardColor;
  final Color strong;
  final Color subtle;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.cardColor,
    required this.strong,
    required this.subtle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: cardColor,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: iconBg.withOpacity(.15),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconBg, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value,
                      style: TextStyle(
                          color: strong,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(title, style: TextStyle(color: subtle, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Color cardColor;
  final Color strong;
  final Color subtle;

  const _SectionCard({
    required this.title,
    required this.child,
    required this.cardColor,
    required this.strong,
    required this.subtle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: cardColor,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    color: strong, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChipFilter extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;
  final Color strong;
  final Color subtle;
  final bool isDark;

  const _ChipFilter({
    required this.value,
    required this.onChanged,
    required this.strong,
    required this.subtle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final options = ["All", "Active", "Inactive"];
    return Wrap(
      spacing: 8,
      children: options.map((opt) {
        final selected = value == opt;
        return ChoiceChip(
          label: Text(
            opt,
            style: TextStyle(
              color: selected ? Colors.white : strong,
              fontWeight: FontWeight.w600,
            ),
          ),
          selected: selected,
          selectedColor: opt == "Active"
              ? Colors.green
              : (opt == "Inactive" ? Colors.red : Colors.blue),
          backgroundColor:
              (isDark ? Colors.white10 : Colors.black12).withOpacity(.06),
          onSelected: (_) => onChanged(opt),
        );
      }).toList(),
    );
  }
}

class _SearchField extends StatelessWidget {
  final String hint;
  final void Function(String) onChanged;
  final Color strong;
  final Color subtle;
  final bool isDark;

  const _SearchField({
    required this.hint,
    required this.onChanged,
    required this.strong,
    required this.subtle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: TextStyle(color: strong),
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.search, color: subtle),
        hintText: hint,
        hintStyle: TextStyle(color: subtle),
        filled: true,
        fillColor: (isDark ? Colors.white10 : Colors.black12).withOpacity(.06),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: subtle.withOpacity(.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: subtle.withOpacity(.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary, width: 1.2),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  const _StatusDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(.35), blurRadius: 8, spreadRadius: 1)
        ],
      ),
    );
  }
}
