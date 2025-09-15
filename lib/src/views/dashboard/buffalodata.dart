import 'dart:io';
import 'dart:ui';
import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;

class BuffaloData extends StatefulWidget {
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String nodeId;

  BuffaloData({
    required this.startDateTime,
    required this.endDateTime,
    required this.nodeId,
  });

  @override
  _BuffaloDataState createState() => _BuffaloDataState();
}

class _BuffaloDataState extends State<BuffaloData> {
  List<dynamic> _data = [];
  bool _isLoading = true;
  late DateTime selectedStartDate;
  late DateTime selectedEndDate;
  bool _isHovering = false;

  String selectedNodeId = ''; // Store selected nodeId
  Map<String, int> _totalActivityTimes = {}; // Store total activity times
  TextEditingController nodeIdController =
      TextEditingController(); // Controller for Node ID

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedStartDate = now;
    selectedEndDate = now;
    selectedNodeId = widget.nodeId;
    print("BuffaloData initialized with:");
    print("Start Date: $selectedStartDate");
    print("End Date: $selectedEndDate");
    print("Node ID: $selectedNodeId");
    nodeIdController.text =
        selectedNodeId; // Set initial value of Node ID controller
    _fetchData();
  }

  Future<void> _fetchData() async {
    //Remove the "BF" prefix from the nodeId if it exists
    String nodeIdToUse = selectedNodeId
        .replaceFirst('BF', '')
        .trim(); // .trim() removes extra spaces

    // Convert DateTime to Unix timestamp (seconds since epoch)
    final startTime = selectedStartDate.millisecondsSinceEpoch ~/ 1000;
    final endTime = selectedEndDate.millisecondsSinceEpoch ~/ 1000;

    if (nodeIdToUse.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Node ID is empty or invalid.")),
      );
      return;
    }

    if (startTime == 0 || endTime == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invalid start or end time.")),
      );
      return;
    }

    // Construct the API URL dynamically
    final url =
        "https://mbr7azk167.execute-api.us-east-1.amazonaws.com/gateway_prediction_data_fetch_2?nodeId=$nodeIdToUse&startTime=$startTime&endTime=$endTime";

    try {
      final response = await http.get(Uri.parse(url));

      // Check if the response is successful (status code 200)
      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);

        // Reset activity times before processing new data
        _totalActivityTimes.clear();
        Map<String, int> lastTimestamps =
            {}; // Store the last timestamp for each activity

        // Group activities and calculate total time for each ActivityLabel
        for (int i = 0; i < responseData.length; i++) {
          final activity = responseData[i];
          final activityLabel = activity['ActivityLabel'];
          final timestamp = int.parse(activity['TimeStamp'].toString());

          // If this is not the first timestamp, calculate the time difference
          if (lastTimestamps.containsKey(activityLabel)) {
            final lastTimestamp = lastTimestamps[activityLabel]!;
            final duration =
                timestamp - lastTimestamp; // Time difference in seconds
            _totalActivityTimes.update(
              activityLabel,
              (value) => value + duration,
              ifAbsent: () => duration,
            );
          }

          // Update the last timestamp for this activity
          lastTimestamps[activityLabel] = timestamp;
        }

        setState(() {
          _data = responseData;
          _isLoading = false;
        });
      } else {
        throw Exception("Failed to load data");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

// Method to group activities by label and time difference (3 hours)
  List<List<dynamic>> _groupActivitiesByLabelAndTime(List<dynamic> data) {
    List<List<dynamic>> groupedActivities = [];
    List<dynamic> currentGroup = [];

    for (int i = 0; i < data.length; i++) {
      final activity = data[i];
      final activityLabel = activity['ActivityLabel'];
      final timestamp = int.parse(activity['TimeStamp'].toString());

      if (currentGroup.isEmpty) {
        currentGroup.add(activity);
      } else {
        final lastActivity = currentGroup.last;
        final lastTimestamp = int.parse(lastActivity['TimeStamp'].toString());
        final timeDifference = timestamp - lastTimestamp;

        if (activityLabel == lastActivity['ActivityLabel'] &&
            timeDifference <= 10800) {
          currentGroup.add(activity);
        } else {
          groupedActivities.add(currentGroup);
          currentGroup = [activity];
        }
      }
    }

    if (currentGroup.isNotEmpty) {
      groupedActivities.add(currentGroup);
    }

    return groupedActivities;
  }

  Future<void> _downloadCSV() async {
    try {
      // Group activities by label and time
      final groupedActivities = _groupActivitiesByLabelAndTime(_data);

      // Check if there is data to export
      if (groupedActivities.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No data available to download.")),
        );
        return; // Exit the function early if no data is available
      }

      // Define the column names
      List<String> columnNames = ['TimeStamp Range', 'Activity Label'];

      // Prepare rows for CSV
      List<List<String>> csvRows = [];
      csvRows.add(columnNames); // Add headers

      for (var group in groupedActivities) {
        if (group.isNotEmpty) {
          final startTimestamp = int.parse(group.first['TimeStamp'].toString());
          final endTimestamp = int.parse(group.last['TimeStamp'].toString());
          final activityLabel = group.first['ActivityLabel'];

          // Convert timestamps to readable format
          final startTime =
              DateTime.fromMillisecondsSinceEpoch(startTimestamp * 1000);
          final endTime =
              DateTime.fromMillisecondsSinceEpoch(endTimestamp * 1000);

          String timeRange =
              "${startTime.toIso8601String()} - ${endTime.toIso8601String()}";

          csvRows.add([timeRange, activityLabel]);
        }
      }

      // Convert rows to CSV
      String csvData = const ListToCsvConverter().convert(csvRows);

      String fileName = _generateFileName(); // Generate unique filename

      if (kIsWeb) {
        // Web-specific logic
        final blob = html.Blob([csvData], 'text/csv');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);

        // Show Snackbar and clean up
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Downloading $fileName"),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        // Non-web platforms
        await saveCSVFile(csvData, fileName);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error generating CSV: $e")),
      );
    }
  }

  String _generateFileName() {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return 'GroupedActivities_$timestamp.csv';
  }

  Future<void> saveCSVFile(String csvData, String fileName) async {
    try {
      // Get the Downloads directory.
      final downloadsDirectory = Directory('/storage/emulated/0/Download');
      if (downloadsDirectory.existsSync()) {
        final filePath = '${downloadsDirectory.path}/$fileName';
        final file = File(filePath);

        // Write the CSV data to the file.
        await file.writeAsString(csvData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("File downloaded to $filePath")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unable to find Downloads directory")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving file: $e")),
      );
    }
  }

// Method to show the date and time picker for the start and end dates
  Future<void> _pickDateTime(bool isStartDate) async {
    DateTime initialDate = isStartDate ? selectedStartDate : selectedEndDate;
    DateTime pickedDateTime = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2101),
        ) ??
        initialDate;

    TimeOfDay initialTime = TimeOfDay.fromDateTime(initialDate);
    TimeOfDay pickedTime = await showTimePicker(
          context: context,
          initialTime: initialTime,
        ) ??
        initialTime;

    // Combine selected date and time
    DateTime finalDateTime = DateTime(
      pickedDateTime.year,
      pickedDateTime.month,
      pickedDateTime.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      if (isStartDate) {
        selectedStartDate = finalDateTime;
      } else {
        selectedEndDate = finalDateTime;
      }
    });
  }

  List<PieChartSectionData> generatePieChartData(Map<String, int> data) {
    List<PieChartSectionData> sections = [];

    if (data.isEmpty) {
      return sections; // Return an empty list if there's no data
    }

    int total = data.values.reduce((a, b) => a + b);

    // Calculate the percentage for each activity
    List<double> percentages = [];
    data.forEach((activityLabel, totalTime) {
      double percentage = (totalTime / total) * 100;
      percentages.add(percentage);
    });

    // Round each percentage to 2 decimal places
    percentages = percentages
        .map((percentage) => double.parse(percentage.toStringAsFixed(2)))
        .toList();

    // Adjust the last percentage to make the total exactly 100
    double sum = percentages.reduce((a, b) => a + b);
    double adjustment = 100 - sum;
    if (percentages.isNotEmpty) {
      // Add the remaining adjustment to the last item
      percentages[percentages.length - 1] += adjustment;
    }

    // Create PieChartSectionData from adjusted percentages
    int index = 0;
    data.forEach((activityLabel, totalTime) {
      double percentage = percentages[index];
      sections.add(
        PieChartSectionData(
          value: percentage,
          title: percentage >= 0.05 ? '$activityLabel' : '',
          color: getFixedColor(index),
          titleStyle: TextStyle(fontSize: 10),
          titlePositionPercentageOffset: 0.55,
        ),
      );
      index++;
    });

    return sections;
  }

  List<LegendItem> generateLegendData(Map<String, int> data) {
    List<LegendItem> legendData = [];

    if (data.isEmpty) {
      return legendData; // Return an empty list if there's no data
    }

    int total = data.values.reduce((a, b) => a + b);

    // Calculate the percentage for each activity
    List<double> percentages = [];
    data.forEach((activityLabel, totalTime) {
      double percentage = (totalTime / total) * 100;
      percentages.add(percentage);
    });

    // Round each percentage to 2 decimal places
    percentages = percentages
        .map((percentage) => double.parse(percentage.toStringAsFixed(2)))
        .toList();

    // Adjust the last percentage to make the total exactly 100
    double sum = percentages.reduce((a, b) => a + b);
    double adjustment = 100 - sum;
    if (percentages.isNotEmpty) {
      // Add the remaining adjustment to the last item
      percentages[percentages.length - 1] += adjustment;
    }

    // Create LegendItems from adjusted percentages
    int index = 0;
    data.forEach((activityLabel, totalTime) {
      double percentage = percentages[index];
      legendData.add(
        LegendItem(
          label: '$activityLabel - ${percentage.toStringAsFixed(2)}%',
          color: getFixedColor(index),
        ),
      );
      index++;
    });

    return legendData;
  }

  // Define fixed colors for each activity
  List<Color> fixedColors = [
    Colors.red,
    Colors.green,
    Colors.blue,
    Color.fromARGB(255, 203, 235, 27),
    Color.fromARGB(255, 174, 24, 74),
  ];

  Color getFixedColor(int index) {
    return fixedColors[index % fixedColors.length];
  }

  @override
  Widget build(BuildContext context) {
    // Prepare data for the table with activity time calculation
    final activityTimeData = _totalActivityTimes.entries
        .map((entry) =>
            ActivityTimeData(label: entry.key, totalTime: entry.value))
        .toList();

    final pieChartData = generatePieChartData(_totalActivityTimes);
    final legendData = generateLegendData(_totalActivityTimes);
    // Group activities
    final groupedActivities = _groupActivitiesByLabelAndTime(_data);

    return Scaffold(
      // Use Stack to overlay the AppBar and Body
      body: Stack(
        children: [
          // Background image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/buffalo_.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(
                color: Colors.black
                    .withOpacity(0.4), // Optional overlay for readability
              ),
            ),
          ),
          // Loading indicator or main content
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(),
            )
          else
            // Body content
            Column(
              children: [
                // Transparent AppBar
                AppBar(
                  title: Text(
                    ("Buffalo Data"),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize:
                          MediaQuery.of(context).size.width < 800 ? 18 : 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  backgroundColor: Colors.transparent,
                  elevation: 0, // Remove shadow of the AppBar
                  actions: [],
                ),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // NodeId, Start Date, and End Date input fields with LayoutBuilder
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // Check if the screen width is less than 800 pixels
                              if (constraints.maxWidth < 800) {
                                // If screen is smaller, display Node ID vertically and Start/End Date in a row
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Node ID field aligned to the left
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text("Node ID (Buffalo ID)",
                                              style: TextStyle(fontSize: 16)),
                                          SizedBox(height: 8),
                                          Container(
                                            width: double.infinity,
                                            child: TextField(
                                              controller: nodeIdController,
                                              onChanged: (value) {
                                                setState(() {
                                                  selectedNodeId = value;
                                                });
                                              },
                                              decoration: InputDecoration(
                                                hintText: "Enter Node ID",
                                                hintStyle: TextStyle(
                                                    color: Color.fromARGB(
                                                        255, 199, 196, 196),
                                                    fontSize: 12),
                                                border: InputBorder
                                                    .none, // Removes the underline
                                                labelStyle: TextStyle(
                                                  color: Theme.of(context)
                                                              .brightness ==
                                                          Brightness.dark
                                                      ? Colors.white
                                                      : Colors.black,
                                                ),
                                              ),
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                            .brightness ==
                                                        Brightness.dark
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Row for Start Date and End Date
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 16.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          // Start Date & Time
                                          Column(
                                            children: [
                                              Text("Start Date & Time",
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                  )),
                                              SizedBox(height: 8),
                                              ElevatedButton(
                                                onPressed: () async {
                                                  await _pickDateTime(true);
                                                },
                                                style: TextButton.styleFrom(
                                                    backgroundColor: Colors
                                                        .white
                                                        .withOpacity(0.6)),
                                                child: Text(
                                                  "${selectedStartDate.toLocal()}"
                                                          .split(' ')[0] +
                                                      " ${selectedStartDate.hour}:${selectedStartDate.minute}",
                                                  style: TextStyle(
                                                    color: Theme.of(context)
                                                                .brightness ==
                                                            Brightness.dark
                                                        ? const Color.fromARGB(
                                                            255, 22, 3, 127)
                                                        : null,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          // End Date & Time
                                          Column(
                                            children: [
                                              Text("End Date & Time",
                                                  style:
                                                      TextStyle(fontSize: 16)),
                                              SizedBox(height: 8),
                                              ElevatedButton(
                                                onPressed: () async {
                                                  await _pickDateTime(false);
                                                },
                                                style: TextButton.styleFrom(
                                                  backgroundColor: Colors.white
                                                      .withOpacity(0.6),
                                                ),
                                                child: Text(
                                                  "${selectedEndDate.toLocal()}"
                                                          .split(' ')[0] +
                                                      " ${selectedEndDate.hour}:${selectedEndDate.minute}",
                                                  style: TextStyle(
                                                    color: Theme.of(context)
                                                                .brightness ==
                                                            Brightness.dark
                                                        ? const Color.fromARGB(
                                                            255, 22, 3, 127)
                                                        : null,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    Center(
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(top: 16.0),
                                        child: ElevatedButton(
                                          onPressed: _fetchData,
                                          child: Text(
                                            "Fetch Data",
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? const Color.fromARGB(
                                                      255, 22, 3, 127)
                                                  : null,
                                            ),
                                          ),
                                          style: TextButton.styleFrom(
                                              backgroundColor: Colors.white
                                                  .withOpacity(0.6)),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              } else {
                                // If screen is larger, display inputs in a row
                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    // Node ID field
                                    Column(
                                      children: [
                                        Text("Node ID (Buffalo ID)",
                                            style: TextStyle(fontSize: 16)),
                                        SizedBox(height: 8),
                                        Container(
                                          width: 100,
                                          child: TextField(
                                            controller: nodeIdController,
                                            onChanged: (value) {
                                              setState(() {
                                                selectedNodeId = value;
                                              });
                                            },
                                            decoration: InputDecoration(
                                              hintText: "Enter Node ID",
                                              hintStyle: TextStyle(
                                                  color: Color.fromARGB(
                                                      255, 199, 196, 196),
                                                  fontSize: 12),
                                              border: InputBorder.none,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Start Date & Time
                                    Column(
                                      children: [
                                        Text("Start Date & Time",
                                            style: TextStyle(fontSize: 16)),
                                        SizedBox(height: 8),
                                        ElevatedButton(
                                          onPressed: () async {
                                            await _pickDateTime(true);
                                          },
                                          style: TextButton.styleFrom(
                                              backgroundColor: Colors.white
                                                  .withOpacity(0.6)),
                                          child: Text(
                                            "${selectedStartDate.toLocal()}"
                                                    .split(' ')[0] +
                                                " ${selectedStartDate.hour}:${selectedStartDate.minute}",
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? const Color.fromARGB(
                                                      255, 22, 3, 127)
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    // End Date & Time
                                    Column(
                                      children: [
                                        Text("End Date & Time",
                                            style: TextStyle(fontSize: 16)),
                                        SizedBox(height: 8),
                                        ElevatedButton(
                                          onPressed: () async {
                                            await _pickDateTime(false);
                                          },
                                          style: TextButton.styleFrom(
                                              backgroundColor: Colors.white
                                                  .withOpacity(0.6)),
                                          child: Text(
                                            "${selectedEndDate.toLocal()}"
                                                    .split(' ')[0] +
                                                " ${selectedEndDate.hour}:${selectedEndDate.minute}",
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? const Color.fromARGB(
                                                      255, 22, 3, 127)
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 16.0),
                                      child: ElevatedButton(
                                        onPressed: _fetchData,
                                        child: Text(
                                          "Fetch Data",
                                          style: TextStyle(
                                            color:
                                                Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? const Color.fromARGB(
                                                        255, 22, 3, 127)
                                                    : null,
                                          ),
                                        ),
                                        style: TextButton.styleFrom(
                                            backgroundColor:
                                                Colors.white.withOpacity(0.6)),
                                      ),
                                    ),
                                  ],
                                );
                              }
                            },
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Center(
                            // Center the entire column
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                  maxWidth:
                                      300), // Limit max width of the table
                              child: Column(
                                children: [
                                  // Heading Text centered above the table
                                  Center(
                                    child: Text(
                                      'Buffalo Activity Data',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 16),

                                  // Using Table widget for better control over header styling
                                  Table(
                                    border: TableBorder.all(
                                      color: Colors.white,
                                      style: BorderStyle.solid,
                                      width: 2,
                                    ),
                                    children: [
                                      // Header Row with background color
                                      TableRow(
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                        ),
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Center(
                                              // Center the "Activity" header
                                              child: Text(
                                                "Activity",
                                                style: TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Center(
                                              // Center the "Total Time (hrs)" header
                                              child: Text(
                                                "Total Time (hrs)",
                                                style: TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Data Rows
                                      ...activityTimeData.map((item) {
                                        return TableRow(
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Text(
                                                item.label,
                                                style: TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Text(
                                                "${(item.totalTime ~/ 3600).toString().padLeft(2, '0')} hr "
                                                "${((item.totalTime % 3600) ~/ 60).toString().padLeft(2, '0')} min "
                                                "${(item.totalTime % 60).toString().padLeft(2, '0')} sec",
                                                style: TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment
                                .center, // Center align the content
                            crossAxisAlignment: CrossAxisAlignment
                                .center, // Align children to the center
                            children: [
                              // Pie Chart Section
                              SizedBox(
                                height: 220,
                                width: MediaQuery.of(context).size.width > 600
                                    ? MediaQuery.of(context).size.width * 0.4
                                    : MediaQuery.of(context).size.width * 0.62,
                                child: PieChart(
                                  PieChartData(
                                    sections: generatePieChartData(
                                        _totalActivityTimes),
                                    borderData: FlBorderData(show: false),
                                    sectionsSpace: 0,
                                    centerSpaceRadius: 40,
                                    centerSpaceColor:
                                        Colors.white.withOpacity(0.4),
                                  ),
                                ),
                              ),
                              // Add horizontal spacing between pie chart and legend
                              SizedBox(
                                width: MediaQuery.of(context).size.width > 600
                                    ? 10
                                    : 16,
                              ),
                              // Legend Section
                              SizedBox(
                                width: MediaQuery.of(context).size.width > 600
                                    ? MediaQuery.of(context).size.width * 0.3
                                    : MediaQuery.of(context).size.width * 0.25,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children:
                                      generateLegendData(_totalActivityTimes)
                                          .map(
                                            (legendItem) => Padding(
                                              padding: EdgeInsets.only(
                                                bottom: MediaQuery.of(context)
                                                            .size
                                                            .width >
                                                        600
                                                    ? 4.0
                                                    : 8.0,
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 16,
                                                    height: 16,
                                                    color: legendItem.color,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Expanded(
                                                    // Ensures text wraps to the next line if necessary
                                                    child: Text(
                                                      legendItem.label,
                                                      style: TextStyle(
                                                          color: Colors.white),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                          .toList(),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 10),
                        groupedActivities.isNotEmpty
                            ? SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  border: TableBorder.all(
                                    color: Colors.white,
                                    style: BorderStyle.solid,
                                    width: 2,
                                  ),
                                  headingRowColor:
                                      WidgetStateProperty.all(Colors.blue),
                                  columns: const <DataColumn>[
                                    DataColumn(
                                      label: Center(
                                        child: Text('Start Time',
                                            style:
                                                TextStyle(color: Colors.white)),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Center(
                                        child: Text('End Time',
                                            style:
                                                TextStyle(color: Colors.white)),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Center(
                                        child: Text('Activity Label',
                                            style:
                                                TextStyle(color: Colors.white)),
                                      ),
                                    ),
                                  ],
                                  rows: groupedActivities.map((group) {
                                    DateTime startTime =
                                        DateTime.fromMillisecondsSinceEpoch(
                                            int.parse(group[0]['TimeStamp']
                                                    .toString()) *
                                                1000);
                                    DateTime endTime =
                                        DateTime.fromMillisecondsSinceEpoch(
                                            int.parse(group.last['TimeStamp']
                                                    .toString()) *
                                                1000);
                                    String activityLabel =
                                        group[0]['ActivityLabel'];

                                    return DataRow(cells: [
                                      DataCell(
                                        Container(
                                          width: 180,
                                          alignment: Alignment.center,
                                          child: Text(
                                            startTime.toLocal().toString(),
                                            style:
                                                TextStyle(color: Colors.white),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          width: 180,
                                          alignment: Alignment.center,
                                          child: Text(
                                            endTime.toLocal().toString(),
                                            style:
                                                TextStyle(color: Colors.white),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          width: 180,
                                          alignment: Alignment.center,
                                          child: Text(
                                            activityLabel,
                                            style:
                                                TextStyle(color: Colors.white),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ]);
                                  }).toList(),
                                ),
                              )
                            : Center(
                                child: Text(
                                  "",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 16),
                                ),
                              ),
                        SizedBox(height: 66),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          Positioned(
            bottom: 16,
            right: 16, // Extreme right position
            child: MouseRegion(
              onEnter: (_) => setState(() => _isHovering = true),
              onExit: (_) => setState(() => _isHovering = false),
              child: ElevatedButton(
                onPressed: _downloadCSV,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color.fromARGB(255, 40, 41, 41),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.download,
                      color: _isHovering ? Colors.blue : Colors.white,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Download CSV',
                      style: TextStyle(
                        color: _isHovering ? Colors.blue : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Data model for activity time calculation
class ActivityTimeData {
  final String label;
  final int totalTime;

  ActivityTimeData({required this.label, required this.totalTime});
}

class LegendItem {
  final String label;
  final Color color;

  LegendItem({required this.label, required this.color});
}
