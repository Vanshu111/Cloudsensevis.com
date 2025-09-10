import 'dart:convert';
import 'package:cloud_sense_webapp/devicemap.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DeviceActivityPage extends StatefulWidget {
  const DeviceActivityPage({super.key});

  @override
  State<DeviceActivityPage> createState() => _DeviceActivityPageState();
}

class _DeviceActivityPageState extends State<DeviceActivityPage> {
  final String apiUrl =
      "https://xa9ry8sls0.execute-api.us-east-1.amazonaws.com/CloudSense_device_activity_api_function";

  bool isLoading = true;
  bool showList = true;
  List<Map<String, dynamic>> allDevices = [];
  int totalActive = 0;
  int totalInactive = 0;

  String? filter = "All";
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    fetchDevices();
  }

  Future<void> fetchDevices() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        List<Map<String, dynamic>> devices = [];

        final keysToInclude = [
          'WS_Device_Activity',
          'Awadh_Jio_Device_Activity',
          'weather_Device_Activity',
        ];

        for (var key in keysToInclude) {
          if (data[key] != null) {
            for (var device in data[key]) {
              DateTime? lastTime = parseDate(device['lastReceivedTime']);
              bool isActive = false;

              if (lastTime != null) {
                final diff = DateTime.now().difference(lastTime);
                isActive = diff.inHours <= 24;
              }

              devices.add({
                "DeviceId": device['DeviceId'],
                "lastReceivedTime": lastTime?.toString() ?? "Invalid date",
                "isActive": isActive,
                "Group": key,
                "Topic":
                    key == "WS_Device_Activity" ? device['Topic'] ?? "" : null
              });
            }
          }
        }
        devices.sort((a, b) {
          if (a['isActive'] == b['isActive']) return 0;
          return a['isActive'] ? -1 : 1;
        });

        int activeCount = devices.where((d) => d['isActive']).length;
        int inactiveCount = devices.length - activeCount;

        setState(() {
          allDevices = devices;
          totalActive = activeCount;
          totalInactive = inactiveCount;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  DateTime? parseDate(String dateStr) {
    try {
      final compactRegex = RegExp(r'^\d{8}T\d{6}$');
      if (compactRegex.hasMatch(dateStr)) {
        final year = int.parse(dateStr.substring(0, 4));
        final month = int.parse(dateStr.substring(4, 6));
        final day = int.parse(dateStr.substring(6, 8));
        final hour = int.parse(dateStr.substring(9, 11));
        final minute = int.parse(dateStr.substring(11, 13));
        final second = int.parse(dateStr.substring(13, 15));
        return DateTime(year, month, day, hour, minute, second);
      }

      final dmyRegex = RegExp(r'^\d{2}-\d{2}-\d{4} \d{2}:\d{2}:\d{2}$');
      if (dmyRegex.hasMatch(dateStr)) {
        final parts = dateStr.split(' ');
        final dateParts = parts[0].split('-');
        final timeParts = parts[1].split(':');

        final day = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]);
        final year = int.parse(dateParts[2]);
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final second = int.parse(timeParts[2]);

        return DateTime(year, month, day, hour, minute, second);
      }

      final amPmRegex = RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2} (AM|PM)$');
      if (amPmRegex.hasMatch(dateStr)) {
        final isPm = dateStr.endsWith('PM');
        final base = dateStr.replaceAll(RegExp(r' (AM|PM)$'), '');
        final dateTimeParts = base.split(' ');
        final date = dateTimeParts[0];
        final time = dateTimeParts[1];
        final dateParts = date.split('-');
        final timeParts = time.split(':');

        int hour = int.parse(timeParts[0]);
        if (isPm && hour < 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;

        return DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
          hour,
          int.parse(timeParts[1]),
        );
      }

      return DateTime.tryParse(dateStr.replaceAll('  ', ' '));
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> get filteredDevices {
    List<Map<String, dynamic>> filteredList = allDevices;

    if (filter == "Active") {
      filteredList = filteredList.where((d) => d['isActive']).toList();
    } else if (filter == "Inactive") {
      filteredList = filteredList.where((d) => !d['isActive']).toList();
    }

    if (searchQuery.isNotEmpty) {
      filteredList = filteredList
          .where((d) =>
              d['DeviceId'].toString().toLowerCase().contains(searchQuery) ||
              (d['Topic'] != null &&
                  d['Topic'].toString().toLowerCase().contains(searchQuery)))
          .toList();
    }

    return filteredList;
  }

  // ✅ Single clean dropdown widget
  Widget _buildDropdown(bool isDarkMode) {
    return Container(
      height: 48,
      width: 180,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<String>(
        isExpanded: true,
        dropdownColor:
            isDarkMode ? const Color.fromARGB(255, 92, 90, 90) : Colors.white70,
        hint: Text(
          "Select Device Type",
          style: TextStyle(
            color: isDarkMode ? Colors.black : Colors.white70,
          ),
        ),
        iconEnabledColor: isDarkMode ? Colors.white : Colors.black,
        iconDisabledColor: Colors.grey,
        value: filter,
        items: [
          DropdownMenuItem(
            value: "All",
            child: Text(
              "All Devices",
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),
          DropdownMenuItem(
            value: "Active",
            child: Text(
              "Active Devices",
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),
          DropdownMenuItem(
            value: "Inactive",
            child: Text(
              "Inactive Devices",
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
        onChanged: (value) {
          setState(() {
            if (value == "Clear") {
              filter = null;
              showList = false;
            } else if (value == filter) {
              showList = !showList;
            } else {
              filter = value;
              showList = true;
            }
          });
        },
        style: TextStyle(
          color: isDarkMode ? Colors.black : Colors.white,
        ),
      ),
    );
  }

  // ✅ Single clean search widget
  Widget _buildSearchField(bool isDarkMode) {
    return SizedBox(
      height: 48,
      width: 180,
      child: TextField(
        onChanged: (query) {
          setState(() {
            searchQuery = query.toLowerCase();
            showList = true;
          });
        },
        decoration: InputDecoration(
          hintText: "Search device...",
          hintStyle: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          filled: true,
          fillColor: isDarkMode ? Colors.grey[850] : Colors.grey[200],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 12,
          ),
        ),
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
          fontSize: 14,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0, // remove shadow
        scrolledUnderElevation:
            0, // NEW: disables the lighter overlay effect when scrolled
        surfaceTintColor: Colors.transparent, // prevents automatic tint
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
            onPressed: fetchDevices,
          ),
          IconButton(
            icon: Icon(
              Icons.map,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
            tooltip: 'Open Map',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DeviceMapScreen()),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode
                ? [
                    const Color.fromARGB(255, 4, 36, 49)!,
                    const Color.fromARGB(255, 2, 54, 76)!,
                  ]
                : [
                    const Color.fromARGB(255, 191, 242, 237)!,
                    const Color.fromARGB(255, 79, 106, 112)!,
                  ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: fetchDevices,
                child: Column(
                  children: [
                    Container(
                      color: Colors.transparent,
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Text(
                            "Total Devices: ${allDevices.length}",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Text(
                                "Active: $totalActive",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDarkMode
                                      ? Colors.green
                                      : const Color.fromARGB(255, 3, 71, 5),
                                ),
                              ),
                              Text(
                                "Inactive: $totalInactive",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ✅ LayoutBuilder for mobile/PC
                          LayoutBuilder(
                            builder: (context, constraints) {
                              bool isMobile = constraints.maxWidth < 600;

                              if (isMobile) {
                                // 📱 Mobile → Column
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _buildDropdown(isDarkMode),
                                    const SizedBox(height: 12),
                                    _buildSearchField(isDarkMode),
                                  ],
                                );
                              } else {
                                // 💻 PC → Row
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildDropdown(isDarkMode),
                                    const SizedBox(width: 12),
                                    _buildSearchField(isDarkMode),
                                  ],
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    Expanded(
                      child: (!showList || filter == null)
                          ? const Center()
                          : filteredDevices.isEmpty
                              ? const Center(child: Text("No devices found"))
                              : ListView.builder(
                                  itemCount: filteredDevices.length,
                                  itemBuilder: (context, index) {
                                    final device = filteredDevices[index];
                                    return _HoverableDeviceCard(
                                      isDarkMode: isDarkMode,
                                      device: device,
                                      onTap: () {
                                        Navigator.pushNamed(context, "/login");
                                      },
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _HoverableDeviceCard extends StatefulWidget {
  final bool isDarkMode;
  final Map<String, dynamic> device;
  final VoidCallback onTap;

  const _HoverableDeviceCard({
    required this.isDarkMode,
    required this.device,
    required this.onTap,
  });

  @override
  State<_HoverableDeviceCard> createState() => _HoverableDeviceCardState();
}

class _HoverableDeviceCardState extends State<_HoverableDeviceCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              colors: widget.isDarkMode
                  ? (_isHovering
                      ? [const Color(0xFF3B6A7F), const Color(0xFF8C6C8E)]
                      : [
                          const Color.fromARGB(255, 3, 62, 88),
                          const Color.fromARGB(227, 41, 36, 42)
                        ])
                  : (_isHovering
                      ? [const Color(0xFF5BAA9D), const Color(0xFFA7DCA1)]
                      : [
                          const Color.fromARGB(255, 188, 215, 215),
                          const Color.fromARGB(255, 158, 211, 212)
                        ]),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: _isHovering ? 8 : 4,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: ListTile(
            leading: Icon(
              Icons.devices,
              color: widget.device['isActive'] ? Colors.green : Colors.red,
            ),
            title: Text(
              "Device ID: ${widget.device['DeviceId']}",
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              "Last Received: ${widget.device['lastReceivedTime']}"
              "${widget.device['Topic'] != null && widget.device['Topic'] != '' ? '\nTopic: ${widget.device['Topic']}' : ''}",
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
