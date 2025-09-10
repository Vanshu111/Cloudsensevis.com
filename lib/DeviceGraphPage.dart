import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cloud_sense_webapp/downloadcsv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import 'package:intl/intl.dart';
import 'dart:async';

// Updated CompassNeedlePainter with corrected arrowhead positioning
class CompassNeedlePainter extends CustomPainter {
  CompassNeedlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Define the needle length (60% of radius as per your code)
    final needleLength = radius * 0.4;

    // Paint for the red tip (pointing to wind direction, initially pointing up/North)
    final redPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    // Paint for the white tail (opposite direction)
    final whitePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    // Paint for the red arrowhead (filled triangle)
    final arrowPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    // Draw the red tip (from center to North, will be rotated by Transform.rotate)
    final tipX = center.dx;
    final tipY = center.dy - needleLength; // Pointing up (North)
    canvas.drawLine(center, Offset(tipX, tipY), redPaint);

    // Draw the white tail (from center to South)
    final tailX = center.dx;
    final tailY = center.dy + needleLength; // Pointing down (South)
    canvas.drawLine(center, Offset(tailX, tailY), whitePaint);

    // Draw the arrowhead at the tip of the red line
    final arrowSize = 8.0; // Width of the arrowhead base
    final arrowHeight = 10.0; // Height of the arrowhead (from base to tip)
    final arrowPath = Path();

    final baseLeft = Offset(tipX - arrowSize / 2, tipY); // Left base point
    final baseRight = Offset(tipX + arrowSize / 2, tipY); // Right base point
    // The tip of the arrowhead extends further in the direction of the red line (upward)
    final arrowTip = Offset(
        tipX, tipY - arrowHeight); // Tip of the arrowhead (further North)
    arrowPath.moveTo(arrowTip.dx, arrowTip.dy); // Tip of the arrow
    arrowPath.lineTo(baseLeft.dx, baseLeft.dy); // Left base
    arrowPath.lineTo(baseRight.dx, baseRight.dy); // Right base
    arrowPath.close(); // Close the triangle
    canvas.drawPath(arrowPath, arrowPaint);

    // Draw a small circle at the center to cover the intersection
    final centerPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 5, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CompassBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final gradientPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.black.withOpacity(0.7), Colors.black.withOpacity(0.5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, gradientPaint);

    final innerCirclePaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.8, innerCirclePaint);

    final tickPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    final tickLength = 8.0;
    for (int i = 0; i < 360; i += 30) {
      final angle = i * math.pi / 180;
      final startX = center.dx + (radius - tickLength) * math.sin(angle);
      final startY = center.dy - (radius - tickLength) * math.cos(angle);
      final endX = center.dx + radius * math.sin(angle);
      final endY = center.dy - radius * math.cos(angle);
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), tickPaint);
    }

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// DeviceStatus class to hold device data
class DeviceStatus {
  final String deviceId;
  final String lastReceivedTime;
  final double? latitude;
  final double? longitude;
  final String activityType; // e.g., chloritrone, WS, weather, water, Awadh_Jio

  DeviceStatus({
    required this.deviceId,
    required this.lastReceivedTime,
    this.latitude,
    this.longitude,
    required this.activityType,
  });
}

class DeviceGraphPage extends StatefulWidget {
  final String deviceName;
  final sequentialName;

  DeviceGraphPage(
      {required this.deviceName,
      required this.sequentialName,
      required String backgroundImagePath});
  @override
  _DeviceGraphPageState createState() => _DeviceGraphPageState();
}

class _DeviceGraphPageState extends State<DeviceGraphPage>
    with SingleTickerProviderStateMixin {
  // Mobile menu button builder
  Widget _buildMobileMenuButton(
    String title,
    String value,
    IconData icon,
    bool isDarkMode,
    BuildContext context, {
    required VoidCallback onPressed,
  }) {
    bool isActive = _activeButton == value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10), // smaller height
          backgroundColor: isActive
              ? (isDarkMode ? Colors.blue[700] : Colors.blue[600])
              : (isDarkMode ? Colors.grey[850] : Colors.grey[200]),
          foregroundColor: isActive
              ? Colors.white
              : (isDarkMode ? Colors.white70 : Colors.black87),
          elevation: isActive ? 3 : 0,
          minimumSize: const Size(0, 40), // compact height
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isActive) const Icon(Icons.check_circle, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(bool isDarkMode, BuildContext context) {
    final String prefix = _getPrefix(widget.deviceName);
    final String idStr = widget.deviceName.substring(prefix.length);
    final int? targetIdNum = int.tryParse(idStr);
    final filteredDevices = _deviceStatuses.where((device) {
      final int? deviceIdNum = int.tryParse(device.deviceId);
      return device.activityType == prefix && deviceIdNum == targetIdNum;
    }).toList();

    return Drawer(
      child: Container(
        color: isDarkMode ? Colors.blueGrey[900] : Colors.grey[200],
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[200] : Colors.blueGrey[900],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: isDarkMode ? Colors.red[300] : Colors.red[700],
                        fontSize: 14,
                      ),
                    )
                  else
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredDevices.length,
                        itemBuilder: (context, index) {
                          final device = filteredDevices[index];
                          final bool hasValidCoordinates =
                              device.latitude != null &&
                                  device.longitude != null &&
                                  device.latitude != 0 &&
                                  device.longitude != 0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Last Active: ${device.lastReceivedTime}',
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.black87
                                        : Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                if (hasValidCoordinates) ...[
                                  Text(
                                    'Latitude: ${device.latitude!.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.black87
                                          : Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'Longitude: ${device.longitude!.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.black87
                                          : Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Select Time Period',
                    style: TextStyle(
                      color: isDarkMode ? Colors.black : Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            _buildMobileMenuButton(
              '1 Day : ${DateFormat('dd-MM-yyyy').format(_selectedDay)}',
              'date',
              Icons.today,
              isDarkMode,
              context,
              onPressed: () async {
                await _selectDate();
                _reloadData(range: '1day');
                setState(() => _activeButton = 'date');
                Navigator.pop(context);
              },
            ),
            _buildMobileMenuButton(
              'Last 7 Days',
              '7days',
              Icons.calendar_view_week,
              isDarkMode,
              context,
              onPressed: () {
                _reloadData(range: '7days');
                _fetchDataForRange('7days');
                setState(() => _activeButton = '7days');
                Navigator.pop(context);
              },
            ),
            _buildMobileMenuButton(
              'Last 30 Days',
              '30days',
              Icons.calendar_view_month,
              isDarkMode,
              context,
              onPressed: () {
                _reloadData(range: '30days');
                _fetchDataForRange('30days');
                setState(() => _activeButton = '30days');
                Navigator.pop(context);
              },
            ),
            _buildMobileMenuButton(
              'Last 3 Months',
              '3months',
              Icons.calendar_today,
              isDarkMode,
              context,
              onPressed: () {
                _reloadData(range: '3months');
                _fetchDataForRange('3months');
                setState(() => _activeButton = '3months');
                Navigator.pop(context);
              },
            ),
            _buildMobileMenuButton(
              'Last 1 Year',
              '1year',
              Icons.date_range,
              isDarkMode,
              context,
              onPressed: () {
                _reloadData(range: '1year');
                _fetchDataForRange('1year');
                setState(() => _activeButton = '1year');
                Navigator.pop(context);
              },
            ),
            Padding(
              padding: EdgeInsets.only(
                  top: MediaQuery.of(context).size.height * 0.07),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.deviceName.startsWith('WQ'))
                    _buildMinMaxTable(
                      isDarkMode,
                      {
                        'temp': tempData,
                        'TDS': tdsData,
                        'COD': codData,
                        'BOD': bodData,
                        'pH': pHData,
                        'DO': doData,
                        'EC': ecData,
                      },
                    ),
                  if (widget.deviceName.startsWith('FS'))
                    _buildMinMaxTable(
                      isDarkMode,
                      {
                        'Temperature': fstempData,
                        'Pressure': fspressureData,
                        'Humidity': fshumidityData,
                        'Rainfall': fsrainData,
                        'Radiation': fsradiationData,
                        'Wind Speed': fswindspeedData,
                        'Wind Direction': fswinddirectionData,
                      },
                    ),
                  if (widget.deviceName.startsWith('CB'))
                    _buildMinMaxTable(
                      isDarkMode,
                      {
                        'temp': temp2Data,
                        'COD': cod2Data,
                        'BOD': bod2Data,
                      },
                    ),
                  if (widget.deviceName.startsWith('NH'))
                    _buildMinMaxTable(
                      isDarkMode,
                      {
                        'AMMONIA': ammoniaData,
                        'TEMP': temperaturedata,
                        'HUMIDITY': humiditydata,
                      },
                    ),
                  if (widget.deviceName.startsWith('DO'))
                    _buildMinMaxTable(
                      isDarkMode,
                      {
                        'Temperature': ttempData,
                        'DO Value': dovaluedata,
                        'DO Percentage': dopercentagedata,
                      },
                    ),
                  if (widget.deviceName.startsWith('NA'))
                    _buildMinMaxTable(
                      isDarkMode,
                      {
                        'Temperature':
                            NARLParametersData['CurrentTemperature'] ?? [],
                        'Humidity': NARLParametersData['CurrentHumidity'] ?? [],
                        'Light Intensity':
                            NARLParametersData['LightIntensity'] ?? [],
                        'Wind Speed': NARLParametersData['WindSpeed'] ?? [],
                        'Atm Pressure': NARLParametersData['AtmPressure'] ?? [],
                        'Wind Direction':
                            NARLParametersData['WindDirection'] ?? [],
                        'Rainfall': NARLParametersData['RainfallHourly'] ?? [],
                      },
                    ),
                  if (widget.deviceName.startsWith('VD'))
                    _buildMinMaxTable(
                      isDarkMode,
                      {
                        'Temperature':
                            vdParametersData['CurrentTemperature'] ?? [],
                        'Humidity': vdParametersData['CurrentHumidity'] ?? [],
                        'Light Intensity':
                            vdParametersData['LightIntensity'] ?? [],
                        'Rainfall': vdParametersData['RainfallHourly'] ?? [],
                      },
                    ),
                  if (widget.deviceName.startsWith('CP'))
                    _buildMinMaxTable(
                      isDarkMode,
                      {
                        'Temperature':
                            csParametersData['CurrentTemperature'] ?? [],
                        'Humidity': csParametersData['CurrentHumidity'] ?? [],
                        'Light Intensity':
                            csParametersData['LightIntensity'] ?? [],
                        'Rainfall': csParametersData['RainfallHourly'] ?? [],
                        'Wind Speed': csParametersData['WindSpeed'] ?? [],
                        'Atm Pressure': csParametersData['AtmPressure'] ?? [],
                        'Wind Direction':
                            csParametersData['WindDirection'] ?? [],
                      },
                    ),
                  if (widget.deviceName.startsWith('CF'))
                    _buildMinMaxTable(
                      isDarkMode,
                      {
                        'Temperature':
                            cfParametersData['CurrentTemperature'] ?? [],
                        'Humidity': cfParametersData['CurrentHumidity'] ?? [],
                        'Light Intensity':
                            cfParametersData['LightIntensity'] ?? [],
                        'Rainfall': cfParametersData['RainfallHourly'] ?? [],
                        'Wind Speed': cfParametersData['WindSpeed'] ?? [],
                        'Atm Pressure': cfParametersData['AtmPressure'] ?? [],
                        'Wind Direction':
                            cfParametersData['WindDirection'] ?? [],
                      },
                    ),
                  if (widget.deviceName.startsWith('KJ'))
                    _buildMinMaxTable(
                      isDarkMode,
                      {
                        'Temperature':
                            KJParametersData['CurrentTemperature'] ?? [],
                        'Humidity': KJParametersData['CurrentHumidity'] ?? [],
                        'Potassium': KJParametersData['Potassium'] ?? [],
                        'pH': KJParametersData['pH'] ?? [],
                        'Nitrogen': KJParametersData['Nitrogen'] ?? [],
                        'Salinity': KJParametersData['Salinity'] ?? [],
                        'ElectricalConductivity':
                            KJParametersData['ElectricalConductivity'] ?? [],
                        'Phosphorus': KJParametersData['Phosphorus'] ?? [],
                      },
                    ),
                  if (widget.deviceName.startsWith('MY'))
                    _buildMinMaxTable(
                      isDarkMode,
                      {
                        'Temperature':
                            MYParametersData['CurrentTemperature'] ?? [],
                        'Humidity': MYParametersData['CurrentHumidity'] ?? [],
                        'Light Intensity':
                            MYParametersData['LightIntensity'] ?? [],
                        'Wind Speed': MYParametersData['WindSpeed'] ?? [],
                        'Atm Pressure': MYParametersData['AtmPressure'] ?? [],
                        'Wind Direction':
                            MYParametersData['WindDirection'] ?? [],
                        'Rainfall': MYParametersData['RainfallHourly'] ?? [],
                      },
                    ),

                  // Modified Builder widget for total rainfall display within the sidebar
                  Builder(
                    builder: (context) {
                      double totalRainfall = 0.0;
                      bool showTotalRainfall = false;

                      if (widget.deviceName.startsWith('FS') &&
                          fsrainData.isNotEmpty) {
                        showTotalRainfall = true;
                        totalRainfall = _calculateTotalRainfall(fsrainData);
                      } else if (widget.deviceName.startsWith('NA') &&
                          NARLParametersData['RainfallHourly'] != null &&
                          NARLParametersData['RainfallHourly']!.isNotEmpty) {
                        showTotalRainfall = true;
                        totalRainfall = _calculateTotalRainfall(
                            NARLParametersData['RainfallHourly']!);
                      } else if (widget.deviceName.startsWith('MY') &&
                          MYParametersData['RainfallHourly'] != null &&
                          MYParametersData['RainfallHourly']!.isNotEmpty) {
                        showTotalRainfall = true;
                        totalRainfall = _calculateTotalRainfall(
                            MYParametersData['RainfallHourly']!);
                      } else if (widget.deviceName.startsWith('VD') &&
                          vdParametersData['RainfallHourly'] != null &&
                          vdParametersData['RainfallHourly']!.isNotEmpty) {
                        showTotalRainfall = true;
                        totalRainfall = _calculateTotalRainfall(
                            vdParametersData['RainfallHourly']!);
                      } else if (widget.deviceName.startsWith('CF') &&
                          cfParametersData['RainfallHourly'] != null &&
                          cfParametersData['RainfallHourly']!.isNotEmpty) {
                        showTotalRainfall = true;
                        totalRainfall = _calculateTotalRainfall(
                            cfParametersData['RainfallHourly']!);
                      } else if (widget.deviceName.startsWith('CP') &&
                          csParametersData['RainfallHourly'] != null &&
                          csParametersData['RainfallHourly']!.isNotEmpty) {
                        showTotalRainfall = true;
                        totalRainfall = _calculateTotalRainfall(
                            csParametersData['RainfallHourly']!);
                      } else if (widget.deviceName.startsWith('IT') &&
                          itrainData.isNotEmpty) {
                        showTotalRainfall = true;
                        totalRainfall = _calculateTotalRainfall(itrainData);
                      } else if ((widget.deviceName.startsWith('WD211') ||
                              widget.deviceName.startsWith('WD511')) &&
                          wfrainfallData.isNotEmpty) {
                        showTotalRainfall = true;
                        totalRainfall = _calculateTotalRainfall(wfrainfallData);
                      }

                      if (showTotalRainfall &&
                          !_isLoading &&
                          _errorMessage == null) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 16.0, left: 16),
                          child: Text(
                            'Total Rainfall: ${totalRainfall.toStringAsFixed(2)} mm',
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  DateTime _selectedDay = DateTime.now();
  List<ChartData> temperatureData = [];
  List<ChartData> humidityData = [];
  List<ChartData> lightIntensityData = [];
  List<ChartData> windSpeedData = [];
  List<ChartData> rainLevelData = [];
  List<ChartData> rainDifferenceData = [];
  List<ChartData> solarIrradianceData = [];
  List<ChartData> windDirectionData = [];
  List<ChartData> chlorineData = [];
  List<ChartData> electrodeSignalData = [];
  List<ChartData> hypochlorousData = [];
  List<ChartData> temppData = [];
  List<ChartData> residualchlorineData = [];
  List<ChartData> tempData = [];
  List<ChartData> tdsData = [];
  List<ChartData> codData = [];
  List<ChartData> bodData = [];
  List<ChartData> pHData = [];
  List<ChartData> doData = [];
  List<ChartData> ecData = [];
  List<ChartData> temmppData = [];
  List<ChartData> humidityyData = [];
  List<ChartData> lightIntensityyData = [];
  List<ChartData> windSpeeddData = [];
  List<ChartData> ttempData = [];
  List<ChartData> dovaluedata = [];
  List<ChartData> dopercentagedata = [];
  List<ChartData> temperaturData = [];
  List<ChartData> humData = [];
  List<ChartData> luxData = [];
  List<ChartData> coddata = [];
  List<ChartData> boddata = [];
  List<ChartData> phdata = [];
  List<ChartData> temperattureData = [];
  List<ChartData> humidittyData = [];
  List<ChartData> ammoniaData = [];
  List<ChartData> temperaturedata = [];
  List<ChartData> humiditydata = [];
  List<ChartData> rfdData = [];
  List<ChartData> rfsData = [];
  List<ChartData> ittempData = [];
  List<ChartData> itpressureData = [];
  List<ChartData> ithumidityData = [];
  List<ChartData> itradiationData = [];
  List<ChartData> itwindspeedData = [];
  List<ChartData> itvisibilityData = [];
  List<ChartData> itrainData = [];
  List<ChartData> itwinddirectionData = [];
  List<ChartData> fstempData = [];
  List<ChartData> fspressureData = [];
  List<ChartData> fshumidityData = [];
  List<ChartData> fsradiationData = [];
  List<ChartData> fswindspeedData = [];
  List<ChartData> smwindspeedData = [];
  List<ChartData> smWindDirectionData = [];
  List<ChartData> smAtmPressureData = [];
  List<ChartData> smLightIntensityData = [];
  List<ChartData> smRainfallWeeklyData = [];
  List<ChartData> smMaximumTemperatureData = [];
  List<ChartData> smRainfallDailyData = [];
  List<ChartData> smAverageHumidityData = [];
  List<ChartData> smBatteryVoltageData = [];
  List<ChartData> smAverageTemperatureData = [];
  List<ChartData> smMaximumHumidityData = [];
  List<ChartData> smMinimumTemperatureData = [];
  List<ChartData> smMinimumHumidityData = [];
  List<ChartData> smCurrentHumidityData = [];
  List<ChartData> smRainfallHourlyData = [];
  List<ChartData> smIMEINumberData = [];
  List<ChartData> smRainfallMinutlyData = [];
  List<ChartData> smCurrentTemperatureData = [];
  List<ChartData> smSignalStrength = [];
  Map<String, List<ChartData>> smParametersData = {};
  Map<String, List<ChartData>> cfParametersData = {};
  Map<String, List<ChartData>> svParametersData = {};
  Map<String, List<ChartData>> kdParametersData = {};
  Map<String, List<ChartData>> vdParametersData = {};
  Map<String, List<ChartData>> NARLParametersData = {};
  Map<String, List<ChartData>> KJParametersData = {};
  Map<String, List<ChartData>> MYParametersData = {};
  Map<String, List<ChartData>> csParametersData = {};
  List<ChartData> cod2Data = [];
  List<ChartData> bod2Data = [];
  List<ChartData> temp2Data = [];
  String _currentStatus = 'Unknown';
  bool _isLoading = false;
  String? _errorMessage;
  late final String activityType;

  // Add this method to convert degrees to direction (e.g., ENE)
  String _getWindDirection(double degrees) {
    final directions = [
      "N",
      "NNE",
      "NE",
      "ENE",
      "E",
      "ESE",
      "SE",
      "SSE",
      "S",
      "SSW",
      "SW",
      "WSW",
      "W",
      "WNW",
      "NW",
      "NNW"
    ];
    final index = ((degrees + 11.25) / 22.5).floor() % 16;
    return directions[index];
  }

  double _convertVoltageToPercentage(double voltage) {
    const double maxVoltage = 4.2; // 100%
    const double minVoltage = 2.8; // 0%

    // Clamp the voltage to the valid range to avoid percentages outside 0-100
    if (voltage >= maxVoltage) return 100.0;
    if (voltage <= minVoltage) return 0.0;

    // Linear interpolation: percentage = ((voltage - min) / (max - min)) * 100
    return ((voltage - minVoltage) / (maxVoltage - minVoltage)) * 100.0;
  }

// Helper function to calculate total rainfall (unchanged)
  double _calculateTotalRainfall(List<ChartData> rainData) {
    if (rainData.isEmpty) return 0.0;

    final Map<DateTime, double> hourlyTotals = {};

    for (var data in rainData) {
      DateTime hourEnd = DateTime(
        data.timestamp.year,
        data.timestamp.month,
        data.timestamp.day,
        data.timestamp.hour,
        0,
      );
      if (data.timestamp.minute > 0) {
        hourEnd = DateTime(
          data.timestamp.year,
          data.timestamp.month,
          data.timestamp.day,
          data.timestamp.hour + 1,
          0,
        );
      }

      if (data.timestamp.isAtSameMomentAs(hourEnd) ||
          data.timestamp.isBefore(hourEnd)) {
        hourlyTotals[hourEnd] = data.value;
      }
    }

    return hourlyTotals.values.fold(0.0, (sum, total) => sum + total);
  }

// Helper function to transform cumulative rainfall to incremental rainfall
  List<ChartData> _transformToIncrementalRainfall(List<ChartData> rainData) {
    if (rainData.isEmpty) return [];

    // Sort data by timestamp to ensure chronological order
    final sortedData = List<ChartData>.from(rainData)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    List<ChartData> incrementalData = [];
    double previousValue = 0.0;
    DateTime? previousTimestamp;

    for (var data in sortedData) {
      double incrementalValue;

      if (previousTimestamp == null) {
        // First data point: treat as incremental (no previous value)
        incrementalValue = data.value;
      } else {
        // Determine the hour start for the current and previous timestamps
        DateTime currentHourStart = DateTime(
          data.timestamp.year,
          data.timestamp.month,
          data.timestamp.day,
          data.timestamp.hour,
        );

        DateTime previousHourStart = DateTime(
          previousTimestamp.year,
          previousTimestamp.month,
          previousTimestamp.day,
          previousTimestamp.hour,
        );

        bool isEndOfHour =
            data.timestamp.minute == 0 && data.timestamp.second == 0;
        bool isReset = data.timestamp.minute == 1 && data.timestamp.second == 0;
        bool isNewHour = currentHourStart.isAfter(previousHourStart);

        if (isEndOfHour) {
          // At XX:00, use the difference from previous value (not the full cumulative)
          incrementalValue = data.value - previousValue;
          incrementalValue = incrementalValue >= 0 ? incrementalValue : 0.0;
        } else if (isReset || isNewHour) {
          // At XX:01 or new hour, the value is fresh (reset happened)
          incrementalValue = data.value;
        } else {
          // Within the same hour, calculate difference
          incrementalValue = data.value - previousValue;
          incrementalValue = incrementalValue >= 0 ? incrementalValue : 0.0;
        }
      }

      incrementalData.add(ChartData(
        timestamp: data.timestamp,
        value: incrementalValue,
      ));

      // Update for next iteration
      previousValue = data.value;
      previousTimestamp = data.timestamp;
    }

    return incrementalData;
  }

  double? _lastLatitude;
  double? _lastLongitude;
  DateTime? _lastLocationTime;
  final DateFormat formatter = DateFormat('dd-MM-yyyy HH:mm:ss');
  List<ChartData> wfAverageTemperatureData = [];
  List<ChartData> wfrainfallData = [];
  List<ChartData> fsrainData = [];
  List<ChartData> fswinddirectionData = [];
  Timer? _reloadTimer;
  double? _fsDailyRainBaseline;
  String? _fsLastRainDate;
  // AnimationController for rotating refresh icon
  late AnimationController _rotationController;
  // Add a map to store hover states for each parameter
  final Map<String, bool> _isParamHovering = {};
  String? _selectedParam;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _hasShownAmmoniaNotification =
      false; // To prevent repeated notifications
  double _ammoniaThreshold = 0.0; // Threshold for ammonia alerts

  bool isShiftPressed = false;
  late final FocusNode _focusNode;

  List<Map<String, dynamic>> rainHourlyItems = [];
  List<List<dynamic>> _csvRainRows = [];

  double _precipitationProbability = 0.0;
  List<double> _weeklyPrecipitationData = [];
  int _selectedDeviceId = 0; // Variable to hold the selected device ID
  bool _isHovering = false;
  String? _activeButton;
  String _currentChlorineValue = '0.00';
  String _currentrfdValue = '0.00';
  String _currentAmmoniaValue = '0.00';
  List<DeviceStatus> _deviceStatuses = [];

  String _lastSelectedRange = 'single'; // Default to single
  bool isWindDirectionValid(String? windDirection) {
    return windDirection != null && windDirection != "-";
  }

  List<PlotBand> _generateNoonPlotBands(List<ChartData> data, bool isDarkMode) {
    if (data.isEmpty) return [];

    // Get the date range from the data
    final DateTime minDate =
        data.first.timestamp; // Assuming ChartData.x is DateTime
    final DateTime maxDate = data.last.timestamp;

    // Generate one plot band per day at 12 noon
    List<PlotBand> plotBands = [];
    DateTime currentDate = DateTime(minDate.year, minDate.month, minDate.day);

    while (currentDate.isBefore(maxDate) ||
        currentDate.isAtSameMomentAs(maxDate)) {
      DateTime noon = DateTime(
          currentDate.year, currentDate.month, currentDate.day, 12, 0, 0);
      plotBands.add(
        PlotBand(
          start: noon,
          end: noon,
          borderWidth: 1.0,
          dashArray: [5, 5],
          borderColor: isDarkMode
              ? Color.fromARGB(255, 141, 144, 148)
              : Color.fromARGB(255, 48, 48, 48),
          verticalTextAlignment: TextAnchor.middle,
          shouldRenderAboveSeries: false,
        ),
      );
      currentDate = currentDate.add(Duration(days: 1));
    }

    return plotBands;
  }

  bool iswinddirectionValid(String? direction) {
    if (direction == null || direction.isEmpty) {
      return false;
    }
    try {
      double value = double.parse(direction);
      bool isValid = value >= 0 && value <= 360;

      return isValid;
    } catch (e) {
      return false;
    }
  }

  // ScrollController for scrolling to charts
  final ScrollController _scrollController = ScrollController();
  // Map to associate parameter labels with their chart keys
  final Map<String, GlobalKey> _chartKeys = {};
  // New variables to store rain forecasting data for WD 211
  String _totalRainLast24Hours = '0.00 mm';
  String _mostRecentHourRain = '0.00 mm';

  bool hasNonZeroValues(List<dynamic> data,
      {bool includePrecipitation = true}) {
    // Exclude precipitation from the zero check if `includePrecipitation` is false
    if (includePrecipitation) {
      return data.isNotEmpty && data.any((entry) => entry.value != 0);
    } else {
      return data.isNotEmpty &&
          data.any((entry) =>
              entry.value != 0 && entry.type != 'precipitationProbability');
    }
  }

  @override
  void initState() {
    super.initState();
    requestPermissions();
    _fetchDeviceDetails();
    _fetchDataForRange('single');
    _focusNode = FocusNode();
    _initializeNotifications();

    // Initialize AnimationController
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 500), // Slower for visibility
      vsync: this,
    );
    // Trigger initial data fetch with _reloadData to rotate icon

    _reloadData(range: 'single');

    // Set up the periodic timer to reload data every 120 seconds
    _reloadTimer = Timer.periodic(const Duration(seconds: 180), (timer) {
      if (!_isLoading) {
        _reloadData(range: _lastSelectedRange);
      } else {}
    });
    // Initialize chart keys for each parameter
    _initializeChartKeys();
  }

  // Update _initializeChartKeys to ensure consistent parameter names
  void _initializeChartKeys() {
    // Initialize hover states and chart keys
    _chartKeys.clear();
    _isParamHovering.clear();
    _selectedParam = null; // Reset selected parameter

    if (widget.deviceName.startsWith('WQ')) {
      const params = [
        'Temperature',
        'TDS',
        'COD',
        'BOD',
        'pH',
        'DO',
        'EC',
      ];
      for (var param in params) {
        _chartKeys[param] = GlobalKey();
        _isParamHovering[param] = false;
      }
    } else if (widget.deviceName.startsWith('FS')) {
      const params = [
        'Temperature',
        'Pressure',
        'Humidity',
        'Rain Level',
        'Radiation',
        'Wind Speed',
        'Wind Direction',
      ];
      for (var param in params) {
        _chartKeys[param] = GlobalKey();
        _isParamHovering[param] = false;
      }
    } else if (widget.deviceName.startsWith('CB')) {
      const params = ['Temperature', 'COD', 'BOD'];
      for (var param in params) {
        _chartKeys[param] = GlobalKey();
        _isParamHovering[param] = false;
      }
    } else if (widget.deviceName.startsWith('NH')) {
      const params = ['Ammonia', 'Temperature', 'Humidity'];
      for (var param in params) {
        _chartKeys[param] = GlobalKey();
        _isParamHovering[param] = false;
      }
    } else if (widget.deviceName.startsWith('DO')) {
      const params = ['Temperature', 'DO Value', 'DO Percentage'];
      for (var param in params) {
        _chartKeys[param] = GlobalKey();
        _isParamHovering[param] = false;
      }
    } else if (widget.deviceName.startsWith('NA')) {
      const params = [
        'Temperature',
        'Humidity',
        'Light Intensity',
        'Wind Speed',
        'Atm Pressure',
        'Wind Direction',
        'Rainfall',
      ];
      for (var param in params) {
        _chartKeys[param] = GlobalKey();
        _isParamHovering[param] = false;
      }
    } else if (widget.deviceName.startsWith('VD')) {
      const params = ['Temperature', 'Humidity', 'Light Intensity', 'Rainfall'];
      for (var param in params) {
        _chartKeys[param] = GlobalKey();
        _isParamHovering[param] = false;
      }
    } else if (widget.deviceName.startsWith('KJ')) {
      const params = [
        'Temperature',
        'Potassium',
        'pH',
        'Nitrogen',
        'Salinity',
        'ElectricalConductivity',
        'Phosphorus',
      ];
      for (var param in params) {
        _chartKeys[param] = GlobalKey();
        _isParamHovering[param] = false;
      }
    } else if (widget.deviceName.startsWith('MY')) {
      const params = [
        'Temperature',
        'Humidity',
        'Light Intensity',
        'Wind Speed',
        'Atm Pressure',
        'Wind Direction',
        'Rainfall',
      ];
      for (var param in params) {
        _chartKeys[param] = GlobalKey();
        _isParamHovering[param] = false;
      }
    } else if (widget.deviceName.startsWith('VD')) {
      const params = ['Temperature', 'Humidity', 'Light Intensity', 'Rainfall'];
      for (var param in params) {
        _chartKeys[param] = GlobalKey();
        _isParamHovering[param] = false;
      }
    } else if (widget.deviceName.startsWith('CF') ||
        widget.deviceName.startsWith('CP')) {
      const params = [
        'Temperature',
        'Humidity',
        'Light Intensity',
        'Rainfall',
        'Wind Speed',
        'Atm Pressure',
        'Wind Direction',
      ];
      for (var param in params) {
        _chartKeys[param] = GlobalKey();
        _isParamHovering[param] = false;
      }
    } else {
      const params = [
        'Chlorine',
        'Temperature',
        'Humidity',
        'Light Intensity',
        'Wind Speed',
        'Solar Irradiance',
      ];
      for (var param in params) {
        _chartKeys[param] = GlobalKey();
        _isParamHovering[param] = false;
      }
    }
  }

  @override
  void dispose() {
    // Cancel the timer to prevent memory leaks
    _reloadTimer?.cancel();
    _focusNode.dispose();
    _rotationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> requestPermissions() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

// Add this method to initialize notifications
  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
  }

  // Add this method to show notification
  Future<void> _showAmmoniaAlertNotification(double value) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'ammonia_alerts',
      'Ammonia Alerts',
      channelDescription: 'Alerts for high ammonia values',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      'High Ammonia Level Alert',
      'Ammonia level has reached ${value.toStringAsFixed(2)}, exceeding the safe threshold of $_ammoniaThreshold',
      platformChannelSpecifics,
    );
  }

  Future<void> _fetchDeviceDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _deviceStatuses = [];
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://xa9ry8sls0.execute-api.us-east-1.amazonaws.com/CloudSense_device_activity_api_function',
        ),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        List<DeviceStatus> deviceStatuses = [];

        final activityTypes = [
          {'key': 'chloritrone_Device_Activity', 'type': 'chloritrone'},
          {'key': 'WS_Device_Activity', 'type': 'WS'},
          {'key': 'weather_Device_Activity', 'type': 'weather'},
          {'key': 'water_Device_Activity', 'type': 'water'},
          {'key': 'Awadh_Jio_Device_Activity', 'type': 'Awadh_Jio'},
        ];

        for (var activity in activityTypes) {
          final devices = data[activity['key']] as List<dynamic>? ?? [];
          for (var device in devices) {
            final deviceData = device as Map<String, dynamic>;
            final lat = deviceData['LastKnownLatitude'] is num &&
                    deviceData['LastKnownLatitude'] != 0
                ? deviceData['LastKnownLatitude'] as double?
                : null;
            final lon = deviceData['LastKnownLongitude'] is num &&
                    deviceData['LastKnownLongitude'] != 0
                ? deviceData['LastKnownLongitude'] as double?
                : null;

            deviceStatuses.add(DeviceStatus(
              deviceId: deviceData['DeviceId'].toString(),
              lastReceivedTime: parseTime(deviceData['lastReceivedTime']),
              latitude: lat,
              longitude: lon,
              activityType:
                  _mapActivityToPrefix(activity['type']!, deviceData['Topic']),
            ));
          }
        }

        deviceStatuses.sort((a, b) {
          final aTime = DateTime.tryParse(a.lastReceivedTime) ?? DateTime(1970);
          final bTime = DateTime.tryParse(b.lastReceivedTime) ?? DateTime(1970);
          return bTime.compareTo(aTime);
        });

        setState(() {
          _deviceStatuses = deviceStatuses;
        });
      } else {
        setState(() {
          _errorMessage =
              'Failed to load device details: HTTP ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching device details: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String parseTime(String? time) {
    if (time == null) return 'Unknown';
    try {
      final compactRegex = RegExp(r'^\d{8}T\d{6}$');
      if (compactRegex.hasMatch(time)) {
        final year = int.parse(time.substring(0, 4));
        final month = int.parse(time.substring(4, 6));
        final day = int.parse(time.substring(6, 8));
        final hour = int.parse(time.substring(9, 11));
        final minute = int.parse(time.substring(11, 13));
        final second = int.parse(time.substring(13, 15));
        return DateFormat('dd-MM-yyyy HH:mm:ss').format(
          DateTime(year, month, day, hour, minute, second),
        );
      }

      final dmyRegex = RegExp(r'^\d{2}-\d{2}-\d{4} \d{2}:\d{2}:\d{2}$');
      if (dmyRegex.hasMatch(time)) {
        final parts = time.split(' ');
        final dateParts = parts[0].split('-');
        final timeParts = parts[1].split(':');
        final day = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]);
        final year = int.parse(dateParts[2]);
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final second = int.parse(timeParts[2]);
        return DateFormat('dd-MM-yyyy HH:mm:ss').format(
          DateTime(year, month, day, hour, minute, second),
        );
      }

      final amPmRegex = RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2} (AM|PM)$');
      if (amPmRegex.hasMatch(time)) {
        final isPm = time.endsWith('PM');
        final base = time.replaceAll(RegExp(r' (AM|PM)$'), '');
        final dateTimeParts = base.split(' ');
        final date = dateTimeParts[0];
        final timeStr = dateTimeParts[1];
        final dateParts = date.split('-');
        final timeParts = timeStr.split(':');
        int hour = int.parse(timeParts[0]);
        if (isPm && hour < 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;
        return DateFormat('dd-MM-yyyy HH:mm:ss').format(
          DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
            hour,
            int.parse(timeParts[1]),
          ),
        );
      }

      final parsed = DateTime.tryParse(time.replaceAll('  ', ' '));
      return parsed != null
          ? DateFormat('dd-MM-yyyy HH:mm:ss').format(parsed)
          : time;
    } catch (e) {
      return time;
    }
  }

  String _mapActivityToPrefix(String activityType, String? topic) {
    if (activityType == 'chloritrone') return 'CB';
    if (activityType == 'water') return 'WQ';
    if (activityType == 'weather') return 'weather';
    if (activityType == 'Awadh_Jio') return 'FS'; // Map Awadh_Jio to FS
    if (activityType == 'WS') {
      if (topic == null) return 'FS'; // Default to FS if topic is null
      if (topic.contains('SSMET')) return 'SM';
      if (topic.contains('NARL')) return 'NA';
      if (topic == 'WS/Campus/2') return 'CF'; // Exact match before contains
      if (topic.contains('WS/Campus')) return 'CP';
      if (topic.contains('KJSCE')) return 'KJ';
      if (topic.contains('SVPU')) return 'SV';
      if (topic.contains('Mysuru')) return 'MY';
      return 'FS'; // Default to FS for other WS topics
    }

    return activityType;
  }

  String _getPrefix(String deviceName) {
    if (deviceName.startsWith('Awadh_Jio')) return 'Awadh_Jio';
    if (deviceName.startsWith('weather'))
      return 'weather'; // Adjust if weather has a specific prefix
    return deviceName.substring(0, 2);
  }

  List<List<dynamic>> _csvRows = [];
  String _lastWindDirection = "";
  String _lastwinddirection = "";
  // String _lastfswinddirection = "";
  String _lastBatteryPercentage = "";
  double _lastfsBattery = 0.0;
  double _lastsmBattery = 0.0;
  double _lastcfBattery = 0.0;
  double _lastvdBattery = 0.0;
  double _lastkdBattery = 0.0;
  double _lastNARLBattery = 0.0;
  double _lastKJBattery = 0.0;
  double _lastMYBattery = 0.0;
  double _lastcsBattery = 0.0;
  double _lastsvBattery = 0.0;
  String _lastRSSI_Value = "";

  Future<void> _fetchDataForRange(String range,
      [DateTime? selectedDate]) async {
    setState(() {
      _isLoading = true;
      _csvRows.clear();
      chlorineData.clear();
      temperatureData.clear();
      humidityData.clear();
      lightIntensityData.clear();
      windSpeedData.clear();
      rainLevelData.clear();
      solarIrradianceData.clear();
      windDirectionData.clear();
      electrodeSignalData.clear();
      hypochlorousData.clear();
      temppData.clear();
      residualchlorineData.clear();
      tempData.clear();
      tdsData.clear();
      codData.clear();
      bodData.clear();
      pHData.clear();
      doData.clear();
      ecData.clear();
      temmppData.clear();
      humidityyData.clear();
      lightIntensityyData.clear();
      windSpeeddData.clear();
      ttempData.clear();
      dovaluedata.clear();
      dopercentagedata.clear();
      temperaturData.clear();
      humData.clear();
      luxData.clear();
      ammoniaData.clear();
      temperaturedata.clear();
      humiditydata.clear();
      ittempData.clear();
      itpressureData.clear();
      ithumidityData.clear();
      itradiationData.clear();
      itvisibilityData.clear();
      itrainData.clear();
      itwinddirectionData.clear();
      itwindspeedData.clear();
      fshumidityData.clear();
      fspressureData.clear();
      fsradiationData.clear();
      fsrainData.clear();
      fstempData.clear();
      fswinddirectionData.clear();
      _lastfsBattery = 0.0;
      _lastsmBattery = 0.0;
      _lastcfBattery = 0.0;
      _lastvdBattery = 0.0;
      _lastkdBattery = 0.0;
      _lastNARLBattery = 0.0;
      _lastKJBattery = 0.0;
      _lastMYBattery = 0.0;

      _lastcsBattery = 0.0;
      _lastsvBattery = 0.0;

      fswindspeedData.clear();

      smParametersData.clear();
      cfParametersData.clear();
      svParametersData.clear();
      vdParametersData.clear();
      wfAverageTemperatureData.clear();
      wfrainfallData.clear();
      kdParametersData.clear();
      NARLParametersData.clear();
      KJParametersData.clear();
      MYParametersData.clear();
      csParametersData.clear();

      _weeklyPrecipitationData.clear();
    });
    DateTime startDate;
    DateTime endDate = DateTime.now();

    switch (range) {
      case '7days':
        startDate = endDate.subtract(Duration(days: 7));
        break;
      case '30days':
        startDate = endDate.subtract(Duration(days: 30));
        break;
      case '3months':
        startDate = endDate.subtract(Duration(days: 90));
        break;
      case '1year':
        startDate = endDate.subtract(Duration(days: 365));
        break;
      case 'single':
        startDate = _selectedDay; // Use the selected day as startDate
        endDate = startDate;

        // Single day means endDate is same as startDate
        break;
      default:
        startDate = endDate; // Default to today
    }

    _lastSelectedRange = range; // Store the currently selected range

    // Format dates for most APIs (DD-MM-YYYY)
    final dateFormatter = DateFormat('dd-MM-yyyy');
    final startdate = dateFormatter.format(startDate);
    final enddate = dateFormatter.format(endDate);

    // Format dates for SM sensor API (YYYYMMDD)
    final smDateFormatter = DateFormat('yyyyMMdd');
    final smStartDate = smDateFormatter.format(startDate);
    final smEndDate = smDateFormatter.format(endDate);

    final DateFormat formatter = DateFormat('dd-MM-yyyy HH:mm:ss');
    int deviceId =
        int.parse(widget.deviceName.replaceAll(RegExp(r'[^0-9]'), ''));

    setState(() {
      _selectedDeviceId = deviceId; // Set the selected device ID
    });
    // Call the additional rain data API for WD211
    if (widget.deviceName == 'WD211') {
      await _fetchRainForecastingData();
    }
    if (widget.deviceName == 'WD511') {
      await _fetchRainForecastData();
    }

    String apiUrl;
    if (widget.deviceName.startsWith('SM')) {
      apiUrl =
          'https://n42fiw7l89.execute-api.us-east-1.amazonaws.com/default/SSMet_API_Func?device_id=$deviceId&start_date=$smStartDate&end_date=$smEndDate';
    } else if (widget.deviceName.startsWith('CF')) {
      apiUrl =
          'https://d3g5fo66jwc4iw.cloudfront.net/colonelfarmdata?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('VD')) {
      apiUrl =
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/vanixdata?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('SV')) {
      apiUrl =
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/svpudata?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('KD')) {
      apiUrl =
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/kargildata?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('NA')) {
      apiUrl =
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/ssmetnarldata?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('KJ')) {
      apiUrl =
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/kjscedata?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('MY')) {
      apiUrl =
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/mysurudata?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('CP')) {
      apiUrl =
          'https://d3g5fo66jwc4iw.cloudfront.net/campusdata?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('WD')) {
      apiUrl =
          'https://62f4ihe2lf.execute-api.us-east-1.amazonaws.com/CloudSense_Weather_data_api_function?DeviceId=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('CL') ||
        (widget.deviceName.startsWith('BD'))) {
      apiUrl =
          'https://b0e4z6nczh.execute-api.us-east-1.amazonaws.com/CloudSense_Chloritrone_api_function?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('WQ')) {
      apiUrl =
          'https://oy7qhc1me7.execute-api.us-west-2.amazonaws.com/default/k_wqm_api?deviceid=${widget.deviceName}&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('WF')) {
      apiUrl =
          'https://wf3uh3yhn7.execute-api.us-east-1.amazonaws.com/default/Awadh_Jio_Data_Api_func?Device_ID=$deviceId&start_date=$startdate&end_date=$enddate';
    } else if (widget.deviceName.startsWith('IT')) {
      apiUrl =
          'https://7a3bcew3y2.execute-api.us-east-1.amazonaws.com/default/IIT_Bombay_API_func?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('WS')) {
      apiUrl =
          'https://xjbnnqcup4.execute-api.us-east-1.amazonaws.com/default/CloudSense_Water_quality_api_function?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('CB')) {
      apiUrl =
          'https://a9z5vrfpkd.execute-api.us-east-1.amazonaws.com/default/CloudSense_BOD_COD_Api_func?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('FS')) {
      apiUrl =
          'https://w7w21t8s23.execute-api.us-east-1.amazonaws.com/default/SSMet_Forest_API_func?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('DO')) {
      apiUrl =
          'https://br2s08as9f.execute-api.us-east-1.amazonaws.com/default/CloudSense_Water_quality_api_2_function?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('TH')) {
      apiUrl =
          'https://5s3pangtz0.execute-api.us-east-1.amazonaws.com/default/CloudSense_TH_Data_Api_function?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('NH')) {
      apiUrl =
          'https://qgbwurafri.execute-api.us-east-1.amazonaws.com/default/CloudSense_NH_Data_Api_function?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('LU') ||
        widget.deviceName.startsWith('TE') ||
        widget.deviceName.startsWith('AC')) {
      apiUrl =
          'https://2bftil5o0c.execute-api.us-east-1.amazonaws.com/default/CloudSense_sensor_api_function?DeviceId=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('20')) {
      apiUrl =
          'https://gzdsa7h08k.execute-api.us-east-1.amazonaws.com/default/lat_long_api_func?deviceId=$deviceId';

      try {
        final response = await http.get(Uri.parse(apiUrl));

        if (response.statusCode == 200) {
        } else {
          print("Failed to fetch data. Status Code: ${response.statusCode}");
        }
      } catch (e) {
        print("Error during API call: $e");
      }
    } else {
      setState(() {}); // Not sure if needed here
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        List<List<dynamic>> rows = [];
        String lastWindDirection = 'Unknown';
        String lastwinddirection;
        String lastBatteryPercentage = 'Unknown';
        String lastRSSI_Value = 'Unknown';

        if (widget.deviceName.startsWith('SM')) {
          setState(() {
            smParametersData.clear();
            smParametersData = _parseSMParametersData(data);

            if (smParametersData.isEmpty) {
              _csvRows = [
                ['Timestamp', 'Message'],
                ['', 'No data available']
              ];
            } else {
              List<String> headers = ['Timestamp'];
              headers.addAll(smParametersData.keys);

              List<List<dynamic>> dataRows = [];
              int maxLength = smParametersData.values
                  .map((list) => list.length)
                  .reduce((a, b) => a > b ? a : b);

              for (int i = 0; i < maxLength; i++) {
                List<dynamic> row = [
                  smParametersData.values.isNotEmpty &&
                          smParametersData.values.first.length > i
                      ? formatter
                          .format(smParametersData.values.first[i].timestamp)
                      : ''
                ];
                for (var key in smParametersData.keys) {
                  var value = smParametersData[key]!.length > i
                      ? smParametersData[key]![i].value
                      : null;
                  // ✅ Preserve 0, replace null with empty string
                  row.add(value ?? '');
                }
                dataRows.add(row);
              }

              _csvRows = [headers, ...dataRows];
            }

            // Clear unrelated data
            temperatureData = [];
            humidityData = [];
            // etc...
          });

          // // ✅ Now trigger download
          // downloadCSV(context);
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('CF')) {
          setState(() {
            cfParametersData.clear();
            cfParametersData = _parseCFParametersData(data);

            // Update last location data
            if (data.isNotEmpty) {
              for (var item in data.reversed) {
                if (item['Latitude'] != null &&
                    item['Latitude'] != 0 &&
                    item['Longitude'] != null &&
                    item['Longitude'] != 0) {
                  _lastLatitude = item['Latitude'].toDouble();
                  _lastLongitude = item['Longitude'].toDouble();
                  _lastLocationTime = DateTime.parse(item['TimeStamp']);
                  break;
                }
              }
            }

            if (cfParametersData.isEmpty) {
              _csvRows = [
                ['Timestamp', 'Message'],
                ['', 'No data available']
              ];
            } else {
              List<String> headers = ['Timestamp'];
              headers.addAll(cfParametersData.keys);

              List<List<dynamic>> dataRows = [];
              int maxLength = cfParametersData.values
                  .map((list) => list.length)
                  .reduce((a, b) => a > b ? a : b);

              for (int i = 0; i < maxLength; i++) {
                List<dynamic> row = [
                  cfParametersData.values.isNotEmpty &&
                          cfParametersData.values.first.length > i
                      ? formatter
                          .format(cfParametersData.values.first[i].timestamp)
                      : ''
                ];
                for (var key in cfParametersData.keys) {
                  var value = cfParametersData[key]!.length > i
                      ? cfParametersData[key]![i].value
                      : null;
                  // ✅ Preserve 0, replace null with empty string
                  row.add(value ?? '');
                }
                dataRows.add(row);
              }

              _csvRows = [headers, ...dataRows];
            }

            // Clear unrelated data
            temperatureData = [];
            humidityData = [];
          });

          // // ✅ Now trigger download
          // downloadCSV(context);
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('VD')) {
          setState(() {
            vdParametersData.clear();
            vdParametersData = _parseVDParametersData(data);

            if (vdParametersData.isEmpty) {
              _csvRows = [
                ['Timestamp', 'Message'],
                ['', 'No data available']
              ];
            } else {
              List<String> headers = ['Timestamp'];
              headers.addAll(vdParametersData.keys);

              List<List<dynamic>> dataRows = [];
              int maxLength = vdParametersData.values
                  .map((list) => list.length)
                  .reduce((a, b) => a > b ? a : b);

              for (int i = 0; i < maxLength; i++) {
                List<dynamic> row = [
                  vdParametersData.values.isNotEmpty &&
                          vdParametersData.values.first.length > i
                      ? formatter
                          .format(vdParametersData.values.first[i].timestamp)
                      : ''
                ];
                for (var key in vdParametersData.keys) {
                  var value = vdParametersData[key]!.length > i
                      ? vdParametersData[key]![i].value
                      : null;
                  // ✅ Preserve 0, replace null with empty string
                  row.add(value ?? '');
                }
                dataRows.add(row);
              }

              _csvRows = [headers, ...dataRows];
            }

            // Clear unrelated data
            temperatureData = [];
            humidityData = [];
          });

          // // ✅ Now trigger download
          // downloadCSV(context);
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('SV')) {
          setState(() {
            svParametersData.clear();
            svParametersData = _parseSVParametersData(data);

            if (svParametersData.isEmpty) {
              _csvRows = [
                ['Timestamp', 'Message'],
                ['', 'No data available']
              ];
            } else {
              List<String> headers = ['Timestamp'];
              headers.addAll(svParametersData.keys);

              List<List<dynamic>> dataRows = [];
              int maxLength = svParametersData.values
                  .map((list) => list.length)
                  .reduce((a, b) => a > b ? a : b);

              for (int i = 0; i < maxLength; i++) {
                List<dynamic> row = [
                  svParametersData.values.isNotEmpty &&
                          svParametersData.values.first.length > i
                      ? formatter
                          .format(svParametersData.values.first[i].timestamp)
                      : ''
                ];
                for (var key in svParametersData.keys) {
                  var value = svParametersData[key]!.length > i
                      ? svParametersData[key]![i].value
                      : null;
                  // ✅ Preserve 0, replace null with empty string
                  row.add(value ?? '');
                }
                dataRows.add(row);
              }

              _csvRows = [headers, ...dataRows];
            }

            // Clear unrelated data
            temperatureData = [];
            humidityData = [];
            // etc...
          });

          // // ✅ Now trigger download
          // downloadCSV(context);
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('KD')) {
          setState(() {
            kdParametersData.clear();
            kdParametersData = _parseKDParametersData(data);

            if (kdParametersData.isEmpty) {
              _csvRows = [
                ['Timestamp', 'Message'],
                ['', 'No data available']
              ];
            } else {
              List<String> headers = ['Timestamp'];
              headers.addAll(kdParametersData.keys);

              List<List<dynamic>> dataRows = [];
              int maxLength = kdParametersData.values
                  .map((list) => list.length)
                  .reduce((a, b) => a > b ? a : b);

              for (int i = 0; i < maxLength; i++) {
                List<dynamic> row = [
                  kdParametersData.values.isNotEmpty &&
                          kdParametersData.values.first.length > i
                      ? formatter
                          .format(kdParametersData.values.first[i].timestamp)
                      : ''
                ];
                for (var key in kdParametersData.keys) {
                  var value = kdParametersData[key]!.length > i
                      ? kdParametersData[key]![i].value
                      : null;
                  // ✅ Preserve 0, replace null with empty string
                  row.add(value ?? '');
                }
                dataRows.add(row);
              }

              _csvRows = [headers, ...dataRows];
            }

            // Clear unrelated data
            temperatureData = [];
            humidityData = [];
          });

          // // ✅ Now trigger download
          // downloadCSV(context);
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('NA')) {
          setState(() {
            NARLParametersData.clear();
            NARLParametersData = _parseNARLParametersData(data);

            // Update last location data
            if (data.isNotEmpty) {
              for (var item in data.reversed) {
                if (item['Latitude'] != null &&
                    item['Latitude'] != 0 &&
                    item['Longitude'] != null &&
                    item['Longitude'] != 0) {
                  _lastLatitude = item['Latitude'].toDouble();
                  _lastLongitude = item['Longitude'].toDouble();
                  _lastLocationTime = DateTime.parse(item['TimeStamp']);
                  break;
                }
              }
            }

            if (NARLParametersData.isEmpty) {
              _csvRows = [
                ['Timestamp', 'Message'],
                ['', 'No data available']
              ];
            } else {
              List<String> headers = ['Timestamp'];
              headers.addAll(NARLParametersData.keys);

              List<List<dynamic>> dataRows = [];
              int maxLength = NARLParametersData.values
                  .map((list) => list.length)
                  .reduce((a, b) => a > b ? a : b);

              for (int i = 0; i < maxLength; i++) {
                List<dynamic> row = [
                  NARLParametersData.values.isNotEmpty &&
                          NARLParametersData.values.first.length > i
                      ? formatter
                          .format(NARLParametersData.values.first[i].timestamp)
                      : ''
                ];
                for (var key in NARLParametersData.keys) {
                  var value = NARLParametersData[key]!.length > i
                      ? NARLParametersData[key]![i].value
                      : null;
                  // ✅ Preserve 0, replace null with empty string
                  row.add(value ?? '');
                }
                dataRows.add(row);
              }

              _csvRows = [headers, ...dataRows];
            }

            // Clear unrelated data
            temperatureData = [];
            humidityData = [];
          });

          // // ✅ Now trigger download
          // downloadCSV(context);
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('KJ')) {
          setState(() {
            KJParametersData.clear();
            KJParametersData = _parseKJParametersData(data);

            // Update last location data
            if (data.isNotEmpty) {
              for (var item in data.reversed) {
                if (item['Latitude'] != null &&
                    item['Latitude'] != 0 &&
                    item['Longitude'] != null &&
                    item['Longitude'] != 0) {
                  _lastLatitude = item['Latitude'].toDouble();
                  _lastLongitude = item['Longitude'].toDouble();
                  _lastLocationTime = DateTime.parse(item['TimeStamp']);
                  break;
                }
              }
            }

            if (KJParametersData.isEmpty) {
              _csvRows = [
                ['Timestamp', 'Message'],
                ['', 'No data available']
              ];
            } else {
              List<String> headers = ['Timestamp'];
              headers.addAll(KJParametersData.keys);

              List<List<dynamic>> dataRows = [];
              int maxLength = KJParametersData.values
                  .map((list) => list.length)
                  .reduce((a, b) => a > b ? a : b);

              for (int i = 0; i < maxLength; i++) {
                List<dynamic> row = [
                  KJParametersData.values.isNotEmpty &&
                          KJParametersData.values.first.length > i
                      ? formatter
                          .format(KJParametersData.values.first[i].timestamp)
                      : ''
                ];
                for (var key in KJParametersData.keys) {
                  var value = KJParametersData[key]!.length > i
                      ? KJParametersData[key]![i].value
                      : null;
                  // ✅ Preserve 0, replace null with empty string
                  row.add(value ?? '');
                }
                dataRows.add(row);
              }

              _csvRows = [headers, ...dataRows];
            }

            // Clear unrelated data
            temperatureData = [];
            humidityData = [];
          });

          // // ✅ Now trigger download
          // downloadCSV(context);
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('MY')) {
          setState(() {
            MYParametersData.clear();
            MYParametersData = _parseMYParametersData(data);

            // Update last location data
            if (data.isNotEmpty) {
              for (var item in data.reversed) {
                if (item['Latitude'] != null &&
                    item['Latitude'] != 0 &&
                    item['Longitude'] != null &&
                    item['Longitude'] != 0) {
                  _lastLatitude = item['Latitude'].toDouble();
                  _lastLongitude = item['Longitude'].toDouble();
                  _lastLocationTime = DateTime.parse(item['TimeStamp']);
                  break;
                }
              }
            }

            if (MYParametersData.isEmpty) {
              _csvRows = [
                ['Timestamp', 'Message'],
                ['', 'No data available']
              ];
            } else {
              List<String> headers = ['Timestamp'];
              headers.addAll(MYParametersData.keys);

              List<List<dynamic>> dataRows = [];
              int maxLength = MYParametersData.values
                  .map((list) => list.length)
                  .reduce((a, b) => a > b ? a : b);

              for (int i = 0; i < maxLength; i++) {
                List<dynamic> row = [
                  MYParametersData.values.isNotEmpty &&
                          MYParametersData.values.first.length > i
                      ? formatter
                          .format(MYParametersData.values.first[i].timestamp)
                      : ''
                ];
                for (var key in MYParametersData.keys) {
                  var value = MYParametersData[key]!.length > i
                      ? MYParametersData[key]![i].value
                      : null;
                  // ✅ Preserve 0, replace null with empty string
                  row.add(value ?? '');
                }
                dataRows.add(row);
              }

              _csvRows = [headers, ...dataRows];
            }

            // Clear unrelated data
            temperatureData = [];
            humidityData = [];
          });

          // // ✅ Now trigger download
          // downloadCSV(context);
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('CP')) {
          setState(() {
            csParametersData.clear();
            csParametersData = _parsecsParametersData(data);

            // Update last location data
            if (data.isNotEmpty) {
              // Find the most recent non-zero location data
              for (var item in data.reversed) {
                // Iterate in reverse to get the latest first
                if (item['Latitude'] != null &&
                    item['Latitude'] != 0 &&
                    item['Longitude'] != null &&
                    item['Longitude'] != 0) {
                  _lastLatitude = item['Latitude'].toDouble();
                  _lastLongitude = item['Longitude'].toDouble();
                  _lastLocationTime = DateTime.parse(item['TimeStamp']);
                  break; // Exit after finding the first valid location
                }
              }
            }

            if (csParametersData.isEmpty) {
              _csvRows = [
                ['Timestamp', 'Message'],
                ['', 'No data available']
              ];
            } else {
              List<String> headers = ['Timestamp'];
              headers.addAll(csParametersData.keys);

              List<List<dynamic>> dataRows = [];
              int maxLength = csParametersData.values
                  .map((list) => list.length)
                  .reduce((a, b) => a > b ? a : b);

              for (int i = 0; i < maxLength; i++) {
                List<dynamic> row = [
                  csParametersData.values.isNotEmpty &&
                          csParametersData.values.first.length > i
                      ? formatter
                          .format(csParametersData.values.first[i].timestamp)
                      : ''
                ];
                for (var key in csParametersData.keys) {
                  var value = csParametersData[key]!.length > i
                      ? csParametersData[key]![i].value
                      : null;
                  // ✅ Preserve 0, replace null with empty string
                  row.add(value ?? '');
                }
                dataRows.add(row);
              }

              _csvRows = [headers, ...dataRows];
            }

            // Clear unrelated data
            temperatureData = [];
            humidityData = [];
          });

          // // ✅ Now trigger download
          // downloadCSV(context);
          await _fetchDeviceDetails();
        }

        if (widget.deviceName.startsWith('CL') ||
            widget.deviceName.startsWith('BD')) {
          setState(() {
            chlorineData = _parseBDChartData(data, 'chlorine');
            temperatureData = [];
            humidityData = [];
            lightIntensityData = [];
            windSpeedData = [];
            rainLevelData = [];
            solarIrradianceData = [];
            tempData = [];
            tdsData = [];
            codData = [];
            bodData = [];
            pHData = [];
            doData = [];
            ecData = [];

            // Update current chlorine value
            if (chlorineData.isNotEmpty) {
              _currentChlorineValue =
                  chlorineData.last.value.toStringAsFixed(2);
            }

            // Prepare data for CSV

            rows = [
              ["Timestamp", "Chlorine"],
              ...chlorineData.map(
                  (entry) => [formatter.format(entry.timestamp), entry.value])
            ];
          });
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('WQ')) {
          setState(() {
            tempData = _parseWaterChartData(data, 'temperature');
            tdsData = _parseWaterChartData(data, 'TDS');
            codData = _parseWaterChartData(data, 'COD');
            bodData = _parseWaterChartData(data, 'BOD');
            pHData = _parseWaterChartData(data, 'pH');
            doData = _parseWaterChartData(data, 'DO');
            ecData = _parseWaterChartData(data, 'EC');
            temperatureData = [];
            humidityData = [];
            lightIntensityData = [];
            windSpeedData = [];
            rainLevelData = [];
            solarIrradianceData = [];
            chlorineData = [];

            rows = [
              [
                "Timestamp",
                "temperature",
                "TDS ",
                "COD",
                "BOD",
                "pH",
                "DO",
                "EC"
              ],
              for (int i = 0; i < tempData.length; i++)
                [
                  formatter.format(tempData[i].timestamp),
                  tempData[i].value,
                  tdsData[i].value,
                  codData[i].value,
                  bodData[i].value,
                  pHData[i].value,
                  doData[i].value,
                  ecData[i].value,
                ]
            ];
          });
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('CB')) {
          setState(() {
            temp2Data = _parseCBChartData(data, 'temperature');

            cod2Data = _parseCBChartData(data, 'COD');
            bod2Data = _parseCBChartData(data, 'BOD');

            rows = [
              [
                "Timestamp",
                "temperature",
                "COD",
                "BOD",
              ],
              for (int i = 0; i < temp2Data.length; i++)
                [
                  formatter.format(temp2Data[i].timestamp),
                  temp2Data[i].value,
                  cod2Data[i].value,
                  bod2Data[i].value,
                ]
            ];
          });
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('IT')) {
          setState(() {
            ittempData = _parseITChartData(data, 'temperature');
            itpressureData = _parseITChartData(data, 'pressure');
            ithumidityData = _parseITChartData(data, 'humidity');
            itradiationData = _parseITChartData(data, 'radiation');
            itrainData = _parseITChartData(data, 'rain_level');
            itvisibilityData = _parseITChartData(data, 'visibility');
            itwinddirectionData = _parseITChartData(data, 'wind_direction');
            itwindspeedData = _parseITChartData(data, 'wind_speed');
            temperatureData = [];
            humidityData = [];
            lightIntensityData = [];
            windSpeedData = [];
            rainLevelData = [];
            solarIrradianceData = [];
            chlorineData = [];

            // Assign _lastWindDirection from the latest item
            if (data.containsKey('items') &&
                data['items'] is List &&
                data['items'].isNotEmpty) {
              var lastItem = data['items'].last;

              _lastwinddirection =
                  lastItem['wind_direction']?.toString() ?? '0';
            } else {
              _lastwinddirection = '0';
            }
            rows = [
              [
                "Timestamp",
                "Temperature",
                "Pressure ",
                "Humidity",
                "Radiation",
                "Visibility",
                "Wind Direction",
                "Wind Speed",
                "Rain Level"
              ],
              for (int i = 0; i < ittempData.length; i++)
                [
                  formatter.format(ittempData[i].timestamp),
                  ittempData[i].value,
                  itpressureData[i].value,
                  ithumidityData[i].value,
                  itradiationData[i].value,
                  itvisibilityData[i].value,
                  itwinddirectionData[i].value,
                  itwindspeedData[i].value,
                  itrainData[i].value,
                ]
            ];
          });
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('WS')) {
          setState(() {
            temppData = _parsewaterChartData(data, 'Temperature');
            electrodeSignalData =
                _parsewaterChartData(data, 'Electrode_signal');
            residualchlorineData = _parsewaterChartData(data, 'Chlorine_value');
            hypochlorousData = _parsewaterChartData(data, 'Hypochlorous_value');

            rows = [
              [
                "Timestamp",
                "Temperature",
                "Electrode Signal ",
                "Chlorine",
                "HypochlorouS",
              ],
              for (int i = 0; i < temppData.length; i++)
                [
                  formatter.format(temppData[i].timestamp),
                  temppData[i].value,
                  electrodeSignalData[i].value,
                  residualchlorineData[i].value,
                  hypochlorousData[i].value,
                ]
            ];
          });
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('DO')) {
          setState(() {
            ttempData = _parsedoChartData(data, 'Temperature');
            dovaluedata = _parsedoChartData(data, 'DO Value');
            dopercentagedata = _parsedoChartData(data, 'DO Percentage');

            temperatureData = [];
            humidityData = [];
            lightIntensityData = [];
            windSpeedData = [];
            rainLevelData = [];
            solarIrradianceData = [];
            chlorineData = [];
            tempData = [];
            tdsData = [];
            codData = [];
            bodData = [];
            pHData = [];
            doData = [];
            ecData = [];
            temmppData = [];
            humidityyData = [];
            lightIntensityData = [];
            windSpeeddData = [];

            rows = [
              [
                "Timestamp",
                "Temperature",
                "DO Value ",
                "DO Percentage",
              ],
              for (int i = 0; i < ttempData.length; i++)
                [
                  formatter.format(ttempData[i].timestamp),
                  ttempData[i].value,
                  dovaluedata[i].value,
                  dopercentagedata[i].value,
                ]
            ];
          });
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('TH')) {
          setState(() {
            temperattureData = _parsethChartData(data, 'Temperature');
            humidittyData = _parsethChartData(data, 'Humidity');

            temperatureData = [];
            humidityData = [];
            lightIntensityData = [];
            windSpeedData = [];
            rainLevelData = [];
            solarIrradianceData = [];
            chlorineData = [];
            tempData = [];
            tdsData = [];
            codData = [];
            bodData = [];
            pHData = [];
            doData = [];
            ecData = [];
            temmppData = [];
            humidityyData = [];
            lightIntensityData = [];
            windSpeeddData = [];

            rows = [
              [
                "Timestamp",
                "Temperature",
                "Humidity ",
              ],
              for (int i = 0; i < temperattureData.length; i++)
                [
                  formatter.format(temperattureData[i].timestamp),
                  temperattureData[i].value,
                  humidittyData[i].value,
                ]
            ];
          });
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('NH')) {
          setState(() {
            ammoniaData = _parseammoniaChartData(data, 'AmmoniaPPM');
            temperaturedata = _parseammoniaChartData(data, 'Temperature');
            humiditydata = _parseammoniaChartData(data, 'Humidity');

            temperatureData = [];
            humidityData = [];
            lightIntensityData = [];
            windSpeedData = [];
            rainLevelData = [];
            solarIrradianceData = [];
            chlorineData = [];
            electrodeSignalData = [];
            hypochlorousData = [];
            temppData = [];
            residualchlorineData = [];
            tempData = [];
            tdsData = [];
            codData = [];
            bodData = [];
            pHData = [];
            doData = [];
            ecData = [];
            temmppData = [];
            humidityyData = [];
            lightIntensityData = [];
            windSpeeddData = [];
            ttempData = [];
            dovaluedata = [];
            dopercentagedata = [];
            temperaturData = [];
            humData = [];
            luxData = [];
            coddata = [];
            boddata = [];
            phdata = [];
            temperattureData = [];
            humidittyData = [];

            rows = [
              [
                "Timestamp",
                "Ammonia",
                "Temperature",
                "Humidity ",
              ],
              for (int i = 0; i < ammoniaData.length; i++)
                [
                  formatter.format(ammoniaData[i].timestamp),
                  ammoniaData[i].value,
                  temperaturedata[i].value,
                  humiditydata[i].value,
                ]
            ];
          });
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('WF')) {
          setState(() {
            wfAverageTemperatureData =
                _parsewfChartData(data, 'Average_Temperature');
            wfrainfallData =
                _parsewfChartData(data, 'Rainfall_Daily_Comulative');

            rows = [
              [
                "Time_Stamp",
                "Average_Temperature",
                "Rainfall_Daily_Comulative"
              ],
              for (int i = 0; i < wfAverageTemperatureData.length; i++)
                [
                  formatter.format(wfAverageTemperatureData[i].timestamp),
                  wfAverageTemperatureData[i].value,
                  wfrainfallData[i].value,
                ]
            ];
          });
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('TE')) {
          setState(() {
            temperaturData = _parsesensorChartData(data, 'Temperature');
            humData = _parsesensorChartData(data, 'Humidity');

            temperatureData = [];
            humidityData = [];
            lightIntensityData = [];
            windSpeedData = [];
            rainLevelData = [];
            solarIrradianceData = [];
            chlorineData = [];
            tempData = [];
            tdsData = [];
            codData = [];
            bodData = [];
            pHData = [];
            doData = [];
            ecData = [];
            temmppData = [];
            humidityyData = [];
            lightIntensityData = [];
            windSpeeddData = [];

            if (data['sensor_data_items'].isNotEmpty) {
              lastRSSI_Value =
                  data['sensor_data_items'].last['RSSI_Value']?.toString() ??
                      'Unknown';
            }

            rows = [
              [
                "Timestamp",
                "Temperature",
                "Humidity",
              ],
              for (int i = 0; i < temperaturData.length; i++)
                [
                  formatter.format(temperaturData[i].timestamp),
                  temperaturData[i].value,
                  humData[i].value,
                ]
            ];
          });
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('LU')) {
          setState(() {
            luxData = _parsesensorChartData(data, 'LUX');

            temperatureData = [];
            humidityData = [];
            lightIntensityData = [];
            windSpeedData = [];
            rainLevelData = [];
            solarIrradianceData = [];
            chlorineData = [];
            tempData = [];
            tdsData = [];
            codData = [];
            bodData = [];
            pHData = [];
            doData = [];
            ecData = [];
            temmppData = [];
            humidityyData = [];
            lightIntensityData = [];
            windSpeeddData = [];

            rows = [
              [
                "Timestamp",
                "LUX",
              ],
              for (int i = 0; i < luxData.length; i++)
                [
                  formatter.format(luxData[i].timestamp),
                  luxData[i].value,
                ]
            ];
          });
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('FS')) {
          setState(() {
            fstempData = _parsefsChartData(data, 'temperature');
            fspressureData = _parsefsChartData(data, 'pressure');
            fshumidityData = _parsefsChartData(data, 'humidity');
            fsradiationData = _parsefsChartData(data, 'radiation');
            fsrainData = [];

            for (var item in data['items']) {
              DateTime ts = formatter.parse(item['timestamp']);
              String day = DateFormat('yyyy-MM-dd').format(ts);

              double rain =
                  double.tryParse(item['rain_level'].toString()) ?? 0.0;

              if (_fsLastRainDate != day) {
                // New day starts -> reset baseline
                _fsLastRainDate = day;
                _fsDailyRainBaseline = rain;
              }

              double rainDisplay = rain - (_fsDailyRainBaseline ?? rain);

              // Round to 2 decimal places
              rainDisplay = double.parse(rainDisplay.toStringAsFixed(2));

              fsrainData.add(ChartData(timestamp: ts, value: rainDisplay));
            }

            fswinddirectionData = _parsefsChartData(data, 'wind_direction');
            fswindspeedData = _parsefsChartData(data, 'wind_speed');

            if (data.containsKey('items') &&
                data['items'] is List &&
                data['items'].isNotEmpty) {
              var lastItem = data['items'].last;

              var batteryVoltage = lastItem['battery_voltage'];
              if (batteryVoltage != null) {
                _lastfsBattery =
                    double.tryParse(batteryVoltage.toString()) ?? 0.0;
              } else {
                _lastfsBattery = 0;
              }
            }

            // Prepare data for CSV
            rows = [
              [
                "Timestamp",
                "Temperature",
                "Pressure ",
                "Relative Humidity",
                "Radiation",
                "Wind Speed",
                "Wind Direction",
                "Rain Level"
              ],
              for (int i = 0; i < fstempData.length; i++)
                [
                  formatter.format(fstempData[i].timestamp),
                  fstempData[i].value,
                  fspressureData[i].value,
                  fshumidityData[i].value,
                  fsradiationData[i].value,
                  fswindspeedData[i].value,
                  fswinddirectionData[i].value,
                  fsrainData[i].value,
                ]
            ];
          });
          // Fetch device details specifically for Weather data
          await _fetchDeviceDetails();
        } else if (widget.deviceName.startsWith('WD')) {
          setState(() {
            temperatureData = _parseChartData(data, 'Temperature');
            humidityData = _parseChartData(data, 'Humidity');
            lightIntensityData = _parseChartData(data, 'LightIntensity');
            windSpeedData = _parseChartData(data, 'WindSpeed');
            rainDifferenceData = _parseRainDifferenceData(data);
            solarIrradianceData = _parseChartData(data, 'SolarIrradiance');

            chlorineData = [];
            tempData = [];
            tdsData = [];
            codData = [];
            bodData = [];
            pHData = [];
            doData = [];
            ecData = [];

            //Extract the last wind direction from the data
            if (data['weather_items'].isNotEmpty) {
              lastWindDirection = data['weather_items'].last['WindDirection'];
              lastBatteryPercentage =
                  data['weather_items'].last['BatteryPercentage'];
            }

            // Prepare data for CSV
            rows = [
              [
                "Timestamp",
                "Temperature",
                "Humidity",
                "LightIntensity",
                "SolarIrradiance",
              ],
              for (int i = 0; i < temperatureData.length; i++)
                [
                  formatter.format(temperatureData[i].timestamp),
                  temperatureData[i].value,
                  humidityData[i].value,
                  lightIntensityData[i].value,
                  solarIrradianceData[i].value,
                ]
            ];
          });
          // Fetch device details specifically for Weather data
          await _fetchDeviceDetails();
        } else {
          setState(() {
            rfdData = _parserainChartData(data, 'RFD');
            rfsData = _parserainChartData(data, 'RFS');

            temperatureData = [];
            humidityData = [];
            lightIntensityData = [];
            windSpeedData = [];
            rainLevelData = [];
            solarIrradianceData = [];
            chlorineData = [];
            tempData = [];
            tdsData = [];
            codData = [];
            bodData = [];
            pHData = [];
            doData = [];
            ecData = [];
            temmppData = [];
            humidityyData = [];
            lightIntensityData = [];
            windSpeeddData = [];

            // Update current chlorine value
            if (rfdData.isNotEmpty) {
              _currentrfdValue = rfdData.last.value.toStringAsFixed(2);
            }
          });
          await _fetchDeviceDetails();
        }

        // Store CSV rows for download later
        setState(() {
          // Only set _csvRows for sensors other than SM and CF
          if (!widget.deviceName.startsWith('SM') &&
              !widget.deviceName.startsWith('CF') &&
              !widget.deviceName.startsWith('VD') &&
              !widget.deviceName.startsWith('CP') &&
              !widget.deviceName.startsWith('NA') &&
              !widget.deviceName.startsWith('KJ') &&
              !widget.deviceName.startsWith('MY') &&
              !widget.deviceName.startsWith('SV')) {
            _csvRows = rows;
          }
          _lastWindDirection =
              lastWindDirection; // Store the last wind direction
          _lastBatteryPercentage = lastBatteryPercentage;
          _lastRSSI_Value = lastRSSI_Value;
          // _lastwinddirection = lastwinddirection;

          if (_csvRows.isEmpty) {
          } else {}
        });
      }
    } catch (e) {
      setState(() {});
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void downloadCSV(BuildContext context, {DateTimeRange? range}) async {
    List<List<dynamic>> csvRows;

    if (widget.deviceName.startsWith('SM')) {
      if (smParametersData.isEmpty) {
        csvRows = [
          ['Timestamp', 'Message'],
          ['', 'No data available']
        ];
      } else {
        List<String> headers = ['Timestamp'];
        headers.addAll(smParametersData.keys);

        List<List<dynamic>> dataRows = [];
        Set<DateTime> timestamps = {};
        smParametersData.values.forEach((dataList) {
          dataList.forEach((data) => timestamps.add(data.timestamp));
        });
        List<DateTime> sortedTimestamps = timestamps.toList()..sort();

        for (var timestamp in sortedTimestamps) {
          List<dynamic> row = [formatter.format(timestamp)];
          for (var key in smParametersData.keys) {
            var dataList = smParametersData[key]!;
            var matchingData = dataList.firstWhere(
              (data) => data.timestamp == timestamp,
              orElse: () => ChartData(timestamp: timestamp, value: 0.0),
            );
            row.add(matchingData.value ?? '');
          }
          dataRows.add(row);
        }

        csvRows = [headers, ...dataRows];
      }
    } else if (widget.deviceName.startsWith('CF')) {
      if (cfParametersData.isEmpty) {
        csvRows = [
          ['Timestamp', 'Message'],
          ['', 'No data available']
        ];
      } else {
        List<String> headers = ['Timestamp'];
        headers.addAll(cfParametersData.keys);

        List<List<dynamic>> dataRows = [];
        Set<DateTime> timestamps = {};
        cfParametersData.values.forEach((dataList) {
          dataList.forEach((data) => timestamps.add(data.timestamp));
        });
        List<DateTime> sortedTimestamps = timestamps.toList()..sort();

        for (var timestamp in sortedTimestamps) {
          List<dynamic> row = [formatter.format(timestamp)];
          for (var key in cfParametersData.keys) {
            var dataList = cfParametersData[key]!;
            var matchingData = dataList.firstWhere(
              (data) => data.timestamp == timestamp,
              orElse: () => ChartData(timestamp: timestamp, value: 0.0),
            );
            row.add(matchingData.value ?? '');
          }
          dataRows.add(row);
        }

        csvRows = [headers, ...dataRows];
      }
    } else if (widget.deviceName.startsWith('CP')) {
      if (csParametersData.isEmpty) {
        csvRows = [
          ['Timestamp', 'Message'],
          ['', 'No data available']
        ];
      } else {
        List<String> headers = ['Timestamp'];
        headers.addAll(csParametersData.keys);

        List<List<dynamic>> dataRows = [];
        Set<DateTime> timestamps = {};
        csParametersData.values.forEach((dataList) {
          dataList.forEach((data) => timestamps.add(data.timestamp));
        });
        List<DateTime> sortedTimestamps = timestamps.toList()..sort();

        for (var timestamp in sortedTimestamps) {
          List<dynamic> row = [formatter.format(timestamp)];
          for (var key in csParametersData.keys) {
            var dataList = csParametersData[key]!;
            var matchingData = dataList.firstWhere(
              (data) => data.timestamp == timestamp,
              orElse: () => ChartData(timestamp: timestamp, value: 0.0),
            );
            row.add(matchingData.value ?? '');
          }
          dataRows.add(row);
        }

        csvRows = [headers, ...dataRows];
      }
    } else if (widget.deviceName.startsWith('NA')) {
      if (NARLParametersData.isEmpty) {
        csvRows = [
          ['Timestamp', 'Message'],
          ['', 'No data available']
        ];
      } else {
        List<String> headers = ['Timestamp'];
        headers.addAll(NARLParametersData.keys);

        List<List<dynamic>> dataRows = [];
        Set<DateTime> timestamps = {};
        NARLParametersData.values.forEach((dataList) {
          dataList.forEach((data) => timestamps.add(data.timestamp));
        });
        List<DateTime> sortedTimestamps = timestamps.toList()..sort();

        for (var timestamp in sortedTimestamps) {
          List<dynamic> row = [formatter.format(timestamp)];
          for (var key in NARLParametersData.keys) {
            var dataList = NARLParametersData[key]!;
            var matchingData = dataList.firstWhere(
              (data) => data.timestamp == timestamp,
              orElse: () => ChartData(timestamp: timestamp, value: 0.0),
            );
            row.add(matchingData.value ?? '');
          }
          dataRows.add(row);
        }

        csvRows = [headers, ...dataRows];
      }
    } else if (widget.deviceName.startsWith('KJ')) {
      if (KJParametersData.isEmpty) {
        csvRows = [
          ['Timestamp', 'Message'],
          ['', 'No data available']
        ];
      } else {
        List<String> headers = ['Timestamp'];
        headers.addAll(KJParametersData.keys);

        List<List<dynamic>> dataRows = [];
        Set<DateTime> timestamps = {};
        KJParametersData.values.forEach((dataList) {
          dataList.forEach((data) => timestamps.add(data.timestamp));
        });
        List<DateTime> sortedTimestamps = timestamps.toList()..sort();

        for (var timestamp in sortedTimestamps) {
          List<dynamic> row = [formatter.format(timestamp)];
          for (var key in KJParametersData.keys) {
            var dataList = KJParametersData[key]!;
            var matchingData = dataList.firstWhere(
              (data) => data.timestamp == timestamp,
              orElse: () => ChartData(timestamp: timestamp, value: 0.0),
            );
            row.add(matchingData.value ?? '');
          }
          dataRows.add(row);
        }

        csvRows = [headers, ...dataRows];
      }
    } else if (widget.deviceName.startsWith('MY')) {
      if (MYParametersData.isEmpty) {
        csvRows = [
          ['Timestamp', 'Message'],
          ['', 'No data available']
        ];
      } else {
        List<String> headers = ['Timestamp'];
        headers.addAll(MYParametersData.keys);

        List<List<dynamic>> dataRows = [];
        Set<DateTime> timestamps = {};
        MYParametersData.values.forEach((dataList) {
          dataList.forEach((data) => timestamps.add(data.timestamp));
        });
        List<DateTime> sortedTimestamps = timestamps.toList()..sort();

        for (var timestamp in sortedTimestamps) {
          List<dynamic> row = [formatter.format(timestamp)];
          for (var key in MYParametersData.keys) {
            var dataList = MYParametersData[key]!;
            var matchingData = dataList.firstWhere(
              (data) => data.timestamp == timestamp,
              orElse: () => ChartData(timestamp: timestamp, value: 0.0),
            );
            row.add(matchingData.value ?? '');
          }
          dataRows.add(row);
        }

        csvRows = [headers, ...dataRows];
      }
    } else if (widget.deviceName.startsWith('SV')) {
      if (svParametersData.isEmpty) {
        csvRows = [
          ['Timestamp', 'Message'],
          ['', 'No data available']
        ];
      } else {
        List<String> headers = ['Timestamp'];
        headers.addAll(svParametersData.keys);

        List<List<dynamic>> dataRows = [];
        Set<DateTime> timestamps = {};
        svParametersData.values.forEach((dataList) {
          dataList.forEach((data) => timestamps.add(data.timestamp));
        });
        List<DateTime> sortedTimestamps = timestamps.toList()..sort();

        for (var timestamp in sortedTimestamps) {
          List<dynamic> row = [formatter.format(timestamp)];
          for (var key in svParametersData.keys) {
            var dataList = svParametersData[key]!;
            var matchingData = dataList.firstWhere(
              (data) => data.timestamp == timestamp,
              orElse: () => ChartData(timestamp: timestamp, value: 0.0),
            );
            row.add(matchingData.value ?? '');
          }
          dataRows.add(row);
        }

        csvRows = [headers, ...dataRows];
      }
    } else if (widget.deviceName.startsWith('WD211') ||
        widget.deviceName.startsWith('WD511')) {
      if (rfdData.isEmpty || rfsData.isEmpty) {
        csvRows = [
          ['Timestamp', 'Message'],
          ['', 'No data available']
        ];
      } else {
        csvRows = [
          ["Timestamp", "RFD ", "RFS "],
          for (int i = 0; i < rfdData.length; i++)
            [
              formatter.format(rfdData[i].timestamp),
              rfdData[i].value,
              rfsData[i].value,
            ]
        ];
      }
    } else {
      // Use _csvRows for other sensors (CL, BD, WQ, IT, WS, DO, TH, NH, TE, LU, FS, WD, etc.)
      if (_csvRows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No data available for download.")),
        );
        return;
      }
      csvRows = _csvRows;
    }

    String csvData = const ListToCsvConverter().convert(csvRows);
    String fileName = _generateFileName();

    if (kIsWeb) {
      final blob = html.Blob([csvData], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Downloading"),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      try {
        await saveCSVFile(csvData, fileName);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error downloading: $e")),
        );
      }
    }
  }

  String _generateFileName() {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return 'SensorData_$timestamp.csv';
  }

  Future<void> saveCSVFile(String csvData, String fileName) async {
    try {
      // Get the Downloads directory.
      final downloadsDirectory = Directory('/storage/emulated/0/Download');
      if (downloadsDirectory.existsSync()) {
        final filePath = '${downloadsDirectory.path}/$fileName';
        final file = File(filePath);

        await file.writeAsString(csvData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("File downloaded to $filePath"),
          ),
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

  Future<void> _fetchRainForecastingData() async {
    try {
      final response = await http.get(Uri.parse(
          'https://w6dzlucugb.execute-api.us-east-1.amazonaws.com/default/CloudSense_rain_data_api?DeviceId=211'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _totalRainLast24Hours =
              data['TotalRainLast24Hours']?.toString() ?? '0.00 mm';
          _mostRecentHourRain =
              data['MostRecentHourRain']?.toString() ?? '0.00 mm';
        });
      } else {
        throw Exception('Failed to load rain forecasting data');
      }
    } catch (e) {
      print('Error fetching rain forecasting data: $e');
    }
  }

  Future<void> _fetchRainForecastData() async {
    try {
      final response = await http.get(Uri.parse(
          'https://w6dzlucugb.execute-api.us-east-1.amazonaws.com/default/CloudSense_rain_data_api?DeviceId=511'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _totalRainLast24Hours =
              data['TotalRainLast24Hours']?.toString() ?? '0.00 mm';
          _mostRecentHourRain =
              data['MostRecentHourRain']?.toString() ?? '0.00 mm';
        });
      } else {
        throw Exception('Failed to load rain forecasting data');
      }
    } catch (e) {
      print('Error fetching rain forecasting data: $e');
    }
  }

  Future<void> _showDownloadOptionsDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Download Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  downloadCSV(context);
                },
                child: const Text('Download for Selected Range'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => CsvDownloader(
                              deviceName: widget.deviceName,
                            )),
                  );
                },
                child: const Text('Download for Custom Range'),
              ),
            ],
          ),
        );
      },
    );
  }

  List<ChartData> _parseBDChartData(Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['items'] ?? [];
    return items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }
      return ChartData(
        timestamp: _parseBDDate(item['human_time']),
        value: item[type] != null
            ? double.tryParse(item[type].toString()) ?? 0.0
            : 0.0,
      );
    }).toList();
  }

  List<ChartData> _parseChartData(Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['weather_items'] ?? [];
    return items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }

      // Parse the value based on the `type`
      double value;
      if (type == 'RainLevel' && item[type] is String) {
        // Remove unit from RainLevel string and parse the numeric part
        String rainLevelStr =
            item[type].split(' ')[0]; // Extract "2.51" from "2.51 mm"
        value = double.tryParse(rainLevelStr) ?? 0.0;
      } else {
        // For other types, parse directly
        value = double.tryParse(item[type].toString()) ?? 0.0;
      }

      return ChartData(
        timestamp: _parseDate(item['HumanTime']),
        value: value,
      );
    }).toList();
  }

  List<ChartData> _parseRainDifferenceData(Map<String, dynamic> data) {
    final List<dynamic> items = data['rain_hourly_items'] ?? [];

    return items.map((item) {
      if (item == null) {
        return ChartData(
            timestamp: DateTime.now(), value: 0.0); // Default value
      }

      // Extract and parse RainDifference value, removing unit "mm"
      String rainDifferenceStr = item['RainDifference'].split(' ')[0];
      double rainDifferenceValue = double.tryParse(rainDifferenceStr) ?? 0.0;

      return ChartData(
        timestamp: DateTime.parse(item['HourTimestamp']),
        value: rainDifferenceValue,
      );
    }).toList();
  }

  List<ChartData> _parsewaterChartData(Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['items'] ?? [];
    final result = items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }
      String valueStr = item[type]?.toString().split(' ')[0] ?? '0.0';
      double value = double.tryParse(valueStr) ?? 0.0;
      DateTime timestamp = _parsewaterDate(item['HumanTime']);

      return ChartData(
        timestamp: timestamp,
        value: value,
      );
    }).toList();

    return result;
  }

  List<ChartData> _parseITChartData(Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['items'] ?? [];
    return items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }
      return ChartData(
        timestamp: _parseITDate(item['human_time']),
        value: item[type] != null
            ? double.tryParse(item[type].toString()) ?? 0.0
            : 0.0,
      );
    }).toList();
  }

  List<ChartData> _parsefsChartData(Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['items'] ?? [];
    return items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }
      return ChartData(
        timestamp: _parsefsDate(item['timestamp']),
        value: item[type] != null
            ? double.tryParse(item[type].toString()) ?? 0.0
            : 0.0,
      );
    }).toList();
  }

  Map<String, List<ChartData>> _parseSMParametersData(
      Map<String, dynamic> data) {
    final List<dynamic> items = data['items'] ?? [];
    Map<String, List<ChartData>> parametersData = {};

    if (items.isEmpty) {
      return parametersData;
    }

    // Collect all possible parameter keys from the first item, excluding non-numeric fields
    final sampleItem = items.first;
    final parameterKeys = sampleItem.keys.where((key) {
      // Exclude non-numeric fields like TimeStamp, TimeStampFormatted, Topic, IMEINumber, DeviceId
      return ![
        'TimeStamp',
        'TimeStampFormatted',
        'Topic',
        'IMEINumber',
        'DeviceId'
      ].contains(key);
    }).toList();

    // Initialize ChartData lists for each parameter
    for (var key in parameterKeys) {
      parametersData[key] = [];
    }

    // Parse data for each item
    for (var item in items) {
      if (item == null) continue;
      DateTime timestamp = _parseSMDate(item['TimeStamp']);
      for (var key in parameterKeys) {
        if (item[key] != null) {
          // Only include non-null values
          double value = double.tryParse(item[key].toString()) ?? 0.0;
          parametersData[key]!
              .add(ChartData(timestamp: timestamp, value: value));
        }
      }
    }
    // Update _lastsmBattery with the latest BatteryVoltage (from the last item)
    for (var item in items.reversed) {
      if (item != null && item['BatteryVoltage'] != null) {
        _lastsmBattery =
            double.tryParse(item['BatteryVoltage'].toString()) ?? 0.0;

        break; // Exit after finding the latest non-null value
      }
    }

    // Remove parameters with empty lists (i.e., all values were null)
    parametersData.removeWhere((key, value) => value.isEmpty);

    return parametersData;
  }

  Map<String, List<ChartData>> _parseCFParametersData(
      Map<String, dynamic> data) {
    final List<dynamic> items = data['items'] ?? [];
    Map<String, List<ChartData>> parametersData = {};

    if (items.isEmpty) {
      return parametersData;
    }

    // Collect all possible parameter keys from the first item, excluding non-numeric fields
    final sampleItem = items.first;
    final parameterKeys = sampleItem.keys.where((key) {
      // Exclude non-numeric fields like TimeStamp, Topic, IMEINumber, DeviceId, Latitude, Longitude
      return ![
        'TimeStamp',
        'Topic',
        'IMEINumber',
        'DeviceId',
      ].contains(key);
    }).toList();

    // Initialize ChartData lists for each parameter
    for (var key in parameterKeys) {
      parametersData[key] = [];
    }

    // Parse data for each item
    for (var item in items) {
      if (item == null) continue;
      DateTime timestamp = _parseCFDate(item['TimeStamp']);
      for (var key in parameterKeys) {
        if (item[key] != null) {
          // Only include non-null values
          double value = double.tryParse(item[key].toString()) ?? 0.0;
          parametersData[key]!
              .add(ChartData(timestamp: timestamp, value: value));
        }
      }
    }

    // Update _lastcfBattery with the latest BatteryVoltage (from the last item)
    for (var item in items.reversed) {
      if (item != null && item['BatteryVoltage'] != null) {
        _lastcfBattery =
            double.tryParse(item['BatteryVoltage'].toString()) ?? 0.0;

        break; // Exit after finding the latest non-null value
      }
    }

    // Remove parameters with empty lists (i.e., all values were null)
    parametersData.removeWhere((key, value) => value.isEmpty);

    return parametersData;
  }

  Map<String, List<ChartData>> _parseVDParametersData(
      Map<String, dynamic> data) {
    final List<dynamic> items = data['items'] ?? [];
    Map<String, List<ChartData>> parametersData = {};

    if (items.isEmpty) {
      return parametersData;
    }

    // Collect all possible parameter keys from the first item, excluding non-numeric fields
    final sampleItem = items.first;
    final parameterKeys = sampleItem.keys.where((key) {
      // Exclude non-numeric fields like TimeStamp, Topic, IMEINumber, DeviceId, Latitude, Longitude
      return ![
        'TimeStamp',
        'Topic',
        'IMEINumber',
        'DeviceId',
        'Latitude',
        'Longitude'
      ].contains(key);
    }).toList();

    // Initialize ChartData lists for each parameter
    for (var key in parameterKeys) {
      parametersData[key] = [];
    }

    // Parse data for each item
    for (var item in items) {
      if (item == null) continue;
      DateTime timestamp = _parseVDDate(item['TimeStamp']);
      for (var key in parameterKeys) {
        if (item[key] != null) {
          // Only include non-null values
          double value = double.tryParse(item[key].toString()) ?? 0.0;
          parametersData[key]!
              .add(ChartData(timestamp: timestamp, value: value));
        }
      }
    }

    // Update _lastcfBattery with the latest BatteryVoltage (from the last item)
    for (var item in items.reversed) {
      if (item != null && item['BatteryVoltage'] != null) {
        _lastvdBattery =
            double.tryParse(item['BatteryVoltage'].toString()) ?? 0.0;

        break; // Exit after finding the latest non-null value
      }
    }

    // Remove parameters with empty lists (i.e., all values were null)
    parametersData.removeWhere((key, value) => value.isEmpty);

    return parametersData;
  }

  Map<String, List<ChartData>> _parseKDParametersData(
      Map<String, dynamic> data) {
    final List<dynamic> items = data['items'] ?? [];
    Map<String, List<ChartData>> parametersData = {};

    if (items.isEmpty) {
      return parametersData;
    }

    // Collect all possible parameter keys from the first item, excluding non-numeric fields
    final sampleItem = items.first;
    final parameterKeys = sampleItem.keys.where((key) {
      // Exclude non-numeric fields like TimeStamp, Topic, IMEINumber, DeviceId, Latitude, Longitude
      return ![
        'TimeStamp',
        'Topic',
        'IMEINumber',
        'DeviceId',
        'Latitude',
        'Longitude'
      ].contains(key);
    }).toList();

    // Initialize ChartData lists for each parameter
    for (var key in parameterKeys) {
      parametersData[key] = [];
    }

    // Parse data for each item
    for (var item in items) {
      if (item == null) continue;
      DateTime timestamp = _parseKDDate(item['TimeStamp']);
      for (var key in parameterKeys) {
        if (item[key] != null) {
          // Only include non-null values
          double value = double.tryParse(item[key].toString()) ?? 0.0;
          parametersData[key]!
              .add(ChartData(timestamp: timestamp, value: value));
        }
      }
    }

    // Update _lastkdBattery with the latest BatteryVoltage (from the last item)
    for (var item in items.reversed) {
      if (item != null && item['BatteryVoltage'] != null) {
        _lastkdBattery =
            double.tryParse(item['BatteryVoltage'].toString()) ?? 0.0;

        break; // Exit after finding the latest non-null value
      }
    }

    // Remove parameters with empty lists (i.e., all values were null)
    parametersData.removeWhere((key, value) => value.isEmpty);

    return parametersData;
  }

  Map<String, List<ChartData>> _parseNARLParametersData(
      Map<String, dynamic> data) {
    final List<dynamic> items = data['items'] ?? [];
    Map<String, List<ChartData>> parametersData = {};

    if (items.isEmpty) {
      return parametersData;
    }

    // Collect all possible parameter keys from the first item, excluding non-numeric fields
    final sampleItem = items.first;
    final parameterKeys = sampleItem.keys.where((key) {
      // Exclude non-numeric fields like TimeStamp, Topic, IMEINumber, DeviceId, Latitude, Longitude
      return ![
        'TimeStamp',
        'Topic',
        'IMEINumber',
        'DeviceId',
      ].contains(key);
    }).toList();

    // Initialize ChartData lists for each parameter
    for (var key in parameterKeys) {
      parametersData[key] = [];
    }

    // Parse data for each item
    for (var item in items) {
      if (item == null) continue;
      DateTime timestamp = _parseNARLDate(item['TimeStamp']);
      for (var key in parameterKeys) {
        if (item[key] != null) {
          // Only include non-null values
          double value = double.tryParse(item[key].toString()) ?? 0.0;
          parametersData[key]!
              .add(ChartData(timestamp: timestamp, value: value));
        }
      }
    }

    // Update _lastkdBattery with the latest BatteryVoltage (from the last item)
    for (var item in items.reversed) {
      if (item != null && item['BatteryVoltage'] != null) {
        _lastNARLBattery =
            double.tryParse(item['BatteryVoltage'].toString()) ?? 0.0;

        break; // Exit after finding the latest non-null value
      }
    }

    // Remove parameters with empty lists (i.e., all values were null)
    parametersData.removeWhere((key, value) => value.isEmpty);

    return parametersData;
  }

  Map<String, List<ChartData>> _parseKJParametersData(
      Map<String, dynamic> data) {
    final List<dynamic> items = data['items'] ?? [];
    Map<String, List<ChartData>> parametersData = {};

    if (items.isEmpty) {
      return parametersData;
    }

    // Collect all possible parameter keys from the first item, excluding non-numeric fields
    final sampleItem = items.first;
    final parameterKeys = sampleItem.keys.where((key) {
      // Exclude non-numeric fields like TimeStamp, Topic, IMEINumber, DeviceId, Latitude, Longitude
      return ![
        'TimeStamp',
        'Topic',
        'IMEINumber',
        'DeviceId',
      ].contains(key);
    }).toList();

    // Initialize ChartData lists for each parameter
    for (var key in parameterKeys) {
      parametersData[key] = [];
    }

    // Parse data for each item
    for (var item in items) {
      if (item == null) continue;
      DateTime timestamp = _parseKJDate(item['TimeStamp']);
      for (var key in parameterKeys) {
        if (item[key] != null) {
          // Only include non-null values
          double value = double.tryParse(item[key].toString()) ?? 0.0;
          parametersData[key]!
              .add(ChartData(timestamp: timestamp, value: value));
        }
      }
    }

    // Update _lastkdBattery with the latest BatteryVoltage (from the last item)
    for (var item in items.reversed) {
      if (item != null && item['BatteryVoltage'] != null) {
        _lastKJBattery =
            double.tryParse(item['BatteryVoltage'].toString()) ?? 0.0;

        break; // Exit after finding the latest non-null value
      }
    }

    // Remove parameters with empty lists (i.e., all values were null)
    parametersData.removeWhere((key, value) => value.isEmpty);

    return parametersData;
  }

  Map<String, List<ChartData>> _parseMYParametersData(
      Map<String, dynamic> data) {
    final List<dynamic> items = data['items'] ?? [];
    Map<String, List<ChartData>> parametersData = {};

    if (items.isEmpty) {
      return parametersData;
    }

    // Collect all possible parameter keys from the first item, excluding non-numeric fields
    final sampleItem = items.first;
    final parameterKeys = sampleItem.keys.where((key) {
      // Exclude non-numeric fields like TimeStamp, Topic, IMEINumber, DeviceId, Latitude, Longitude
      return ![
        'TimeStamp',
        'Topic',
        'IMEINumber',
        'DeviceId',
      ].contains(key);
    }).toList();

    // Initialize ChartData lists for each parameter
    for (var key in parameterKeys) {
      parametersData[key] = [];
    }

    // Parse data for each item
    for (var item in items) {
      if (item == null) continue;
      DateTime timestamp = _parseMYDate(item['TimeStamp']);
      for (var key in parameterKeys) {
        if (item[key] != null) {
          // Only include non-null values
          double value = double.tryParse(item[key].toString()) ?? 0.0;
          parametersData[key]!
              .add(ChartData(timestamp: timestamp, value: value));
        }
      }
    }

    // Update _lastkdBattery with the latest BatteryVoltage (from the last item)
    for (var item in items.reversed) {
      if (item != null && item['BatteryVoltage'] != null) {
        _lastMYBattery =
            double.tryParse(item['BatteryVoltage'].toString()) ?? 0.0;

        break; // Exit after finding the latest non-null value
      }
    }

    // Remove parameters with empty lists (i.e., all values were null)
    parametersData.removeWhere((key, value) => value.isEmpty);

    return parametersData;
  }

  Map<String, List<ChartData>> _parsecsParametersData(
      Map<String, dynamic> data) {
    final List<dynamic> items = data['items'] ?? [];
    Map<String, List<ChartData>> parametersData = {};

    if (items.isEmpty) {
      return parametersData;
    }

    // Collect all possible parameter keys from the first item, excluding non-numeric fields
    final sampleItem = items.first;
    final parameterKeys = sampleItem.keys.where((key) {
      // Exclude non-numeric fields like TimeStamp, Topic, IMEINumber, DeviceId, Latitude, Longitude
      return ![
        'TimeStamp',
        'Topic',
        'IMEINumber',
        'DeviceId',
      ].contains(key);
    }).toList();

    // Initialize ChartData lists for each parameter
    for (var key in parameterKeys) {
      parametersData[key] = [];
    }

    // Parse data for each item
    for (var item in items) {
      if (item == null) continue;
      DateTime timestamp = _parsecsDate(item['TimeStamp']);
      for (var key in parameterKeys) {
        if (item[key] != null) {
          // Only include non-null values
          double value = double.tryParse(item[key].toString()) ?? 0.0;
          parametersData[key]!
              .add(ChartData(timestamp: timestamp, value: value));
        }
      }
    }

    // Update _lastkdBattery with the latest BatteryVoltage (from the last item)
    for (var item in items.reversed) {
      if (item != null && item['BatteryVoltage'] != null) {
        _lastcsBattery =
            double.tryParse(item['BatteryVoltage'].toString()) ?? 0.0;

        break; // Exit after finding the latest non-null value
      }
    }

    // Remove parameters with empty lists (i.e., all values were null)
    parametersData.removeWhere((key, value) => value.isEmpty);

    return parametersData;
  }

  Map<String, List<ChartData>> _parseSVParametersData(
      Map<String, dynamic> data) {
    final List<dynamic> items = data['items'] ?? [];
    Map<String, List<ChartData>> parametersData = {};

    if (items.isEmpty) {
      return parametersData;
    }

    // Collect all possible parameter keys from the first item, excluding non-numeric fields
    final sampleItem = items.first;
    final parameterKeys = sampleItem.keys.where((key) {
      // Exclude non-numeric fields like TimeStamp, Topic, IMEINumber, DeviceId, Latitude, Longitude
      return ![
        'TimeStamp',
        'Topic',
        'IMEINumber',
        'DeviceId',
        'Latitude',
        'Longitude'
      ].contains(key);
    }).toList();

    // Initialize ChartData lists for each parameter
    for (var key in parameterKeys) {
      parametersData[key] = [];
    }

    // Parse data for each item
    for (var item in items) {
      if (item == null) continue;
      DateTime timestamp = _parseSVDate(item['TimeStamp']);
      for (var key in parameterKeys) {
        if (item[key] != null) {
          // Only include non-null values
          double value = double.tryParse(item[key].toString()) ?? 0.0;
          parametersData[key]!
              .add(ChartData(timestamp: timestamp, value: value));
        }
      }
    }

    // Update _lastsvBattery with the latest BatteryVoltage (from the last item)
    for (var item in items.reversed) {
      if (item != null && item['BatteryVoltage'] != null) {
        _lastsvBattery =
            double.tryParse(item['BatteryVoltage'].toString()) ?? 0.0;

        break; // Exit after finding the latest non-null value
      }
    }

    // Remove parameters with empty lists (i.e., all values were null)
    parametersData.removeWhere((key, value) => value.isEmpty);

    return parametersData;
  }

  List<ChartData> _parsesensorChartData(
      Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['sensor_data_items'] ?? [];
    return items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }
      return ChartData(
        timestamp: _parsesensorDate(item['HumanTime']),
        value: item[type] != null
            ? double.tryParse(item[type].toString()) ?? 0.0
            : 0.0,
      );
    }).toList();
  }

  List<ChartData> _parsewindChartData(Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['items'] ?? [];
    return items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }
      return ChartData(
        timestamp: _parsewindDate(item['human_time']),
        value: item[type] != null
            ? double.tryParse(item[type].toString()) ?? 0.0
            : 0.0,
      );
    }).toList();
  }

  List<ChartData> _parsedoChartData(Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['items'] ?? [];
    return items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }
      return ChartData(
        timestamp: _parsedoDate(item['HumanTime']),
        value: item[type] != null
            ? double.tryParse(item[type].toString()) ?? 0.0
            : 0.0,
      );
    }).toList();
  }

  List<ChartData> _parsethChartData(Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['items'] ?? [];
    return items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }
      return ChartData(
        timestamp: _parsethDate(item['HumanTime']),
        value: item[type] != null
            ? double.tryParse(item[type].toString()) ?? 0.0
            : 0.0,
      );
    }).toList();
  }

  List<ChartData> _parseammoniaChartData(
      Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['items'] ?? [];
    return items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }
      return ChartData(
        timestamp: _parseammoniaDate(item['HumanTime']),
        value: item[type] != null
            ? double.tryParse(item[type].toString()) ?? 0.0
            : 0.0,
      );
    }).toList();
  }

  List<ChartData> _parsewfChartData(Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['items'] ?? [];
    return items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }
      return ChartData(
        timestamp: _parsewfDate(item['Time_Stamp']),
        value: item[type] != null
            ? double.tryParse(item[type].toString()) ?? 0.0
            : 0.0,
      );
    }).toList();
  }

  List<ChartData> _parseWaterChartData(Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['items'] ?? [];
    return items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }
      return ChartData(
        timestamp: _parseWaterDate(item['time_stamp']),
        value: item[type] != null
            ? double.tryParse(item[type].toString()) ?? 0.0
            : 0.0,
      );
    }).toList();
  }

  List<ChartData> _parseCBChartData(Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['items'] ?? [];
    return items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }
      return ChartData(
        timestamp: _parseCBDate(item['human_time']),
        value: item[type] != null
            ? double.tryParse(item[type].toString()) ?? 0.0
            : 0.0,
      );
    }).toList();
  }

  List<ChartData> _parserainChartData(Map<String, dynamic> data, String type) {
    final List<dynamic> items = data['items'] ?? [];
    return items.map((item) {
      if (item == null) {
        return ChartData(timestamp: DateTime.now(), value: 0.0);
      }
      return ChartData(
        timestamp: _parserainDate(item['human_time']),
        value: item[type] != null
            ? double.tryParse(item[type].toString()) ?? 0.0
            : 0.0,
      );
    }).toList();
  }

// Calculate average, min, and max values
  Map<String, List<double?>> _calculateStatistics(List<ChartData> data) {
    if (data.isEmpty) {
      return {
        // 'average': [null],
        'current': [null],
        'min': [null],
        'max': [null],
      };
    }
    // double sum = 0.0;
    double? current = data.last.value;
    double min = double.infinity;
    double max = double.negativeInfinity;

    for (var entry in data) {
      if (entry.value < min) min = entry.value;
      if (entry.value > max) max = entry.value;
    }

    return {
      'current': [current],
      'min': [min],
      'max': [max],
    };
  }

  // Create a table displaying statistics
  Widget buildStatisticsTable() {
    final tempStats = _calculateStatistics(tempData);
    final tdsStats = _calculateStatistics(tdsData);
    final codStats = _calculateStatistics(codData);
    final bodStats = _calculateStatistics(bodData);
    final pHStats = _calculateStatistics(pHData);
    final doStats = _calculateStatistics(doData);
    final ecStats = _calculateStatistics(ecData);

    double screenWidth = MediaQuery.of(context).size.width;
    double fontSize = screenWidth < 800 ? 13 : 16;
    double headerFontSize = screenWidth < 800 ? 16 : 22;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1),
          borderRadius: BorderRadius.circular(16),
          color: Colors.black.withOpacity(0.6),
        ),
        margin: EdgeInsets.all(10),
        padding: EdgeInsets.all(8),
        width: screenWidth < 800 ? double.infinity : 500,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: screenWidth < 800 ? screenWidth - 32 : 500,
            ),
            child: DataTable(
              horizontalMargin: 16,
              columnSpacing: 16,
              columns: [
                DataColumn(
                  label: Text(
                    'Parameter',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Current',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Min',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Max',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
              ],
              rows: [
                buildDataRow('Temp', tempStats, fontSize),
                buildDataRow('TDS', tdsStats, fontSize),
                buildDataRow('COD', codStats, fontSize),
                buildDataRow('BOD', bodStats, fontSize),
                buildDataRow('pH', pHStats, fontSize),
                buildDataRow('DO', doStats, fontSize),
                buildDataRow('EC', ecStats, fontSize),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DataRow buildDataRow(
      String parameter, Map<String, List<double?>> stats, double fontSize) {
    return DataRow(cells: [
      DataCell(Text(parameter,
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['current']?[0] != null
              ? stats['current']![0]!.toStringAsFixed(2)
              : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['min']?[0] != null ? stats['min']![0]!.toStringAsFixed(2) : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['max']?[0] != null ? stats['max']![0]!.toStringAsFixed(2) : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
    ]);
  }

// Calculate average, min, and max values
  Map<String, List<double?>> _calculateCBStatistics(List<ChartData> data) {
    if (data.isEmpty) {
      return {
        // 'average': [null],
        'current': [null],
        'min': [null],
        'max': [null],
      };
    }
    // double sum = 0.0;
    double? current = data.last.value;
    double min = double.infinity;
    double max = double.negativeInfinity;

    for (var entry in data) {
      if (entry.value < min) min = entry.value;
      if (entry.value > max) max = entry.value;
    }

    return {
      'current': [current],
      'min': [min],
      'max': [max],
    };
  }

  // Create a table displaying statistics
  Widget buildCBStatisticsTable() {
    final temp2Stats = _calculateCBStatistics(temp2Data);

    final cod2Stats = _calculateCBStatistics(cod2Data);
    final bod2Stats = _calculateCBStatistics(bod2Data);

    double screenWidth = MediaQuery.of(context).size.width;
    double fontSize = screenWidth < 800 ? 13 : 16;
    double headerFontSize = screenWidth < 800 ? 16 : 22;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1),
          borderRadius: BorderRadius.circular(16),
          color: Colors.black.withOpacity(0.6),
        ),
        margin: EdgeInsets.all(10),
        padding: EdgeInsets.all(8),
        width: screenWidth < 800 ? double.infinity : 500,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: screenWidth < 800 ? screenWidth - 32 : 500,
            ),
            child: DataTable(
              horizontalMargin: 16,
              columnSpacing: 16,
              columns: [
                DataColumn(
                  label: Text(
                    'Parameter',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Current',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Min',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Max',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
              ],
              rows: [
                buildCBDataRow('Temp', temp2Stats, fontSize),
                buildCBDataRow('COD', cod2Stats, fontSize),
                buildCBDataRow('BOD', bod2Stats, fontSize),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DataRow buildCBDataRow(
      String parameter, Map<String, List<double?>> stats, double fontSize) {
    return DataRow(cells: [
      DataCell(Text(parameter,
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['current']?[0] != null
              ? stats['current']![0]!.toStringAsFixed(2)
              : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['min']?[0] != null ? stats['min']![0]!.toStringAsFixed(2) : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['max']?[0] != null ? stats['max']![0]!.toStringAsFixed(2) : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
    ]);
  }

// Calculate average, min, and max values
  Map<String, List<double?>> _calculateDOStatistics(List<ChartData> data) {
    if (data.isEmpty) {
      return {
        // 'average': [null],
        'current': [null],
        'min': [null],
        'max': [null],
      };
    }
    // double sum = 0.0;
    double? current = data.last.value; // Get the most recent (current) value
    double min = double.infinity;
    double max = double.negativeInfinity;

    for (var entry in data) {
      // sum += entry.value;
      if (entry.value < min) min = entry.value;
      if (entry.value > max) max = entry.value;
    }

    // double avg = data.isNotEmpty ? sum / data.length : 0.0;
    return {
      // 'average': [avg],
      'current': [current], // Return the last (current) value
      'min': [min],
      'max': [max],
    };
  }

  // Create a table displaying statistics
  Widget buildDOStatisticsTable() {
    final ttempStats = _calculateDOStatistics(ttempData);
    final dovalueStats = _calculateDOStatistics(dovaluedata);
    final dopercentageStats = _calculateDOStatistics(dopercentagedata);

    double screenWidth = MediaQuery.of(context).size.width;
    double fontSize = screenWidth < 800 ? 13 : 16;
    double headerFontSize = screenWidth < 800 ? 16 : 22;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1),
          borderRadius: BorderRadius.circular(16),
          color: Colors.black.withOpacity(0.6),
        ),
        margin: EdgeInsets.all(10),
        padding: EdgeInsets.all(8),
        width: screenWidth < 800 ? double.infinity : 500,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: screenWidth < 800 ? screenWidth - 32 : 500,
            ),
            child: DataTable(
              horizontalMargin: 16,
              columnSpacing: 16,
              columns: [
                DataColumn(
                  label: Text(
                    'Parameter',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Recent Value',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Min',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Max',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
              ],
              rows: [
                buildDataRow('Temperature', ttempStats, fontSize),
                buildDataRow('DO Value', dovalueStats, fontSize),
                buildDataRow('DO Percentage', dopercentageStats, fontSize),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DataRow buildDODataRow(
      String parameter, Map<String, List<double?>> stats, double fontSize) {
    return DataRow(cells: [
      DataCell(Text(parameter,
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['current']?[0] != null
              ? stats['current']![0]!.toStringAsFixed(2)
              : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['min']?[0] != null ? stats['min']![0]!.toStringAsFixed(2) : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['max']?[0] != null ? stats['max']![0]!.toStringAsFixed(2) : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
    ]);
  }

  Map<String, List<double?>> _calculateWeatherStatistics(List<ChartData> data) {
    if (data.isEmpty) {
      return {
        'current': [null],
      };
    }

    double? current = data.last.value; // Get the most recent (current) value

    return {
      'current': [current], // Return the last (current) value
    };
  }

  Widget buildWeatherStatisticsTable() {
    final temperatureStats = _calculateWeatherStatistics(temperatureData);
    final humidityStats = _calculateWeatherStatistics(humidityData);
    final lightIntensityStats = _calculateWeatherStatistics(lightIntensityData);
    final solarIrradianceStats =
        _calculateWeatherStatistics(solarIrradianceData);

    double screenWidth = MediaQuery.of(context).size.width;
    double fontSize = screenWidth < 800 ? 13 : 16;
    double headerFontSize = screenWidth < 800 ? 18 : 22;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1),
          borderRadius: BorderRadius.circular(16),
          color: Colors.black.withOpacity(0.6),
        ),
        margin: EdgeInsets.all(10),
        padding: EdgeInsets.all(8),
        width: screenWidth < 800 ? double.infinity : 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Centered heading for the table
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Center(
                child: Text(
                  'Data',
                  style: TextStyle(
                    fontSize: headerFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: screenWidth < 800 ? screenWidth - 32 : 500,
                ),
                child: DataTable(
                  horizontalMargin: 16,
                  // columnSpacing: screenWidth < 700 ? 70 : 30,

                  columnSpacing: screenWidth < 362
                      ? 50
                      : screenWidth < 392
                          ? 80
                          : screenWidth < 500
                              ? 120
                              : screenWidth < 800
                                  ? 180
                                  : 70,

                  columns: [
                    DataColumn(
                      label: Text(
                        'Parameter',
                        style: TextStyle(
                            fontSize: headerFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue),
                      ),
                    ),
                    DataColumn(
                      label: Padding(
                        padding: EdgeInsets.only(
                          right: MediaQuery.of(context).size.width *
                              0.04, // Adjust padding based on screen width
                        ), // Adjust the value as needed
                        child: Text(
                          'Recent Value',
                          style: TextStyle(
                              fontSize: headerFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue),
                        ),
                      ),
                    ),
                  ],
                  rows: [
                    buildWeatherDataRow(
                        'Temperature', temperatureStats, fontSize),
                    buildWeatherDataRow('Humidity', humidityStats, fontSize),
                    buildWeatherDataRow(
                        'Light Intensity', lightIntensityStats, fontSize),
                    buildWeatherDataRow(
                        'Solar Irradiance', solarIrradianceStats, fontSize),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataRow buildWeatherDataRow(
      String parameter, Map<String, List<double?>> stats, double fontSize) {
    return DataRow(cells: [
      DataCell(Text(parameter,
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['current']?[0] != null
              ? stats['current']![0]!.toStringAsFixed(2)
              : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
    ]);
  }

  Widget buildRainDataTable() {
    // Use the string values directly from the API
    String currentRain = _mostRecentHourRain ?? "-"; // If null, show "-"
    String totalRainLast24Hours =
        _totalRainLast24Hours ?? "-"; // If null, show "-"

    double screenWidth = MediaQuery.of(context).size.width;
    double fontSize = screenWidth < 800 ? 13 : 16;
    double headerFontSize = screenWidth < 800 ? 18 : 22;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1),
          borderRadius: BorderRadius.circular(16),
          color: Colors.black.withOpacity(0.6), // Semi-transparent background
        ),
        margin: EdgeInsets.all(10),
        padding: EdgeInsets.all(8),
        width: screenWidth < 800 ? double.infinity : 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'Rain Data',
                style: TextStyle(
                  fontSize: headerFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 16),
            DataTable(
              columnSpacing: screenWidth < 380
                  ? 70
                  : screenWidth < 500
                      ? 120
                      : screenWidth < 800
                          ? 200
                          : 50,
              columns: [
                DataColumn(
                  label: Text(
                    'Timeframe',
                    style: TextStyle(
                        fontSize: screenWidth < 800 ? 18 : 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Value',
                    style: TextStyle(
                        fontSize: screenWidth < 800 ? 18 : 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
              ],
              rows: [
                DataRow(
                  cells: [
                    DataCell(Text(
                      'Recent Hour',
                      style: TextStyle(fontSize: fontSize, color: Colors.white),
                    )),
                    DataCell(Text(
                      currentRain,
                      style: TextStyle(fontSize: fontSize, color: Colors.white),
                    )),
                  ],
                ),
                DataRow(
                  cells: [
                    DataCell(Text(
                      'Last 24 Hours',
                      style: TextStyle(fontSize: fontSize, color: Colors.white),
                    )),
                    DataCell(Text(
                      totalRainLast24Hours,
                      style: TextStyle(fontSize: fontSize, color: Colors.white),
                    )),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

// Calculate average, min, and max values
  Map<String, List<double?>> _calculateNHStatistics(List<ChartData> data) {
    if (data.isEmpty) {
      return {
        // 'average': [null],
        'current': [null],
        'min': [null],
        'max': [null],
      };
    }
    // double sum = 0.0;
    double? current = data.last.value;
    double min = double.infinity;
    double max = double.negativeInfinity;

    for (var entry in data) {
      if (entry.value < min) min = entry.value;
      if (entry.value > max) max = entry.value;
    }

    return {
      'current': [current],
      'min': [min],
      'max': [max],
    };
  }

  // Create a table displaying statistics
  Widget buildNHStatisticsTable() {
    final ammoniaStats = _calculateNHStatistics(ammoniaData);
    final temppStats = _calculateNHStatistics(temperaturedata);
    final humStats = _calculateNHStatistics(humiditydata);

    double screenWidth = MediaQuery.of(context).size.width;
    double fontSize = screenWidth < 800 ? 13 : 16;
    double headerFontSize = screenWidth < 800 ? 16 : 22;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1),
          borderRadius: BorderRadius.circular(16),
          color: Colors.black.withOpacity(0.6),
        ),
        margin: EdgeInsets.all(10),
        padding: EdgeInsets.all(8),
        width: screenWidth < 800 ? double.infinity : 500,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: screenWidth < 800 ? screenWidth - 32 : 500,
            ),
            child: DataTable(
              horizontalMargin: 16,
              columnSpacing: 16,
              columns: [
                DataColumn(
                  label: Text(
                    'Parameter',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Current',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Min',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Max',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
              ],
              rows: [
                buildDataRow('AMMONIA', ammoniaStats, fontSize),
                buildDataRow('TEMP', temppStats, fontSize),
                buildDataRow('HUMIDITY', humStats, fontSize),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DataRow buildNHDataRow(
      String parameter, Map<String, List<double?>> stats, double fontSize) {
    return DataRow(cells: [
      DataCell(Text(parameter,
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['current']?[0] != null
              ? stats['current']![0]!.toStringAsFixed(2)
              : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['min']?[0] != null ? stats['min']![0]!.toStringAsFixed(2) : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['max']?[0] != null ? stats['max']![0]!.toStringAsFixed(2) : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
    ]);
  }

  // Calculate average, min, and max values
  Map<String, List<double?>> _calculateITStatistics(List<ChartData> data) {
    if (data.isEmpty) {
      return {
        // 'average': [null],
        'current': [null],
        'min': [null],
        'max': [null],
      };
    }
    // double sum = 0.0;
    double? current = data.last.value;
    double min = double.infinity;
    double max = double.negativeInfinity;

    for (var entry in data) {
      if (entry.value < min) min = entry.value;
      if (entry.value > max) max = entry.value;
    }

    return {
      'current': [current],
      'min': [min],
      'max': [max],
    };
  }

  // Create a table displaying statistics
  Widget buildITStatisticsTable() {
    final ittempStats = _calculateITStatistics(ittempData);
    final itpressureStats = _calculateITStatistics(itpressureData);
    final ithumStats = _calculateITStatistics(ithumidityData);
    final itrainStats = _calculateITStatistics(itrainData);
    final itradiationStats = _calculateITStatistics(itradiationData);
    final itvisibilityStats = _calculateITStatistics(itvisibilityData);
    final itwindspeedStats = _calculateITStatistics(itwindspeedData);

    double screenWidth = MediaQuery.of(context).size.width;
    double fontSize = screenWidth < 800 ? 13 : 16;
    double headerFontSize = screenWidth < 800 ? 16 : 22;
// Check if there is any valid data
    bool hasValidData = [
      ittempStats['current']?[0],
      itpressureStats['current']?[0],
      ithumStats['current']?[0],
      itrainStats['current']?[0],
      itradiationStats['current']?[0],
      itvisibilityStats['current']?[0],
      itwindspeedStats['current']?[0],
    ].any((value) => value != null && value.toStringAsFixed(2) != '0.00');

    // Only render the table if there is valid data
    if (!hasValidData) {
      return SizedBox.shrink(); // Return an empty widget if no data
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1),
          borderRadius: BorderRadius.circular(16),
          color: Colors.black.withOpacity(0.6),
        ),
        margin: EdgeInsets.all(10),
        padding: EdgeInsets.all(8),
        width: screenWidth < 800 ? double.infinity : 500,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: screenWidth < 800 ? screenWidth - 32 : 500,
            ),
            child: DataTable(
              horizontalMargin: 16,
              columnSpacing: 16,
              columns: [
                DataColumn(
                  label: Text(
                    'Parameter',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Current',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Min',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Max',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
              ],
              rows: [
                buildITDataRow('TEMP', ittempStats, fontSize),
                buildITDataRow('PRESSURE', itpressureStats, fontSize),
                buildITDataRow('HUMIDITY', ithumStats, fontSize),
                buildITDataRow('RAIN', itrainStats, fontSize),
                buildITDataRow('RADIATION', itradiationStats, fontSize),
                buildITDataRow('VISIBILITY', itvisibilityStats, fontSize),
                buildITDataRow('WIND SPEED', itwindspeedStats, fontSize),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DataRow buildITDataRow(
      String parameter, Map<String, List<double?>> stats, double fontSize) {
    // Parameters that should only show current values
    final onlyCurrentParams = [
      'RAIN',
    ];

    final isOnlyCurrent = onlyCurrentParams.contains(parameter);

    return DataRow(cells: [
      DataCell(Text(parameter,
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['current']?[0] != null
              ? stats['current']![0]!.toStringAsFixed(2)
              : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          isOnlyCurrent
              ? '-' // Show '-' for min if parameter is in onlyCurrentParams
              : (stats['min']?[0] != null
                  ? stats['min']![0]!.toStringAsFixed(2)
                  : '-'),
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          isOnlyCurrent
              ? '-' // Show '-' for max if parameter is in onlyCurrentParams
              : (stats['max']?[0] != null
                  ? stats['max']![0]!.toStringAsFixed(2)
                  : '-'),
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
    ]);
  }

  // Calculate average, min, and max values
  Map<String, List<double?>> _calculatefsStatistics(List<ChartData> data) {
    if (data.isEmpty) {
      return {
        'average': [null],
        'current': [null],
        'min': [null],
        'max': [null],
      };
    }
    double sum = 0.0;
    double? current = data.last.value;
    double min = double.infinity;
    double max = double.negativeInfinity;

    for (var entry in data) {
      sum += entry.value;
      if (entry.value < min) min = entry.value;
      if (entry.value > max) max = entry.value;
    }
    double avg = sum / data.length;
    return {
      'average': [avg],
      'current': [current],
      'min': [min],
      'max': [max],
    };
  }

  Widget buildSMStatisticsTable() {
    double screenWidth = MediaQuery.of(context).size.width;
    double fontSize = screenWidth < 800 ? 13 : 16;
    double headerFontSize = screenWidth < 800 ? 16 : 22;

    // Filter only specific keys if needed
    List<String> includedParameters = ['RainfallMinutly', 'RainfallDaily'];

    List<DataRow> rows = smParametersData.entries
        .where((entry) => includedParameters.contains(entry.key))
        .map((entry) {
      final current = entry.value.isNotEmpty
          ? entry.value.last.value.toStringAsFixed(2)
          : '-';
      return DataRow(cells: [
        DataCell(Text(entry.key,
            style: TextStyle(fontSize: fontSize, color: Colors.white))),
        DataCell(Text('$current mm',
            style: TextStyle(fontSize: fontSize, color: Colors.white))),
      ]);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1),
          borderRadius: BorderRadius.circular(16),
          color: Colors.black.withOpacity(0.6),
        ),
        margin: EdgeInsets.all(10),
        padding: EdgeInsets.all(8),
        width: screenWidth < 800 ? double.infinity : 400,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: screenWidth < 800 ? screenWidth - 32 : 400,
            ),
            child: DataTable(
              horizontalMargin: 16,
              columnSpacing: 16,
              columns: [
                DataColumn(
                  label: Text(
                    'Parameter',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Current',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
              ],
              rows: rows,
            ),
          ),
        ),
      ),
    );
  }

  DateTime _parseBDDate(String dateString) {
    final dateFormat = DateFormat(
        'yyyy-MM-dd hh:mm a'); // Ensure this matches your date format
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      return DateTime.now(); // Provide a default date-time if parsing fails
    }
  }

  DateTime _parseDate(String dateString) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      return DateTime.now(); // Provide a default date-time if parsing fails
    }
  }

  DateTime _parsewindDate(String dateString) {
    final dateFormat = DateFormat(
        'yyyy-MM-dd hh:mm a'); // Ensure this matches your date format
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      return DateTime.now(); // Provide a default date-time if parsing fails
    }
  }

  DateTime _parseWaterDate(String dateString) {
    final dateFormat = DateFormat(
        'yyyy-MM-dd HH:mm:ss'); // Ensure this matches your date format
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      return DateTime.now(); // Provide a default date-time if parsing fails
    }
  }

  DateTime _parseCBDate(String dateString) {
    final dateFormat = DateFormat(
        'dd-MM-yyyy HH:mm:ss'); // Ensure this matches your date format
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      return DateTime.now(); // Provide a default date-time if parsing fails
    }
  }

  DateTime _parseITDate(String dateString) {
    final dateFormat = DateFormat(
        'dd-MM-yyyy HH:mm:ss'); // Ensure this matches your date format
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      return DateTime.now(); // Provide a default date-time if parsing fails
    }
  }

  DateTime _parsefsDate(String dateString) {
    final dateFormat = DateFormat(
        'dd-MM-yyyy HH:mm:ss'); // Ensure this matches your date format
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      return DateTime.now(); // Provide a default date-time if parsing fails
    }
  }

  DateTime _parseSMDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return DateTime.now();
    }
    try {
      // Parse the timestamp format: YYYYMMDDTHHMMSS (e.g., 20250614T162130)
      return DateTime.parse(
          dateStr.replaceFirst('T', ' ')); // Convert to YYYYMMDD HHMMSS
    } catch (e) {
      return DateTime.now();
    }
  }

  DateTime _parseCFDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return DateTime.now();
    }
    try {
      // Parse the timestamp format: YYYY-MM-DD HH:MM:SS (e.g., 2025-06-15 01:01:02)
      return DateTime.parse(dateStr);
    } catch (e) {
      return DateTime.now();
    }
  }

  DateTime _parseVDDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return DateTime.now();
    }
    try {
      // Parse the timestamp format: YYYY-MM-DD HH:MM:SS (e.g., 2025-06-15 01:01:02)
      return DateTime.parse(dateStr);
    } catch (e) {
      return DateTime.now();
    }
  }

  DateTime _parseKDDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return DateTime.now();
    }
    try {
      // Parse the timestamp format: YYYY-MM-DD HH:MM:SS (e.g., 2025-06-15 01:01:02)
      return DateTime.parse(dateStr);
    } catch (e) {
      return DateTime.now();
    }
  }

  DateTime _parseNARLDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return DateTime.now();
    }
    try {
      // Parse the timestamp format: YYYY-MM-DD HH:MM:SS (e.g., 2025-06-15 01:01:02)
      return DateTime.parse(dateStr);
    } catch (e) {
      return DateTime.now();
    }
  }

  DateTime _parseKJDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return DateTime.now();
    }
    try {
      // Parse the timestamp format: YYYY-MM-DD HH:MM:SS (e.g., 2025-06-15 01:01:02)
      return DateTime.parse(dateStr);
    } catch (e) {
      return DateTime.now();
    }
  }

  DateTime _parseMYDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return DateTime.now();
    }
    try {
      // Parse the timestamp format: YYYY-MM-DD HH:MM:SS (e.g., 2025-06-15 01:01:02)
      return DateTime.parse(dateStr);
    } catch (e) {
      return DateTime.now();
    }
  }

  DateTime _parsecsDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return DateTime.now();
    }
    try {
      // Parse the timestamp format: YYYY-MM-DD HH:MM:SS (e.g., 2025-06-15 01:01:02)
      return DateTime.parse(dateStr);
    } catch (e) {
      return DateTime.now();
    }
  }

  DateTime _parseSVDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return DateTime.now();
    }
    try {
      // Parse the timestamp format: YYYY-MM-DD HH:MM:SS (e.g., 2025-06-15 01:01:02)
      return DateTime.parse(dateStr);
    } catch (e) {
      return DateTime.now();
    }
  }

  DateTime _parsedoDate(String dateString) {
    final dateFormat = DateFormat(
        'yyyy-MM-dd HH:mm:ss'); // Ensure this matches your date format
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      return DateTime.now(); // Provide a default date-time if parsing fails
    }
  }

  DateTime _parseammoniaDate(String dateString) {
    final dateFormat = DateFormat(
        'dd-MM-yyyy HH:mm:ss'); // Ensure this matches your date format
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      return DateTime.now(); // Provide a default date-time if parsing fails
    }
  }

  DateTime _parsewfDate(String dateString) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss'); // Correct format
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      return DateTime.now();
    }
  }

  DateTime _parserainDate(String dateString) {
    final dateFormat = DateFormat(
        'dd-MM-yyyy HH:mm:ss'); // Ensure this matches your date format
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      return DateTime.now(); // Provide a default date-time if parsing fails
    }
  }

  DateTime _parsethDate(String dateString) {
    if (dateString.isEmpty) {
      return DateTime.now();
    }

    final dateFormat = DateFormat('dd-MM-yyyy HH:mm:ss');
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      return DateTime.now();
    }
  }

  DateTime _parsesensorDate(String dateString) {
    final dateFormat = DateFormat(
        'yyyy-MM-dd HH:mm:ss'); // Ensure this matches your date format
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      return DateTime.now(); // Provide a default date-time if parsing fails
    }
  }

  DateTime _parsewaterDate(String dateString) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    try {
      return dateFormat.parse(dateString);
    } catch (e) {
      return DateTime.now();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  String _getDeviceStatus(String lastReceivedTime) {
    if (lastReceivedTime == 'Unknown') return 'Unknown';
    try {
      // Adjust this format to match the actual format of lastReceivedTime
      final dateFormat = DateFormat(
          'yyyy-MM-dd hh:mm a'); // Change to 'HH:mm' for 24-hour format

      final lastReceivedDate = dateFormat.parse(lastReceivedTime);
      final currentTime = DateTime.now();
      final difference = currentTime.difference(lastReceivedDate);

      if (difference.inMinutes <= 62) {
        return 'Active';
      } else {
        return 'Inactive';
      }
    } catch (e) {
      print('Error parsing date: $e');
      return 'Inactive'; // Fallback status in case of error
    }
  }

  Future<void> _selectDate() async {
    print('selectDate: Opening date picker');
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(1970),
      lastDate: DateTime(2027),
    );

    if (picked != null && picked != _selectedDay && mounted) {
      setState(() {
        _selectedDay = picked;
      });
      print('selectDate: Selected new date $_selectedDay');
    } else {
      print('selectDate: No new date selected, using $_selectedDay');
    }
    if (mounted) {
      print('selectDate: Triggering reload for single day');
      _reloadData(range: 'single', selectedDate: _selectedDay);
    }
  }

  void _reloadData({String range = 'single', DateTime? selectedDate}) async {
    setState(() {
      _isLoading = true;
      _selectedParam = null; // Reset selected parameter
      _isParamHovering
          .updateAll((key, value) => false); // Reset all hover states
      _rotationController.repeat();
    });

    await _fetchDataForRange(range, selectedDate);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _rotationController.stop(canceled: true); // Immediately stop rotation
      });
    } else {}
  }

  // Updated _buildWindCompass
  Widget _buildWindCompass(String? winddirection) {
    // Convert wind direction to double, default to 0 if invalid
    double angle = 0;
    try {
      angle = double.parse(winddirection ?? '0');
    } catch (e) {
      angle = 0;
    }

    // Convert degrees to radians for rotation
    final angleRad = angle * math.pi / 180;

    return Column(
      children: [
        Container(
          width: 150,
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Compass background with ticks
              CustomPaint(
                painter: CompassBackgroundPainter(),
                child: Container(width: 150, height: 150),
              ),
              // Compass cardinal directions (N, NE, E, SE, S, SW, W, NW)
              Positioned(
                top: 10,
                child: Text(
                  'N',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                top: 20,
                right: 20,
                child: Text(
                  'NE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                right: 10,
                child: Text(
                  'E',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                right: 20,
                child: Text(
                  'SE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                child: Text(
                  'S',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                child: Text(
                  'SW',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                left: 10,
                child: Text(
                  'W',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                top: 20,
                left: 20,
                child: Text(
                  'NW',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Rotated needle for wind direction
              Transform.rotate(
                angle: angleRad,
                child: CustomPaint(
                  painter: CompassNeedlePainter(), // No angle parameter
                  child: Container(width: 150, height: 150),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Wind Direction: ${winddirection ?? 'N/A'}°',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

// Updated _getParameterDisplayInfo with normalization
  Map<String, dynamic> _getParameterDisplayInfo(String paramName) {
    // Normalize the paramName by removing prefixes/suffixes like 'Current', 'Hourly', etc.
    // Handle AtmPressure explicitly to preserve "Atm Pressure"
    if (paramName.toLowerCase().contains('atmpressure')) {
      return {
        'displayName': 'Atm Pressure',
        'unit': 'hPa',
      };
    }

    // Handle pH explicitly to preserve "pH"
    if (paramName.toLowerCase().contains('pH')) {
      return {
        'displayName': 'pH',
        'unit': 'pH',
      };
    }
    String normalized = paramName
        .replaceAll('Current', '')
        .replaceAll('Hourly', '')
        .replaceAll('Minutly', '')
        .replaceAll('Daily', '')
        .replaceAll('Weekly', '')
        .replaceAll('Average', '')
        .replaceAll('Maximum', '')
        .replaceAll('Minimum', '')
        .trim();

    // Convert to title case with spaces
    String displayName = normalized
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match[1]}')
        .trim();

    // Special cases for consistency
    if (displayName.toLowerCase().contains('temp')) {
      displayName = 'Temperature';
    } else if (displayName.toLowerCase().contains('humid')) {
      displayName = 'Humidity';
    } else if (displayName.toLowerCase().contains('rain')) {
      displayName = 'Rainfall';
    } else if (displayName.toLowerCase().contains('lightintens')) {
      displayName = 'Light Intensity';
    } else if (displayName.toLowerCase().contains('windspeed')) {
      displayName = 'Wind Speed';
    } else if (displayName.toLowerCase().contains('winddirect')) {
      displayName = 'Wind Direction';
    } else if (displayName.toLowerCase().contains('ammon')) {
      displayName = 'Ammonia';
    } else if (displayName.toLowerCase().contains('press')) {
      displayName = 'Pressure';
    } else if (displayName.toLowerCase().contains('radiat')) {
      displayName = 'Radiation';
    } else if (displayName.toLowerCase().contains('visib')) {
      displayName = 'Visibility';
    } else if (displayName.toLowerCase().contains('solarirrad')) {
      displayName = 'Solar Irradiance';
    } else if (displayName.toLowerCase().contains('electrode')) {
      displayName = 'Electrode Signal';
    } else if (displayName.toLowerCase().contains('hypochlor')) {
      displayName = 'Hypochlorous';
    } else if (displayName.toLowerCase().contains('residualchlor')) {
      displayName = 'Chlorine';
    } else if (displayName.toLowerCase().contains('pH')) {
      displayName = 'pH';
    } else if (displayName.toLowerCase().contains('Phosphorus')) {
      displayName = 'Phosphorus';
    }

    String unit = '';

    if (paramName.contains('Rainfall'))
      unit = 'mm';
    else if (paramName.contains('Voltage'))
      unit = 'V';
    else if (paramName.contains('SignalStrength'))
      unit = 'dBm';
    else if (paramName.contains('Latitude') || paramName.contains('Longitude'))
      unit = 'deg';
    else if (paramName.contains('Temperature'))
      unit = '°C';
    else if (paramName.contains('Humidity'))
      unit = '%';
    else if (paramName.contains('Pressure'))
      unit = 'hPa';
    else if (paramName.contains('LightIntensity'))
      unit = 'Lux';
    else if (paramName.contains('WindSpeed'))
      unit = 'm/s';
    else if (paramName.contains('WindDirection'))
      unit = '°';
    else if (paramName.contains('Potassium'))
      unit = 'mg/Kg';
    else if (paramName.contains('Nitrogen'))
      unit = 'mg/Kg';
    else if (paramName.contains('Salinity'))
      unit = 'mg/L';
    else if (paramName.contains('ElectricalConductivity'))
      unit = 'µS/cm';
    else if (paramName.contains('Phosphorus'))
      unit = 'mg/Kg';
    else if (paramName.contains('pH'))
      unit = 'pH';
    else if (paramName.contains('Irradiance') ||
        paramName.contains('Radiation'))
      unit = 'W/m²';
    else if (paramName.contains('Chlorine') ||
        paramName.contains('COD') ||
        paramName.contains('BOD') ||
        paramName.contains('DO'))
      unit = 'mg/L';
    else if (paramName.contains('TDS'))
      unit = 'ppm';
    else if (paramName.contains('EC'))
      unit = 'mS/cm';
    else if (paramName.contains('pH'))
      unit = '';
    else if (paramName.contains('Ammonia'))
      unit = 'PPM';
    else if (paramName.contains('Visibility'))
      unit = 'm';
    else if (paramName.contains('ElectrodeSignal')) unit = 'mV';

    return {'displayName': displayName, 'unit': unit};
  }

// Updated _buildHorizontalStatsRow and _buildParamStat
  Widget _buildHorizontalStatsRow(bool isDarkMode) {
    if (widget.deviceName.startsWith('WQ')) {
      final tempStats = _calculateStatistics(tempData);
      final tdsStats = _calculateStatistics(tdsData);
      final codStats = _calculateStatistics(codData);
      final bodStats = _calculateStatistics(bodData);
      final pHStats = _calculateStatistics(pHData);
      final doStats = _calculateStatistics(doData);
      final ecStats = _calculateStatistics(ecData);
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildParamStat('Temp', tempStats['current']?[0],
              tempStats['min']?[0], tempStats['max']?[0], '°C', isDarkMode,
              onTap: () => _scrollToChart('Temp')),
          _buildParamStat('TDS', tdsStats['current']?[0], tdsStats['min']?[0],
              tdsStats['max']?[0], 'ppm', isDarkMode,
              onTap: () => _scrollToChart('TDS')),
          _buildParamStat('COD', codStats['current']?[0], codStats['min']?[0],
              codStats['max']?[0], 'mg/L', isDarkMode,
              onTap: () => _scrollToChart('COD')),
          _buildParamStat('BOD', bodStats['current']?[0], bodStats['min']?[0],
              bodStats['max']?[0], 'mg/L', isDarkMode,
              onTap: () => _scrollToChart('BOD')),
          _buildParamStat('pH', pHStats['current']?[0], pHStats['min']?[0],
              pHStats['max']?[0], '', isDarkMode,
              onTap: () => _scrollToChart('pH')),
          _buildParamStat('DO', doStats['current']?[0], doStats['min']?[0],
              doStats['max']?[0], 'mg/L', isDarkMode,
              onTap: () => _scrollToChart('DO')),
          _buildParamStat('EC', ecStats['current']?[0], ecStats['min']?[0],
              ecStats['max']?[0], 'mS/cm', isDarkMode,
              onTap: () => _scrollToChart('EC')),
        ],
      );
    } else if (widget.deviceName.startsWith('FS')) {
      final fstempStats = _calculatefsStatistics(fstempData);
      final fspressureStats = _calculatefsStatistics(fspressureData);
      final fshumStats = _calculatefsStatistics(fshumidityData);
      final fsrainStats = _calculatefsStatistics(fsrainData);
      final fsradiationStats = _calculatefsStatistics(fsradiationData);
      final fswindspeedStats = _calculatefsStatistics(fswindspeedData);
      final fswinddirectionStats = _calculatefsStatistics(fswinddirectionData);

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildParamStat('Temperature', fstempStats['current']?[0], null, null,
              '°C', isDarkMode,
              onTap: () => _scrollToChart('Temperature')),
          _buildParamStat('Pressure', fspressureStats['current']?[0], null,
              null, 'hPa', isDarkMode,
              onTap: () => _scrollToChart('Pressure')),
          _buildParamStat('Humidity', fshumStats['current']?[0], null, null,
              '%', isDarkMode,
              onTap: () => _scrollToChart('Humidity')),
          _buildParamStat('Rain Level', fsrainStats['current']?[0], null, null,
              'mm', isDarkMode,
              onTap: () => _scrollToChart('Rain Level')),
          _buildParamStat('Radiation', fsradiationStats['current']?[0], null,
              null, 'W/m²', isDarkMode,
              onTap: () => _scrollToChart('Radiation')),
          _buildParamStat('Wind Speed', fswindspeedStats['current']?[0], null,
              null, 'm/s', isDarkMode,
              onTap: () => _scrollToChart('Wind Speed')),
          _buildParamStat('Wind Direction', fswinddirectionStats['current']?[0],
              null, null, '°', isDarkMode,
              onTap: () => _scrollToChart('Wind Direction')),
        ],
      );
    } else if (widget.deviceName.startsWith('CB')) {
      final temp2Stats = _calculateCBStatistics(temp2Data);
      final cod2Stats = _calculateCBStatistics(cod2Data);
      final bod2Stats = _calculateCBStatistics(bod2Data);
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildParamStat('Temp', temp2Stats['current']?[0],
              temp2Stats['min']?[0], temp2Stats['max']?[0], '°C', isDarkMode,
              onTap: () => _scrollToChart('Temp')),
          _buildParamStat('COD', cod2Stats['current']?[0], cod2Stats['min']?[0],
              cod2Stats['max']?[0], 'mg/L', isDarkMode,
              onTap: () => _scrollToChart('COD')),
          _buildParamStat('BOD', bod2Stats['current']?[0], bod2Stats['min']?[0],
              bod2Stats['max']?[0], 'mg/L', isDarkMode,
              onTap: () => _scrollToChart('BOD')),
        ],
      );
    } else if (widget.deviceName.startsWith('NH')) {
      final ammoniaStats = _calculateNHStatistics(ammoniaData);
      final temppStats = _calculateNHStatistics(temperaturedata);
      final humStats = _calculateNHStatistics(humiditydata);
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildParamStat(
              'AMMONIA',
              ammoniaStats['current']?[0],
              ammoniaStats['min']?[0],
              ammoniaStats['max']?[0],
              'PPM',
              isDarkMode,
              onTap: () => _scrollToChart('AMMONIA')),
          _buildParamStat('TEMP', temppStats['current']?[0],
              temppStats['min']?[0], temppStats['max']?[0], '°C', isDarkMode,
              onTap: () => _scrollToChart('TEMP')),
          _buildParamStat('HUMIDITY', humStats['current']?[0],
              humStats['min']?[0], humStats['max']?[0], '%', isDarkMode,
              onTap: () => _scrollToChart('HUMIDITY')),
        ],
      );
    } else if (widget.deviceName.startsWith('DO')) {
      final ttempStats = _calculateDOStatistics(ttempData);
      final dovalueStats = _calculateDOStatistics(dovaluedata);
      final dopercentageStats = _calculateDOStatistics(dopercentagedata);
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildParamStat('Temperature', ttempStats['current']?[0],
              ttempStats['min']?[0], ttempStats['max']?[0], '°C', isDarkMode,
              onTap: () => _scrollToChart('Temperature')),
          _buildParamStat(
              'DO Value',
              dovalueStats['current']?[0],
              dovalueStats['min']?[0],
              dovalueStats['max']?[0],
              'mg/L',
              isDarkMode,
              onTap: () => _scrollToChart('DO Value')),
          _buildParamStat(
              'DO Percentage',
              dopercentageStats['current']?[0],
              dopercentageStats['min']?[0],
              dopercentageStats['max']?[0],
              '%',
              isDarkMode,
              onTap: () => _scrollToChart('DO Percentage')),
        ],
      );
    } else if (widget.deviceName.startsWith('NA')) {
      Map<String, String> parameterLabels = {
        'CurrentTemperature': 'Temperature',
        'CurrentHumidity': 'Humidity',
        'LightIntensity': 'Light Intensity',
        'WindSpeed': 'Wind Speed',
        'AtmPressure': 'Atm Pressure',
        'WindDirection': 'Wind Direction',
        'RainfallHourly': 'Rainfall'
      };
      List<String> includedParameters = parameterLabels.keys.toList();

      List<Widget> children = NARLParametersData.entries
          .where((entry) => includedParameters.contains(entry.key))
          .map((entry) {
        String label = parameterLabels[entry.key] ?? entry.key;
        double? current =
            entry.value.isNotEmpty ? entry.value.last.value : null;
        String unit = '';
        if (label == 'Temperature')
          unit = '°C';
        else if (label == 'Humidity')
          unit = '%';
        else if (label == 'Light Intensity')
          unit = 'lux';
        else if (label == 'Rainfall' || label == 'Rainfall Minutely')
          unit = 'mm';
        else if (label == 'Wind Speed')
          unit = 'm/s';
        else if (label == 'Atm Pressure')
          unit = 'hpa';
        else if (label == 'Wind Direction') unit = '°';
        return _buildParamStat(label, current, null, null, unit, isDarkMode,
            onTap: () => _scrollToChart(label));
      }).toList();
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: children,
      );
    } else if (widget.deviceName.startsWith('KJ')) {
      Map<String, String> parameterLabels = {
        'CurrentTemperature': 'Temperature',
        'CurrentHumidity': 'Humidity',
        'Potassium': 'Potassium',
        'pH': 'pH',
        'Nitrogen': 'Nitrogen',
        'Salinity': 'Salinity',
        'ElectricalConductivity': 'Electrical Conductivity',
        'Phosphorus': 'Phosphorus',
      };
      List<String> includedParameters = parameterLabels.keys.toList();

      List<Widget> children = KJParametersData.entries
          .where((entry) => includedParameters.contains(entry.key))
          .map((entry) {
        String label = parameterLabels[entry.key] ?? entry.key;
        double? current =
            entry.value.isNotEmpty ? entry.value.last.value : null;
        String unit = '';
        if (label == 'Temperature')
          unit = '°C';
        else if (label == 'Humidity')
          unit = '%';
        else if (label == 'Light Intensity')
          unit = 'lux';
        else if (label == 'Rainfall' || label == 'Rainfall Minutely')
          unit = 'mm';
        else if (label == 'Wind Speed')
          unit = 'm/s';
        else if (label == 'Atm Pressure')
          unit = 'hpa';
        else if (label == 'Salinity')
          unit = 'mg/L'; // parts per thousand (common for salinity)
        else if (label == 'Potassium')
          unit = 'mg/kg';
        else if (label == 'Nitrogen')
          unit = 'mg/kg';
        else if (label == 'Phosphorus')
          unit = 'mg/kg';
        else if (label == 'EC' || label == 'Electrical Conductivity')
          unit = 'µS/cm';
        else if (label == 'pH')
          unit = ''; // dimensionless
        else if (label == 'Wind Direction') unit = '°';
        return _buildParamStat(label, current, null, null, unit, isDarkMode,
            onTap: () => _scrollToChart(label));
      }).toList();
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: children,
      );
    } else if (widget.deviceName.startsWith('MY')) {
      Map<String, String> parameterLabels = {
        'CurrentTemperature': 'Temperature',
        'CurrentHumidity': 'Humidity',
        'LightIntensity': 'Light Intensity',
        'WindSpeed': 'Wind Speed',
        'AtmPressure': 'Atm Pressure',
        'WindDirection': 'Wind Direction',
        'RainfallHourly': 'Rainfall'
      };
      List<String> includedParameters = parameterLabels.keys.toList();

      List<Widget> children = MYParametersData.entries
          .where((entry) => includedParameters.contains(entry.key))
          .map((entry) {
        String label = parameterLabels[entry.key] ?? entry.key;
        double? current =
            entry.value.isNotEmpty ? entry.value.last.value : null;
        String unit = '';
        if (label == 'Temperature')
          unit = '°C';
        else if (label == 'Humidity')
          unit = '%';
        else if (label == 'Light Intensity')
          unit = 'lux';
        else if (label == 'Rainfall' || label == 'Rainfall Minutely')
          unit = 'mm';
        else if (label == 'Wind Speed')
          unit = 'm/s';
        else if (label == 'Atm Pressure')
          unit = 'hpa';
        else if (label == 'Wind Direction') unit = '°';
        return _buildParamStat(label, current, null, null, unit, isDarkMode,
            onTap: () => _scrollToChart(label));
      }).toList();
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: children,
      );
    } else if (widget.deviceName.startsWith('VD')) {
      Map<String, String> parameterLabels = {
        'CurrentTemperature': 'Temperature',
        'CurrentHumidity': 'Humidity',
        'LightIntensity': 'Light Intensity',
        'RainfallHourly': 'Rainfall',
      };
      List<String> includedParameters = parameterLabels.keys.toList();

      List<Widget> children = vdParametersData.entries
          .where((entry) => includedParameters.contains(entry.key))
          .map((entry) {
        String label = parameterLabels[entry.key] ?? entry.key;
        double? current =
            entry.value.isNotEmpty ? entry.value.last.value : null;
        String unit = '';
        if (label == 'Temperature')
          unit = '°C';
        else if (label == 'Humidity')
          unit = '%';
        else if (label == 'Light Intensity')
          unit = 'lux';
        else if (label == 'Rainfall') unit = 'mm';
        return _buildParamStat(label, current, null, null, unit, isDarkMode,
            onTap: () => _scrollToChart(label));
      }).toList();
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: children,
      );
    } else if (widget.deviceName.startsWith('CF')) {
      Map<String, String> parameterLabels = {
        'CurrentTemperature': 'Temperature',
        'CurrentHumidity': 'Humidity',
        'LightIntensity': 'Light Intensity',
        'RainfallHourly': 'Rainfall',
        'WindSpeed': 'Wind Speed',
        'AtmPressure': 'Atm Pressure',
        'WindDirection': 'Wind Direction'
      };
      List<String> includedParameters = parameterLabels.keys.toList();

      List<Widget> children = cfParametersData.entries
          .where((entry) => includedParameters.contains(entry.key))
          .map((entry) {
        String label = parameterLabels[entry.key] ?? entry.key;
        double? current =
            entry.value.isNotEmpty ? entry.value.last.value : null;
        String unit = '';
        if (label == 'Temperature')
          unit = '°C';
        else if (label == 'Humidity')
          unit = '%';
        else if (label == 'Light Intensity')
          unit = 'lux';
        else if (label == 'Rainfall')
          unit = 'mm';
        else if (label == 'Wind Speed')
          unit = 'm/s';
        else if (label == 'Atm Pressure')
          unit = 'hpa';
        else if (label == 'Wind Direction') unit = '°';
        return _buildParamStat(label, current, null, null, unit, isDarkMode,
            onTap: () => _scrollToChart(label));
      }).toList();
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: children,
      );
    } else if (widget.deviceName.startsWith('CP')) {
      Map<String, String> parameterLabels = {
        'CurrentTemperature': 'Temperature',
        'CurrentHumidity': 'Humidity',
        'LightIntensity': 'Light Intensity',
        'RainfallHourly': 'Rainfall',
        'WindSpeed': 'Wind Speed',
        'AtmPressure': 'Atm Pressure',
        'WindDirection': 'Wind Direction'
      };
      List<String> includedParameters = parameterLabels.keys.toList();

      List<Widget> children = csParametersData.entries
          .where((entry) => includedParameters.contains(entry.key))
          .map((entry) {
        String label = parameterLabels[entry.key] ?? entry.key;
        double? current =
            entry.value.isNotEmpty ? entry.value.last.value : null;
        String unit = '';
        if (label == 'Temperature')
          unit = '°C';
        else if (label == 'Humidity')
          unit = '%';
        else if (label == 'Light Intensity')
          unit = 'lux';
        else if (label == 'Rainfall')
          unit = 'mm';
        else if (label == 'Wind Speed')
          unit = 'm/s';
        else if (label == 'Atm Pressure')
          unit = 'hpa';
        else if (label == 'Wind Direction') unit = '°';
        return _buildParamStat(label, current, null, null, unit, isDarkMode,
            onTap: () => _scrollToChart(label));
      }).toList();
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: children,
      );
    }
    return Row();
  }

  void _scrollToChart(String parameter) {
    final key = _chartKeys[parameter];
    if (key != null && key.currentContext != null) {
      final RenderBox renderBox =
          key.currentContext!.findRenderObject() as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero).dy;
      final scrollPosition = _scrollController.offset +
          position -
          MediaQuery.of(context).padding.top -
          kToolbarHeight;
      _scrollController.animateTo(
        scrollPosition,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  // Updated _buildParamStat with hover, touch, and persistent selection
  Widget _buildParamStat(String label, double? current, double? min,
      double? max, String unit, bool isDarkMode,
      {VoidCallback? onTap}) {
    final Map<String, IconData> parameterIcons = {
      'Atm Pressure': Icons.compress,
      'Light Intensity': Icons.wb_sunny,
      'Rainfall': Icons.cloudy_snowing,
      'Temperature': Icons.thermostat,
      'Wind Direction': Icons.navigation,
      'Wind Speed': Icons.air,
      'Humidity': Icons.water,
      'TDS': Icons.water_drop,
      'COD': Icons.science,
      'BOD': Icons.science,
      'pH': Icons.opacity,
      'DO': Icons.bubble_chart,
      'EC': Icons.electrical_services,
      'Ammonia': Icons.cloud,
      'Pressure': Icons.compress,
      'Rain Level': Icons.cloudy_snowing,
      'Radiation': Icons.wb_sunny,
      'DO Value': Icons.bubble_chart,
      'DO Percentage': Icons.percent,
      'Potassium': Icons.bolt,
      'Nitrogen': Icons.grass,
      'Phosphorus': Icons.local_florist,
      'Salinity': Icons.waves,
      'Electrical Conductivity': Icons.electric_bolt,
    };

    final IconData icon = parameterIcons[label] ?? Icons.help;

    // Determine if the device is mobile based on screen width
    bool isMobile = MediaQuery.of(context).size.width < 600;

    // Determine if this parameter is selected or being hovered/touched
    bool isSelected = _selectedParam == label;
    bool isHovered = _isParamHovering[label] ?? false;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedParam = label; // Set this parameter as selected
        });
        if (onTap != null) {
          onTap();
        }
      },
      onTapDown: (_) {
        if (isMobile) {
          setState(() {
            _isParamHovering[label] = true;
          });
        }
      },
      onTapUp: (_) {
        if (isMobile) {
          setState(() {
            _isParamHovering[label] = false;
          });
        }
      },
      onTapCancel: () {
        if (isMobile) {
          setState(() {
            _isParamHovering[label] = false;
          });
        }
      },
      child: MouseRegion(
        onEnter: (_) {
          if (!isMobile) {
            setState(() {
              _isParamHovering[label] = true;
            });
          }
        },
        onExit: (_) {
          if (!isMobile) {
            setState(() {
              _isParamHovering[label] = false;
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(4.0),
          decoration: BoxDecoration(
            color: current != null
                ? (isSelected || isHovered
                    ? (isDarkMode
                        ? Colors.blueGrey[700]!
                        : const Color.fromARGB(255, 166, 163, 163))
                    : (isDarkMode ? Colors.blueGrey[900]! : Colors.grey[200]!))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8.0),
            boxShadow: (isSelected || isHovered)
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 20.0,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  const SizedBox(width: 4.0),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4.0),
              Text(
                '${current?.toStringAsFixed(2) ?? '-'} $unit',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              if (min != null)
                Text(
                  'Min: ${min.toStringAsFixed(2)} $unit',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              if (max != null)
                Text(
                  'Max: ${max.toStringAsFixed(2)} $unit',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMinMaxTable(
      bool isDarkMode, Map<String, List<ChartData>> parameters) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Align(
            alignment: Alignment.center, // keep table centered
            child: SizedBox(
              width:
                  isMobile ? constraints.maxWidth * 0.95 : constraints.maxWidth,
              child: Table(
                border: TableBorder.all(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                columnWidths: const {
                  0: FlexColumnWidth(2), // Parameter column
                  1: FlexColumnWidth(1), // Min column
                  2: FlexColumnWidth(1), // Max column
                },
                children: [
                  TableRow(
                    children: [
                      _buildCenteredCell('Parameter', isDarkMode,
                          isHeader: true),
                      _buildCenteredCell('Min', isDarkMode, isHeader: true),
                      _buildCenteredCell('Max', isDarkMode, isHeader: true),
                    ],
                  ),
                  ...parameters.entries.map((entry) {
                    final paramName = entry.key;
                    final data = entry.value;

                    if (data.isEmpty) {
                      return TableRow(children: [
                        SizedBox.shrink(),
                        SizedBox.shrink(),
                        SizedBox.shrink()
                      ]);
                    }

                    final values = data.map((d) => d.value).toList();
                    final minValue = values
                        .reduce((a, b) => a < b ? a : b)
                        .toStringAsFixed(2);
                    final maxValue = values
                        .reduce((a, b) => a > b ? a : b)
                        .toStringAsFixed(2);

                    return TableRow(
                      children: [
                        _buildCenteredCell(paramName, isDarkMode),
                        _buildCenteredCell(minValue, isDarkMode, fontSize: 12),
                        _buildCenteredCell(maxValue, isDarkMode, fontSize: 12),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCenteredCell(String text, bool isDarkMode,
      {bool isHeader = false, double fontSize = 14}) {
    return Padding(
      padding: EdgeInsets.all(4.0),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: fontSize,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    String _selectedRange = 'ee';

    // Calculate sidebar width based on screen size
    double sidebarWidth = MediaQuery.of(context).size.width < 800 ? 250 : 260;
    bool isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      drawer: isMobile ? _buildDrawer(isDarkMode, context) : null,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDarkMode
                    ? [
                        const Color.fromARGB(255, 192, 185, 185),
                        const Color.fromARGB(255, 123, 159, 174),
                      ]
                    : [
                        const Color.fromARGB(255, 126, 171, 166),
                        const Color.fromARGB(255, 54, 58, 59),
                      ],
              ),
            ),
          ),
          // Layout for larger screens (tablets and desktops)
          if (!isMobile)
            Row(
              children: [
                // Left Navbar for larger screens
                Container(
                  width: sidebarWidth,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.blueGrey[900] : Colors.grey[200],
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(2, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back button and Device Name on the same line
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.arrow_back,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            SizedBox(width: 8),
                            Text.rich(
                              TextSpan(
                                text:
                                    "${widget.sequentialName}\n", // Sequential name first
                                style: TextStyle(
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                children: [
                                  TextSpan(
                                    text:
                                        "(${widget.deviceName})\n", // Device name next line
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  TextSpan(
                                    text: () {
                                      // Get Lat & Long from _deviceStatuses
                                      final String prefix =
                                          _getPrefix(widget.deviceName);
                                      final String idStr = widget.deviceName
                                          .substring(prefix.length);
                                      final int? targetIdNum =
                                          int.tryParse(idStr);
                                      final filteredDevices =
                                          _deviceStatuses.where((device) {
                                        final int? deviceIdNum =
                                            int.tryParse(device.deviceId);
                                        return device.activityType == prefix &&
                                            deviceIdNum == targetIdNum;
                                      }).toList();
                                      if (filteredDevices.isNotEmpty) {
                                        final device = filteredDevices.first;
                                        final bool hasValidCoordinates =
                                            device.latitude != null &&
                                                device.longitude != null &&
                                                device.latitude != 0 &&
                                                device.longitude != 0;
                                        if (hasValidCoordinates) {
                                          return "Latitude: ${device.latitude!.toStringAsFixed(2)}\n"
                                              "Longitude: ${device.longitude!.toStringAsFixed(2)}\n";
                                        }
                                      }
                                      return "";
                                    }(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDarkMode
                                          ? Colors.white70
                                          : Colors.black87,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

// Device Active Time
                      const SizedBox(height: 8),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (_errorMessage != null)
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            color:
                                isDarkMode ? Colors.red[300] : Colors.red[700],
                            fontSize: 14,
                          ),
                        )
                      else
                        Builder(
                          builder: (context) {
                            // Define filteredDevices based on prefix and device ID
                            final String prefix = _getPrefix(widget.deviceName);
                            final String idStr =
                                widget.deviceName.substring(prefix.length);
                            final int? targetIdNum = int.tryParse(idStr);
                            final filteredDevices =
                                _deviceStatuses.where((device) {
                              final int? deviceIdNum =
                                  int.tryParse(device.deviceId);
                              return device.activityType == prefix &&
                                  deviceIdNum == targetIdNum;
                            }).toList();
                            return SizedBox(
                              height: 60,
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: filteredDevices.length,
                                itemBuilder: (context, index) {
                                  final device = filteredDevices[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 0.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              left:
                                                  38.0), // Move text to the right
                                          child: Text(
                                            'Last Active: ${device.lastReceivedTime}',
                                            style: TextStyle(
                                              color: isDarkMode
                                                  ? Colors.white
                                                  : Colors.black,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      // Time Period Selection
                      Container(
                        height: 64,
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.blueGrey[900]
                              : Colors.grey[200],
                          border: Border(
                            bottom: BorderSide(
                              color: isDarkMode
                                  ? Colors.blueGrey[900]!
                                  : Colors.grey[200]!,
                              width: 0,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: isDarkMode ? Colors.white : Colors.black,
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Select Time Period',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Scrollbar(
                            // 👈 Visible scrollbar
                            // thumbVisibility: true, // Always show the thumb
                            thickness: 6, // Scrollbar thickness
                            radius: Radius.circular(8),
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  _buildSidebarButton(
                                    '1 Day : ${DateFormat('dd-MM-yyyy').format(_selectedDay)}',
                                    'date',
                                    Icons.today,
                                    isDarkMode,
                                    onPressed: () {
                                      _selectDate();
                                      _reloadData(range: '1day');
                                      setState(() {
                                        _activeButton = 'date';
                                      });
                                    },
                                  ),
                                  SizedBox(height: 8),
                                  _buildSidebarButton(
                                    'Last 7 Days',
                                    '7days',
                                    Icons.calendar_view_week,
                                    isDarkMode,
                                    onPressed: () {
                                      _reloadData(range: '7days');
                                      _fetchDataForRange('7days');
                                      setState(() {
                                        _activeButton = '7days';
                                      });
                                    },
                                  ),
                                  SizedBox(height: 8),
                                  _buildSidebarButton(
                                    'Last 30 Days',
                                    '30days',
                                    Icons.calendar_view_month,
                                    isDarkMode,
                                    onPressed: () {
                                      _reloadData(range: '30days');
                                      _fetchDataForRange('30days');
                                      setState(() {
                                        _activeButton = '30days';
                                      });
                                    },
                                  ),
                                  SizedBox(height: 8),
                                  _buildSidebarButton(
                                    'Last 3 Months',
                                    '3months',
                                    Icons.calendar_today,
                                    isDarkMode,
                                    onPressed: () {
                                      _reloadData(range: '3months');
                                      _fetchDataForRange('3months');
                                      setState(() {
                                        _activeButton = '3months';
                                      });
                                    },
                                  ),
                                  SizedBox(height: 8),
                                  _buildSidebarButton(
                                    'Last 1 Year',
                                    '1year',
                                    Icons.date_range,
                                    isDarkMode,
                                    onPressed: () {
                                      _reloadData(range: '1year');
                                      _fetchDataForRange('1year');
                                      setState(() {
                                        _activeButton = '1year';
                                      });
                                    },
                                  ),

                                  // Min/Max Values of Parameters
                                  Padding(
                                    padding: EdgeInsets.only(
                                        top:
                                            MediaQuery.of(context).size.height *
                                                0.07),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (widget.deviceName.startsWith('WQ'))
                                          _buildMinMaxTable(
                                            isDarkMode,
                                            {
                                              'temp': tempData,
                                              'TDS': tdsData,
                                              'COD': codData,
                                              'BOD': bodData,
                                              'pH': pHData,
                                              'DO': doData,
                                              'EC': ecData,
                                            },
                                          ),
                                        if (widget.deviceName.startsWith('FS'))
                                          _buildMinMaxTable(
                                            isDarkMode,
                                            {
                                              'Temperature': fstempData,
                                              'Pressure': fspressureData,
                                              'Humidity': fshumidityData,
                                              'Rainfall': fsrainData,
                                              'Radiation': fsradiationData,
                                              'Wind Speed': fswindspeedData,
                                              'Wind Direction':
                                                  fswinddirectionData,
                                            },
                                          ),
                                        if (widget.deviceName.startsWith('CB'))
                                          _buildMinMaxTable(
                                            isDarkMode,
                                            {
                                              'temp': temp2Data,
                                              'COD': cod2Data,
                                              'BOD': bod2Data,
                                            },
                                          ),
                                        if (widget.deviceName.startsWith('NH'))
                                          _buildMinMaxTable(
                                            isDarkMode,
                                            {
                                              'AMMONIA': ammoniaData,
                                              'TEMP': temperaturedata,
                                              'HUMIDITY': humiditydata,
                                            },
                                          ),
                                        if (widget.deviceName.startsWith('DO'))
                                          _buildMinMaxTable(
                                            isDarkMode,
                                            {
                                              'Temperature': ttempData,
                                              'DO Value': dovaluedata,
                                              'DO Percentage': dopercentagedata,
                                            },
                                          ),
                                        if (widget.deviceName.startsWith('NA'))
                                          _buildMinMaxTable(
                                            isDarkMode,
                                            {
                                              'Temperature': NARLParametersData[
                                                      'CurrentTemperature'] ??
                                                  [],
                                              'Humidity': NARLParametersData[
                                                      'CurrentHumidity'] ??
                                                  [],
                                              'Light Intensity':
                                                  NARLParametersData[
                                                          'LightIntensity'] ??
                                                      [],
                                              'Wind Speed': NARLParametersData[
                                                      'WindSpeed'] ??
                                                  [],
                                              'Atm Pressure':
                                                  NARLParametersData[
                                                          'AtmPressure'] ??
                                                      [],
                                              'Wind Direction':
                                                  NARLParametersData[
                                                          'WindDirection'] ??
                                                      [],
                                              'Rainfall': NARLParametersData[
                                                      'RainfallHourly'] ??
                                                  [],
                                            },
                                          ),
                                        if (widget.deviceName.startsWith('KJ'))
                                          _buildMinMaxTable(
                                            isDarkMode,
                                            {
                                              'Temperature': KJParametersData[
                                                      'CurrentTemperature'] ??
                                                  [],
                                              'Humidity': KJParametersData[
                                                      'CurrentHumidity'] ??
                                                  [],
                                              'Potassium': KJParametersData[
                                                      'Potassium'] ??
                                                  [],
                                              'pH':
                                                  KJParametersData['pH'] ?? [],
                                              'Nitrogen': KJParametersData[
                                                      'Nitrogen'] ??
                                                  [],
                                              'Salinity': KJParametersData[
                                                      'Salinity'] ??
                                                  [],
                                              'ElectricalConductivity':
                                                  KJParametersData[
                                                          'ElectricalConductivity'] ??
                                                      [],
                                              'Phosphorus': KJParametersData[
                                                      'Phosphorus'] ??
                                                  [],
                                            },
                                          ),
                                        if (widget.deviceName.startsWith('MY'))
                                          _buildMinMaxTable(
                                            isDarkMode,
                                            {
                                              'Temperature': MYParametersData[
                                                      'CurrentTemperature'] ??
                                                  [],
                                              'Humidity': MYParametersData[
                                                      'CurrentHumidity'] ??
                                                  [],
                                              'Light Intensity':
                                                  MYParametersData[
                                                          'LightIntensity'] ??
                                                      [],
                                              'Wind Speed': MYParametersData[
                                                      'WindSpeed'] ??
                                                  [],
                                              'Atm Pressure': MYParametersData[
                                                      'AtmPressure'] ??
                                                  [],
                                              'Wind Direction':
                                                  MYParametersData[
                                                          'WindDirection'] ??
                                                      [],
                                              'Rainfall': MYParametersData[
                                                      'RainfallHourly'] ??
                                                  [],
                                            },
                                          ),
                                        if (widget.deviceName.startsWith('VD'))
                                          _buildMinMaxTable(
                                            isDarkMode,
                                            {
                                              'Temperature': vdParametersData[
                                                      'CurrentTemperature'] ??
                                                  [],
                                              'Humidity': vdParametersData[
                                                      'CurrentHumidity'] ??
                                                  [],
                                              'Light Intensity':
                                                  vdParametersData[
                                                          'LightIntensity'] ??
                                                      [],
                                              'Rainfall': vdParametersData[
                                                      'RainfallHourly'] ??
                                                  [],
                                            },
                                          ),
                                        if (widget.deviceName.startsWith('CF'))
                                          _buildMinMaxTable(
                                            isDarkMode,
                                            {
                                              'Temperature': cfParametersData[
                                                      'CurrentTemperature'] ??
                                                  [],
                                              'Humidity': cfParametersData[
                                                      'CurrentHumidity'] ??
                                                  [],
                                              'Light Intensity':
                                                  cfParametersData[
                                                          'LightIntensity'] ??
                                                      [],
                                              'Rainfall': cfParametersData[
                                                      'RainfallHourly'] ??
                                                  [],
                                              'Wind Speed': cfParametersData[
                                                      'WindSpeed'] ??
                                                  [],
                                              'Atm Pressure': cfParametersData[
                                                      'AtmPressure'] ??
                                                  [],
                                              'Wind Direction':
                                                  cfParametersData[
                                                          'WindDirection'] ??
                                                      [],
                                            },
                                          ),
                                        if (widget.deviceName.startsWith('CP'))
                                          _buildMinMaxTable(
                                            isDarkMode,
                                            {
                                              'Temperature': csParametersData[
                                                      'CurrentTemperature'] ??
                                                  [],
                                              'Humidity': csParametersData[
                                                      'CurrentHumidity'] ??
                                                  [],
                                              'Light Intensity':
                                                  csParametersData[
                                                          'LightIntensity'] ??
                                                      [],
                                              'Rainfall': csParametersData[
                                                      'RainfallHourly'] ??
                                                  [],
                                              'Wind Speed': csParametersData[
                                                      'WindSpeed'] ??
                                                  [],
                                              'Atm Pressure': csParametersData[
                                                      'AtmPressure'] ??
                                                  [],
                                              'Wind Direction':
                                                  csParametersData[
                                                          'WindDirection'] ??
                                                      [],
                                            },
                                          ),
// Modified Builder widget for total rainfall display within the sidebar
                                        Builder(
                                          builder: (context) {
                                            double totalRainfall = 0.0;
                                            bool showTotalRainfall = false;

                                            if (widget.deviceName.startsWith('FS') &&
                                                fsrainData.isNotEmpty) {
                                              showTotalRainfall = true;
                                              totalRainfall =
                                                  _calculateTotalRainfall(
                                                      fsrainData);
                                            } else if (widget.deviceName.startsWith('NA') &&
                                                NARLParametersData['RainfallHourly'] !=
                                                    null &&
                                                NARLParametersData['RainfallHourly']!
                                                    .isNotEmpty) {
                                              showTotalRainfall = true;
                                              totalRainfall =
                                                  _calculateTotalRainfall(
                                                      NARLParametersData[
                                                          'RainfallHourly']!);
                                            } else if (widget.deviceName.startsWith('MY') &&
                                                MYParametersData['RainfallHourly'] !=
                                                    null &&
                                                MYParametersData['RainfallHourly']!
                                                    .isNotEmpty) {
                                              showTotalRainfall = true;
                                              totalRainfall =
                                                  _calculateTotalRainfall(
                                                      MYParametersData[
                                                          'RainfallHourly']!);
                                            } else if (widget.deviceName.startsWith('VD') &&
                                                vdParametersData['RainfallHourly'] !=
                                                    null &&
                                                vdParametersData['RainfallHourly']!
                                                    .isNotEmpty) {
                                              showTotalRainfall = true;
                                              totalRainfall =
                                                  _calculateTotalRainfall(
                                                      vdParametersData[
                                                          'RainfallHourly']!);
                                            } else if (widget.deviceName
                                                    .startsWith('CF') &&
                                                cfParametersData['RainfallHourly'] !=
                                                    null &&
                                                cfParametersData['RainfallHourly']!
                                                    .isNotEmpty) {
                                              showTotalRainfall = true;
                                              totalRainfall =
                                                  _calculateTotalRainfall(
                                                      cfParametersData[
                                                          'RainfallHourly']!);
                                            } else if (widget.deviceName
                                                    .startsWith('CP') &&
                                                csParametersData['RainfallHourly'] !=
                                                    null &&
                                                csParametersData['RainfallHourly']!
                                                    .isNotEmpty) {
                                              showTotalRainfall = true;
                                              totalRainfall =
                                                  _calculateTotalRainfall(
                                                      csParametersData[
                                                          'RainfallHourly']!);
                                            } else if (widget.deviceName
                                                    .startsWith('IT') &&
                                                itrainData.isNotEmpty) {
                                              showTotalRainfall = true;
                                              totalRainfall =
                                                  _calculateTotalRainfall(
                                                      itrainData);
                                            } else if ((widget.deviceName
                                                        .startsWith('WD211') ||
                                                    widget.deviceName
                                                        .startsWith('WD511')) &&
                                                wfrainfallData.isNotEmpty) {
                                              showTotalRainfall = true;
                                              totalRainfall =
                                                  _calculateTotalRainfall(
                                                      wfrainfallData);
                                            }

                                            if (showTotalRainfall &&
                                                !_isLoading &&
                                                _errorMessage == null) {
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 16.0, left: 16),
                                                child: Text(
                                                  'Total Rainfall: ${totalRainfall.toStringAsFixed(2)} mm',
                                                  style: TextStyle(
                                                    color: isDarkMode
                                                        ? Colors.white
                                                        : Colors.black,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              );
                                            } else {
                                              return const SizedBox.shrink();
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Main content area for larger screens
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Horizontal row with stats, battery, and reload
                      Container(
                        padding: EdgeInsets.symmetric(
                            vertical: 8.0, horizontal: 16.0),
                        color: isDarkMode
                            ? Colors.blueGrey[900]
                            : Colors.grey[200],
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: MediaQuery.of(context).size.width < 1400
                                  ? SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child:
                                          _buildHorizontalStatsRow(isDarkMode),
                                    )
                                  : _buildHorizontalStatsRow(isDarkMode),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.deviceName.startsWith('WD'))
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _getBatteryIcon(
                                            _parseBatteryPercentage(
                                                _lastBatteryPercentage),
                                          ),
                                          size: 26,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          ': $_lastBatteryPercentage',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isDarkMode
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (widget.deviceName.startsWith('FS'))
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getpercentBatteryIcon(
                                                  _lastfsBattery),
                                              color: _getpercentBatteryColor(
                                                  _lastfsBattery),
                                              size: 28,
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              '${_convertVoltageToPercentage(_lastfsBattery).toStringAsFixed(2)} %',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isDarkMode
                                                    ? Colors.white
                                                    : Colors.black,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                if (widget.deviceName.startsWith('SM'))
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getpercentBatteryIcon(
                                                  _lastsmBattery),
                                              color: _getpercentBatteryColor(
                                                  _lastsmBattery),
                                              size: 28,
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              '${_convertVoltageToPercentage(_lastsmBattery).toStringAsFixed(2)} %',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isDarkMode
                                                    ? Colors.white
                                                    : Colors.black,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                if (widget.deviceName.startsWith('CF'))
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getpercentBatteryIcon(
                                                  _lastcfBattery),
                                              color: _getpercentBatteryColor(
                                                  _lastcfBattery),
                                              size: 28,
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              '${_convertVoltageToPercentage(_lastcfBattery).toStringAsFixed(2)} %',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isDarkMode
                                                    ? Colors.white
                                                    : Colors.black,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                if (widget.deviceName.startsWith('VD'))
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getpercentBatteryIcon(
                                                  _lastvdBattery),
                                              color: _getpercentBatteryColor(
                                                  _lastvdBattery),
                                              size: 28,
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              '${_convertVoltageToPercentage(_lastvdBattery).toStringAsFixed(2)} %',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isDarkMode
                                                    ? Colors.white
                                                    : Colors.black,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                if (widget.deviceName.startsWith('KD'))
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getpercentBatteryIcon(
                                                  _lastkdBattery),
                                              color: _getpercentBatteryColor(
                                                  _lastkdBattery),
                                              size: 28,
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              '${_convertVoltageToPercentage(_lastkdBattery).toStringAsFixed(2)} %',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isDarkMode
                                                    ? Colors.white
                                                    : Colors.black,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                if (widget.deviceName.startsWith('NA'))
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getpercentBatteryIcon(
                                                  _lastNARLBattery),
                                              color: _getpercentBatteryColor(
                                                  _lastNARLBattery),
                                              size: 28,
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              '${_convertVoltageToPercentage(_lastNARLBattery).toStringAsFixed(2)} %',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isDarkMode
                                                    ? Colors.white
                                                    : Colors.black,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                if (widget.deviceName.startsWith('KJ'))
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getpercentBatteryIcon(
                                                  _lastKJBattery),
                                              color: _getpercentBatteryColor(
                                                  _lastKJBattery),
                                              size: 28,
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              '${_convertVoltageToPercentage(_lastKJBattery).toStringAsFixed(2)} %',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isDarkMode
                                                    ? Colors.white
                                                    : Colors.black,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                if (widget.deviceName.startsWith('MY'))
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getpercentBatteryIcon(
                                                  _lastMYBattery),
                                              color: _getpercentBatteryColor(
                                                  _lastMYBattery),
                                              size: 28,
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              '${_convertVoltageToPercentage(_lastMYBattery).toStringAsFixed(2)} %',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isDarkMode
                                                    ? Colors.white
                                                    : Colors.black,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                if (widget.deviceName.startsWith('CP'))
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getpercentBatteryIcon(
                                                  _lastcsBattery),
                                              color: _getpercentBatteryColor(
                                                  _lastcsBattery),
                                              size: 28,
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              '${_convertVoltageToPercentage(_lastcsBattery).toStringAsFixed(2)} %',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isDarkMode
                                                    ? Colors.white
                                                    : Colors.black,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                if (widget.deviceName.startsWith('SV'))
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getpercentBatteryIcon(
                                                  _lastsvBattery),
                                              color: _getpercentBatteryColor(
                                                  _lastsvBattery),
                                              size: 28,
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              '${_convertVoltageToPercentage(_lastsvBattery).toStringAsFixed(2)} %',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isDarkMode
                                                    ? Colors.white
                                                    : Colors.black,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 12.0),
                                  child: RotationTransition(
                                    turns: Tween(begin: 0.0, end: 1.0)
                                        .animate(_rotationController),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.refresh,
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                        size: 26,
                                      ),
                                      onPressed: _isLoading
                                          ? null
                                          : () {
                                              _reloadData(
                                                  range: _lastSelectedRange);
                                            },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Main Content Area
                      Expanded(
                        child: SingleChildScrollView(
                          controller:
                              _scrollController, // Use ScrollController for scrolling
                          child: Container(
                            padding: EdgeInsets.only(top: 10),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(0.0),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Column(
                                        children: [
                                          SizedBox(height: 0),
                                          if (widget.deviceName
                                                  .startsWith('WD') &&
                                              isWindDirectionValid(
                                                  _lastWindDirection) &&
                                              _lastWindDirection.isNotEmpty)
                                            Column(
                                              children: [
                                                Icon(
                                                  Icons.wind_power,
                                                  size: 40,
                                                  color: Colors.white,
                                                ),
                                                SizedBox(height: 0),
                                                Text(
                                                  'Wind Direction : $_lastWindDirection',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 20,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          SizedBox(height: 0),
                                          if (widget.deviceName
                                              .startsWith('TE'))
                                            Text(
                                              'RSSI Value : $_lastRSSI_Value',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                                color: Colors.white,
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(0.0),
                                  child: Column(
                                    children: [
                                      if (widget.deviceName.startsWith('CL'))
                                        _buildCurrentValue('Chlorine Level',
                                            _currentChlorineValue, 'mg/L'),
                                      if (widget.deviceName.startsWith('20'))
                                        _buildCurrentValue('Rain Level ',
                                            _currentrfdValue, 'mm'),
                                      () {
                                        if (widget.deviceName
                                                .startsWith('IT') &&
                                            iswinddirectionValid(
                                                _lastwinddirection) &&
                                            _lastwinddirection.isNotEmpty) {
                                          return _buildWindCompass(
                                              _lastwinddirection);
                                        } else {
                                          return SizedBox.shrink();
                                        }
                                      }(),
                                    ],
                                  ),
                                ),
                                if (widget.deviceName.startsWith('WQ'))
                                  buildStatisticsTable(),
                                if (widget.deviceName.startsWith('CB'))
                                  buildCBStatisticsTable(),
                                if (widget.deviceName.startsWith('NH'))
                                  buildNHStatisticsTable(),
                                if (widget.deviceName.startsWith('DO'))
                                  buildDOStatisticsTable(),
                                if (widget.deviceName.startsWith('IT'))
                                  buildITStatisticsTable(),
                                if (widget.deviceName.startsWith('WD211') ||
                                    (widget.deviceName.startsWith('WD511')))
                                  SingleChildScrollView(
                                    child: Center(
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          double screenWidth =
                                              constraints.maxWidth;
                                          bool isLargeScreen =
                                              screenWidth > 800;
                                          return isLargeScreen
                                              ? Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    buildWeatherStatisticsTable(),
                                                    SizedBox(width: 5),
                                                    buildRainDataTable(),
                                                  ],
                                                )
                                              : Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    buildWeatherStatisticsTable(),
                                                    SizedBox(height: 5),
                                                    buildRainDataTable(),
                                                  ],
                                                );
                                        },
                                      ),
                                    ),
                                  ),
                                Column(
                                  children: [
                                    if (widget.deviceName.startsWith('SM'))
                                      ...[
                                        if (hasNonZeroValues(smParametersData[
                                                'CurrentTemperature'] ??
                                            []))
                                          _buildChartContainer(
                                              'Temperature',
                                              smParametersData[
                                                      'CurrentTemperature'] ??
                                                  [],
                                              '(°C)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(
                                            smParametersData['AtmPressure'] ??
                                                []))
                                          _buildChartContainer(
                                              'Pressure',
                                              smParametersData['AtmPressure'] ??
                                                  [],
                                              '(hPa)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(smParametersData[
                                                'CurrentHumidity'] ??
                                            []))
                                          _buildChartContainer(
                                              'Humidity',
                                              smParametersData[
                                                      'CurrentHumidity'] ??
                                                  [],
                                              '(%)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(smParametersData[
                                                'LightIntensity'] ??
                                            []))
                                          _buildChartContainer(
                                              'Light Intensity',
                                              smParametersData[
                                                      'LightIntensity'] ??
                                                  [],
                                              '(Lux)',
                                              ChartType.line,
                                              isDarkMode),
                                      ]
                                          .where((widget) =>
                                              widget != const SizedBox.shrink())
                                          .toList(),
                                    if (widget.deviceName.startsWith('SM'))
                                      _buildWindChartContainer(
                                        'Wind',
                                        smParametersData['WindSpeed'] ?? [],
                                        smParametersData['WindDirection'] ?? [],
                                        isDarkMode,
                                      ),
                                    if (widget.deviceName.startsWith('SM'))
                                      ...smParametersData.entries
                                          .where((entry) {
                                            String paramName = entry.key;
                                            List<ChartData> data = entry.value;
                                            List<String> excludedParams = [
                                              'Longitude',
                                              'Latitude',
                                              'SignalStrength',
                                              // 'BatteryVoltage',
                                              'WindSpeed',
                                              'WindDirection',
                                              'TemperatureHourlyComulative',
                                              'LuxHourlyComulative',
                                              'PressureHourlyComulative',
                                              'HumidityHourlyComulative'
                                            ];
                                            return !excludedParams
                                                    .contains(paramName) &&
                                                data.isNotEmpty;
                                          })
                                          .map((entry) {
                                            String paramName = entry.key;
                                            List<ChartData> data = entry.value;
                                            final displayInfo =
                                                _getParameterDisplayInfo(
                                                    paramName);
                                            String displayName =
                                                displayInfo['displayName'];
                                            String unit = displayInfo['unit'];
                                            String chartTitle;
                                            if (paramName.toLowerCase() ==
                                                'currenthumidity') {
                                              chartTitle = '($unit)';
                                            } else if (paramName
                                                    .toLowerCase() ==
                                                'currenttemperature') {
                                              chartTitle = '($unit)';
                                            } else {
                                              chartTitle = unit.isNotEmpty
                                                  ? '($unit)'
                                                  : displayName;
                                            }
                                            if ([
                                              'CurrentTemperature',
                                              'AtmPressure',
                                              'CurrentHumidity',
                                              'LightIntensity'
                                            ].contains(paramName)) {
                                              return const SizedBox
                                                  .shrink(); // Skip these as they are handled above
                                            }
                                            return _buildChartContainer(
                                                displayName,
                                                data,
                                                chartTitle,
                                                ChartType.line,
                                                isDarkMode);
                                          })
                                          .where((widget) =>
                                              widget != const SizedBox.shrink())
                                          .toList(),
                                    if (widget.deviceName.startsWith('CF'))
                                      ...[
                                        if (hasNonZeroValues(cfParametersData[
                                                'CurrentTemperature'] ??
                                            []))
                                          _buildChartContainer(
                                              'Temperature',
                                              cfParametersData[
                                                      'CurrentTemperature'] ??
                                                  [],
                                              '(°C)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(
                                            cfParametersData['AtmPressure'] ??
                                                []))
                                          _buildChartContainer(
                                              'Pressure',
                                              cfParametersData['AtmPressure'] ??
                                                  [],
                                              '(hPa)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(cfParametersData[
                                                'CurrentHumidity'] ??
                                            []))
                                          _buildChartContainer(
                                              'Humidity',
                                              cfParametersData[
                                                      'CurrentHumidity'] ??
                                                  [],
                                              '(%)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(cfParametersData[
                                                'LightIntensity'] ??
                                            []))
                                          _buildChartContainer(
                                              'Light Intensity',
                                              cfParametersData[
                                                      'LightIntensity'] ??
                                                  [],
                                              '(Lux)',
                                              ChartType.line,
                                              isDarkMode),
                                      ]
                                          .where((widget) =>
                                              widget != const SizedBox.shrink())
                                          .toList(),
                                    if (widget.deviceName.startsWith('CF'))
                                      _buildWindChartContainer(
                                        'Wind',
                                        cfParametersData['WindSpeed'] ?? [],
                                        cfParametersData['WindDirection'] ?? [],
                                        isDarkMode,
                                      ),
                                    if (widget.deviceName.startsWith('CF'))
                                      ...cfParametersData.entries
                                          .where((entry) {
                                            String paramName = entry.key;
                                            List<ChartData> data = entry.value;
                                            List<String> excludedParams = [
                                              'Longitude',
                                              'Latitude',
                                              'SignalStrength',
                                              // 'BatteryVoltage',
                                              'WindSpeed',
                                              'WindDirection',
                                              'MaximumTemperature',
                                              'MinimumTemperature',
                                              'AverageTemperature',
                                              'RainfallDaily',
                                              'RainfallWeekly',
                                              'RainfallMinutly',
                                              'AverageHumidity',
                                              'MinimumHumidity',
                                              'MaximumHumidity',
                                              'HumidityHourlyComulative',
                                              'PressureHourlyComulative',
                                              'LuxHourlyComulative',
                                              'TemperatureHourlyComulative',
                                            ];
                                            return !excludedParams
                                                    .contains(paramName) &&
                                                data.isNotEmpty;
                                          })
                                          .map((entry) {
                                            String paramName = entry.key;
                                            List<ChartData> data = entry.value;
                                            final displayInfo =
                                                _getParameterDisplayInfo(
                                                    paramName);
                                            String displayName =
                                                displayInfo['displayName'];
                                            String unit = displayInfo['unit'];
                                            String chartTitle;
                                            if (paramName.toLowerCase() ==
                                                'currenthumidity') {
                                              chartTitle = '($unit)';
                                            } else if (paramName
                                                    .toLowerCase() ==
                                                'currenttemperature') {
                                              chartTitle = '($unit)';
                                            } else {
                                              chartTitle = unit.isNotEmpty
                                                  ? '($unit)'
                                                  : displayName;
                                            }
                                            if ([
                                              'CurrentTemperature',
                                              'AtmPressure',
                                              'CurrentHumidity',
                                              'LightIntensity'
                                            ].contains(paramName)) {
                                              return const SizedBox
                                                  .shrink(); // Skip these as they are handled above
                                            }
                                            return _buildChartContainer(
                                                displayName,
                                                data,
                                                chartTitle,
                                                ChartType.line,
                                                isDarkMode);
                                          })
                                          .where((widget) =>
                                              widget != const SizedBox.shrink())
                                          .toList(),
                                    if (widget.deviceName.startsWith('VD'))
                                      ...[
                                        if (hasNonZeroValues(vdParametersData[
                                                'CurrentTemperature'] ??
                                            []))
                                          _buildChartContainer(
                                              'Temperature',
                                              vdParametersData[
                                                      'CurrentTemperature'] ??
                                                  [],
                                              '(°C)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(
                                            vdParametersData['AtmPressure'] ??
                                                []))
                                          _buildChartContainer(
                                              'Pressure',
                                              vdParametersData['AtmPressure'] ??
                                                  [],
                                              '(hPa)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(vdParametersData[
                                                'CurrentHumidity'] ??
                                            []))
                                          _buildChartContainer(
                                              'Humidity',
                                              vdParametersData[
                                                      'CurrentHumidity'] ??
                                                  [],
                                              '(%)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(vdParametersData[
                                                'LightIntensity'] ??
                                            []))
                                          _buildChartContainer(
                                              'Light Intensity',
                                              vdParametersData[
                                                      'LightIntensity'] ??
                                                  [],
                                              '(Lux)',
                                              ChartType.line,
                                              isDarkMode),
                                      ]
                                          .where((widget) =>
                                              widget != const SizedBox.shrink())
                                          .toList(),
                                    if (widget.deviceName.startsWith('VD'))
                                      _buildWindChartContainer(
                                        'Wind',
                                        vdParametersData['WindSpeed'] ?? [],
                                        vdParametersData['WindDirection'] ?? [],
                                        isDarkMode,
                                      ),
                                    if (widget.deviceName.startsWith('VD'))
                                      ...vdParametersData.entries
                                          .where((entry) {
                                            String paramName = entry.key;
                                            List<ChartData> data = entry.value;
                                            List<String> excludedParams = [
                                              'Longitude',
                                              'Latitude',
                                              'SignalStrength',
                                              // 'BatteryVoltage',
                                              'WindSpeed',
                                              'WindDirection',
                                              'MaximumTemperature',
                                              'MinimumTemperature',
                                              'AverageTemperature',
                                              'RainfallDaily',
                                              'RainfallWeekly',
                                              'AverageHumidity',
                                              'MinimumHumidity',
                                              'MaximumHumidity',
                                            ];
                                            return !excludedParams
                                                    .contains(paramName) &&
                                                data.isNotEmpty;
                                          })
                                          .map((entry) {
                                            String paramName = entry.key;
                                            List<ChartData> data = entry.value;
                                            final displayInfo =
                                                _getParameterDisplayInfo(
                                                    paramName);
                                            String displayName =
                                                displayInfo['displayName'];
                                            String unit = displayInfo['unit'];
                                            String chartTitle;
                                            if (paramName.toLowerCase() ==
                                                'currenthumidity') {
                                              chartTitle = '($unit)';
                                            } else if (paramName
                                                    .toLowerCase() ==
                                                'currenttemperature') {
                                              chartTitle = '($unit)';
                                            } else {
                                              chartTitle = unit.isNotEmpty
                                                  ? '$displayName ($unit)'
                                                  : displayName;
                                            }
                                            if ([
                                              'CurrentTemperature',
                                              'AtmPressure',
                                              'CurrentHumidity',
                                              'LightIntensity'
                                            ].contains(paramName)) {
                                              return const SizedBox
                                                  .shrink(); // Skip these as they are handled above
                                            }
                                            return _buildChartContainer(
                                                displayName,
                                                data,
                                                chartTitle,
                                                ChartType.line,
                                                isDarkMode);
                                          })
                                          .where((widget) =>
                                              widget != const SizedBox.shrink())
                                          .toList(),
                                    if (widget.deviceName.startsWith('KD'))
                                      ...[
                                        if (hasNonZeroValues(kdParametersData[
                                                'CurrentTemperature'] ??
                                            []))
                                          _buildChartContainer(
                                              'Temperature',
                                              kdParametersData[
                                                      'CurrentTemperature'] ??
                                                  [],
                                              '(°C)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(
                                            kdParametersData['AtmPressure'] ??
                                                []))
                                          _buildChartContainer(
                                              'Pressure',
                                              kdParametersData['AtmPressure'] ??
                                                  [],
                                              '(hPa)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(kdParametersData[
                                                'CurrentHumidity'] ??
                                            []))
                                          _buildChartContainer(
                                              'Humidity',
                                              kdParametersData[
                                                      'CurrentHumidity'] ??
                                                  [],
                                              '(%)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(kdParametersData[
                                                'LightIntensity'] ??
                                            []))
                                          _buildChartContainer(
                                              'Light Intensity',
                                              kdParametersData[
                                                      'LightIntensity'] ??
                                                  [],
                                              '(Lux)',
                                              ChartType.line,
                                              isDarkMode),
                                      ]
                                          .where((widget) =>
                                              widget != const SizedBox.shrink())
                                          .toList(),
                                    if (widget.deviceName.startsWith('KD'))
                                      _buildWindChartContainer(
                                        'Wind',
                                        kdParametersData['WindSpeed'] ?? [],
                                        kdParametersData['WindDirection'] ?? [],
                                        isDarkMode,
                                      ),
                                    if (widget.deviceName.startsWith('KD'))
                                      ...kdParametersData.entries
                                          .where((entry) {
                                            String paramName = entry.key;
                                            List<ChartData> data = entry.value;
                                            List<String> excludedParams = [
                                              'Longitude',
                                              'Latitude',
                                              'SignalStrength',
                                              // 'BatteryVoltage',
                                              'WindSpeed',
                                              'WindDirection',
                                              'MaximumTemperature',
                                              'MinimumTemperature',
                                              'AverageTemperature',
                                              'RainfallDaily',
                                              'RainfallWeekly',
                                              'AverageHumidity',
                                              'MinimumHumidity',
                                              'MaximumHumidity',
                                            ];
                                            return !excludedParams
                                                    .contains(paramName) &&
                                                data.isNotEmpty;
                                          })
                                          .map((entry) {
                                            String paramName = entry.key;
                                            List<ChartData> data = entry.value;
                                            final displayInfo =
                                                _getParameterDisplayInfo(
                                                    paramName);
                                            String displayName =
                                                displayInfo['displayName'];
                                            String unit = displayInfo['unit'];
                                            String chartTitle;
                                            if (paramName.toLowerCase() ==
                                                'currenthumidity') {
                                              chartTitle = '($unit)';
                                            } else if (paramName
                                                    .toLowerCase() ==
                                                'currenttemperature') {
                                              chartTitle = '($unit)';
                                            } else {
                                              chartTitle = unit.isNotEmpty
                                                  ? '$displayName ($unit)'
                                                  : displayName;
                                            }
                                            if ([
                                              'CurrentTemperature',
                                              'AtmPressure',
                                              'CurrentHumidity',
                                              'LightIntensity'
                                            ].contains(paramName)) {
                                              return const SizedBox
                                                  .shrink(); // Skip these as they are handled above
                                            }
                                            return _buildChartContainer(
                                                displayName,
                                                data,
                                                chartTitle,
                                                ChartType.line,
                                                isDarkMode);
                                          })
                                          .where((widget) =>
                                              widget != const SizedBox.shrink())
                                          .toList(),
                                    if (widget.deviceName.startsWith('NA'))
                                      ...[
                                        if (hasNonZeroValues(NARLParametersData[
                                                'CurrentTemperature'] ??
                                            []))
                                          _buildChartContainer(
                                              'Temperature',
                                              NARLParametersData[
                                                      'CurrentTemperature'] ??
                                                  [],
                                              '(°C)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(
                                            NARLParametersData['AtmPressure'] ??
                                                []))
                                          _buildChartContainer(
                                              'Pressure',
                                              NARLParametersData[
                                                      'AtmPressure'] ??
                                                  [],
                                              '(hPa)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(NARLParametersData[
                                                'CurrentHumidity'] ??
                                            []))
                                          _buildChartContainer(
                                              'Humidity',
                                              NARLParametersData[
                                                      'CurrentHumidity'] ??
                                                  [],
                                              '(%)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(NARLParametersData[
                                                'LightIntensity'] ??
                                            []))
                                          _buildChartContainer(
                                              'Light Intensity',
                                              NARLParametersData[
                                                      'LightIntensity'] ??
                                                  [],
                                              '(Lux)',
                                              ChartType.line,
                                              isDarkMode),
                                      ]
                                          .where((widget) =>
                                              widget != const SizedBox.shrink())
                                          .toList(),
                                    if (widget.deviceName.startsWith('NA'))
                                      _buildWindChartContainer(
                                        'Wind',
                                        NARLParametersData['WindSpeed'] ?? [],
                                        NARLParametersData['WindDirection'] ??
                                            [],
                                        isDarkMode,
                                      ),
                                    if (widget.deviceName.startsWith('NA'))
                                      ...NARLParametersData.entries
                                          .where((entry) {
                                            String paramName = entry.key;
                                            List<ChartData> data = entry.value;
                                            List<String> excludedParams = [
                                              'Longitude',
                                              'Latitude',
                                              'SignalStrength',
                                              // 'BatteryVoltage',
                                              'WindSpeed',
                                              'WindDirection',
                                              'MaximumTemperature',
                                              'MinimumTemperature',
                                              'AverageTemperature',
                                              'RainfallDaily',
                                              'RainfallWeekly',
                                              'RainfallMinutly',
                                              'AverageHumidity',
                                              'MinimumHumidity',
                                              'MaximumHumidity',
                                              'HumidityHourlyComulative',
                                              'PressureHourlyComulative',
                                              'LuxHourlyComulative',
                                              'TemperatureHourlyComulative',
                                            ];
                                            return !excludedParams
                                                    .contains(paramName) &&
                                                data.isNotEmpty;
                                          })
                                          .map((entry) {
                                            String paramName = entry.key;
                                            List<ChartData> data = entry.value;
                                            final displayInfo =
                                                _getParameterDisplayInfo(
                                                    paramName);
                                            String displayName =
                                                displayInfo['displayName'];
                                            String unit = displayInfo['unit'];
                                            String chartTitle;
                                            if (paramName.toLowerCase() ==
                                                'currenthumidity') {
                                              chartTitle = '($unit)';
                                            } else if (paramName
                                                    .toLowerCase() ==
                                                'currenttemperature') {
                                              chartTitle = '($unit)';
                                            } else {
                                              chartTitle = unit.isNotEmpty
                                                  ? '($unit)'
                                                  : displayName;
                                            }
                                            if ([
                                              'CurrentTemperature',
                                              'AtmPressure',
                                              'CurrentHumidity',
                                              'LightIntensity'
                                            ].contains(paramName)) {
                                              return const SizedBox
                                                  .shrink(); // Skip these as they are handled above
                                            }
                                            return _buildChartContainer(
                                                displayName,
                                                data,
                                                chartTitle,
                                                ChartType.line,
                                                isDarkMode);
                                          })
                                          .where((widget) =>
                                              widget != const SizedBox.shrink())
                                          .toList(),
                                    if (widget.deviceName.startsWith('KJ'))
                                      ...[
                                        if (hasNonZeroValues(KJParametersData[
                                                'CurrentTemperature'] ??
                                            []))
                                          _buildChartContainer(
                                              'Temperature',
                                              KJParametersData[
                                                      'CurrentTemperature'] ??
                                                  [],
                                              '(°C)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(
                                            KJParametersData['AtmPressure'] ??
                                                []))
                                          _buildChartContainer(
                                              'Pressure',
                                              KJParametersData['AtmPressure'] ??
                                                  [],
                                              '(hPa)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(KJParametersData[
                                                'CurrentHumidity'] ??
                                            []))
                                          _buildChartContainer(
                                              'Humidity',
                                              KJParametersData[
                                                      'CurrentHumidity'] ??
                                                  [],
                                              '(%)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(KJParametersData[
                                                'LightIntensity'] ??
                                            []))
                                          _buildChartContainer(
                                              'Light Intensity',
                                              KJParametersData[
                                                      'LightIntensity'] ??
                                                  [],
                                              '(Lux)',
                                              ChartType.line,
                                              isDarkMode),
                                      ]
                                          .where((widget) =>
                                              widget != const SizedBox.shrink())
                                          .toList(),
                                    if (widget.deviceName.startsWith('KJ'))
                                      _buildWindChartContainer(
                                        'Wind',
                                        KJParametersData['WindSpeed'] ?? [],
                                        KJParametersData['WindDirection'] ?? [],
                                        isDarkMode,
                                      ),
                                    if (widget.deviceName.startsWith('KJ'))
                                      ...KJParametersData.entries
                                          .where((entry) {
                                            String paramName = entry.key;
                                            List<ChartData> data = entry.value;
                                            List<String> excludedParams = [
                                              'Longitude',
                                              'Latitude',
                                              'SignalStrength',
                                              // 'BatteryVoltage',
                                              'WindSpeed',
                                              'WindDirection',
                                              'MaximumTemperature',
                                              'MinimumTemperature',
                                              'AverageTemperature',
                                              'RainfallDaily',
                                              'RainfallWeekly',
                                              'RainfallHourly',
                                              'RainfallMinutly',
                                              'AverageHumidity',
                                              'MinimumHumidity',
                                              'MaximumHumidity',
                                              'HumidityHourlyComulative',
                                              'PressureHourlyComulative',
                                              'LuxHourlyComulative',
                                              'TemperatureHourlyComulative',
                                              'AtmPressure',
                                              'Light Intensity',
                                              'Wind Direction',
                                              'Wind Speed',
                                            ];
                                            return !excludedParams
                                                    .contains(paramName) &&
                                                data.isNotEmpty;
                                          })
                                          .map((entry) {
                                            String paramName = entry.key;
                                            List<ChartData> data = entry.value;
                                            final displayInfo =
                                                _getParameterDisplayInfo(
                                                    paramName);
                                            String displayName =
                                                displayInfo['displayName'];
                                            String unit = displayInfo['unit'];
                                            String chartTitle;
                                            if (paramName.toLowerCase() ==
                                                'currenthumidity') {
                                              chartTitle = '($unit)';
                                            } else if (paramName
                                                    .toLowerCase() ==
                                                'currenttemperature') {
                                              chartTitle = '($unit)';
                                            } else {
                                              chartTitle = unit.isNotEmpty
                                                  ? '($unit)'
                                                  : displayName;
                                            }
                                            if ([
                                              'CurrentTemperature',
                                              'AtmPressure',
                                              'CurrentHumidity',
                                              'LightIntensity'
                                            ].contains(paramName)) {
                                              return const SizedBox
                                                  .shrink(); // Skip these as they are handled above
                                            }
                                            return _buildChartContainer(
                                                displayName,
                                                data,
                                                chartTitle,
                                                ChartType.line,
                                                isDarkMode);
                                          })
                                          .where((widget) =>
                                              widget != const SizedBox.shrink())
                                          .toList(),
                                    if (widget.deviceName.startsWith('MY'))
                                      ...[
                                        if (hasNonZeroValues(MYParametersData[
                                                'CurrentTemperature'] ??
                                            []))
                                          _buildChartContainer(
                                              'Temperature',
                                              MYParametersData[
                                                      'CurrentTemperature'] ??
                                                  [],
                                              '(°C)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(
                                            MYParametersData['AtmPressure'] ??
                                                []))
                                          _buildChartContainer(
                                              'Pressure',
                                              MYParametersData['AtmPressure'] ??
                                                  [],
                                              '(hPa)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(MYParametersData[
                                                'CurrentHumidity'] ??
                                            []))
                                          _buildChartContainer(
                                              'Humidity',
                                              MYParametersData[
                                                      'CurrentHumidity'] ??
                                                  [],
                                              '(%)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(MYParametersData[
                                                'LightIntensity'] ??
                                            []))
                                          _buildChartContainer(
                                              'Light Intensity',
                                              MYParametersData[
                                                      'LightIntensity'] ??
                                                  [],
                                              '(Lux)',
                                              ChartType.line,
                                              isDarkMode),
                                      ]
                                          .where((widget) =>
                                              widget != const SizedBox.shrink())
                                          .toList(),
                                    if (widget.deviceName.startsWith('MY'))
                                      _buildWindChartContainer(
                                        'Wind',
                                        MYParametersData['WindSpeed'] ?? [],
                                        MYParametersData['WindDirection'] ?? [],
                                        isDarkMode,
                                      ),
                                    if (widget.deviceName.startsWith('MY'))
                                      ...MYParametersData.entries
                                          .where((entry) {
                                            String paramName = entry.key;
                                            List<ChartData> data = entry.value;
                                            List<String> excludedParams = [
                                              'Longitude',
                                              'Latitude',
                                              'SignalStrength',
                                              'BatteryVoltage',
                                              'MaximumTemperature',
                                              'MinimumTemperature',
                                              'AverageTemperature',
                                              'RainfallDaily',
                                              'RainfallWeekly',
                                              'RainfallMinutly',
                                              'AverageHumidity',
                                              'MinimumHumidity',
                                              'MaximumHumidity',
                                              'HumidityHourlyComulative',
                                              'PressureHourlyComulative',
                                              'LuxHourlyComulative',
                                              'TemperatureHourlyComulative',
                                              'WindSpeed',
                                              'WindDirection',
                                            ];
                                            return !excludedParams
                                                    .contains(paramName) &&
                                                data.isNotEmpty;
                                          })
                                          .map((entry) {
                                            String paramName = entry.key;
                                            List<ChartData> data = entry.value;
                                            final displayInfo =
                                                _getParameterDisplayInfo(
                                                    paramName);
                                            String displayName =
                                                displayInfo['displayName'];
                                            String unit = displayInfo['unit'];
                                            String chartTitle;
                                            if (paramName.toLowerCase() ==
                                                'currenthumidity') {
                                              chartTitle = '($unit)';
                                            } else if (paramName
                                                    .toLowerCase() ==
                                                'currenttemperature') {
                                              chartTitle = '($unit)';
                                            } else {
                                              chartTitle = unit.isNotEmpty
                                                  ? '($unit)'
                                                  : displayName;
                                            }
                                            if ([
                                              'CurrentTemperature',
                                              'AtmPressure',
                                              'CurrentHumidity',
                                              'LightIntensity'
                                            ].contains(paramName)) {
                                              return const SizedBox
                                                  .shrink(); // Skip these as they are handled above
                                            }
                                            return _buildChartContainer(
                                                displayName,
                                                data,
                                                chartTitle,
                                                ChartType.line,
                                                isDarkMode);
                                          })
                                          .where((widget) =>
                                              widget != const SizedBox.shrink())
                                          .toList(),
                                    if (widget.deviceName.startsWith('CP'))
                                      ...[
                                        if (hasNonZeroValues(csParametersData[
                                                'CurrentTemperature'] ??
                                            []))
                                          _buildChartContainer(
                                              'Temperature',
                                              csParametersData[
                                                      'CurrentTemperature'] ??
                                                  [],
                                              '(°C)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(
                                            csParametersData['AtmPressure'] ??
                                                []))
                                          _buildChartContainer(
                                              'Pressure',
                                              csParametersData['AtmPressure'] ??
                                                  [],
                                              '(hPa)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(csParametersData[
                                                'CurrentHumidity'] ??
                                            []))
                                          _buildChartContainer(
                                              'Humidity',
                                              csParametersData[
                                                      'CurrentHumidity'] ??
                                                  [],
                                              '(%)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(csParametersData[
                                                'LightIntensity'] ??
                                            []))
                                          _buildChartContainer(
                                              'Light Intensity',
                                              csParametersData[
                                                      'LightIntensity'] ??
                                                  [],
                                              '(Lux)',
                                              ChartType.line,
                                              isDarkMode),
                                      ]
                                          .where((widget) =>
                                              widget != const SizedBox.shrink())
                                          .toList(),
                                    if (widget.deviceName.startsWith('CP'))
                                      _buildWindChartContainer(
                                        'Wind',
                                        csParametersData['WindSpeed'] ?? [],
                                        csParametersData['WindDirection'] ?? [],
                                        isDarkMode,
                                      ),
                                    if (widget.deviceName.startsWith('CP'))
                                      ...csParametersData.entries
                                          .where((entry) {
                                            String paramName = entry.key;
                                            List<ChartData> data = entry.value;
                                            List<String> excludedParams = [
                                              'Longitude',
                                              'Latitude',
                                              'SignalStrength',
                                              // 'BatteryVoltage',
                                              'WindSpeed',
                                              'WindDirection',
                                              'MaximumTemperature',
                                              'MinimumTemperature',
                                              'AverageTemperature',
                                              'RainfallMinutly',
                                              'RainfallDaily',
                                              'RainfallWeekly',
                                              'AverageHumidity',
                                              'MinimumHumidity',
                                              'MaximumHumidity',
                                              'HumidityHourlyComulative',
                                              'PressureHourlyComulative',
                                              'LuxHourlyComulative',
                                              'TemperatureHourlyComulative',
                                            ];
                                            return !excludedParams
                                                    .contains(paramName) &&
                                                data.isNotEmpty;
                                          })
                                          .map((entry) {
                                            String paramName = entry.key;
                                            List<ChartData> data = entry.value;
                                            final displayInfo =
                                                _getParameterDisplayInfo(
                                                    paramName);
                                            String displayName =
                                                displayInfo['displayName'];
                                            String unit = displayInfo['unit'];
                                            String chartTitle;
                                            if (paramName.toLowerCase() ==
                                                'currenthumidity') {
                                              chartTitle = '($unit)';
                                            } else if (paramName
                                                    .toLowerCase() ==
                                                'currenttemperature') {
                                              chartTitle = '($unit)';
                                            } else {
                                              chartTitle = unit.isNotEmpty
                                                  ? '($unit)'
                                                  : displayName;
                                            }
                                            if ([
                                              'CurrentTemperature',
                                              'AtmPressure',
                                              'CurrentHumidity',
                                              'LightIntensity'
                                            ].contains(paramName)) {
                                              return const SizedBox
                                                  .shrink(); // Skip these as they are handled above
                                            }
                                            return _buildChartContainer(
                                                displayName,
                                                data,
                                                chartTitle,
                                                ChartType.line,
                                                isDarkMode);
                                          })
                                          .where((widget) =>
                                              widget != const SizedBox.shrink())
                                          .toList(),
                                    if (widget.deviceName.startsWith('SV'))
                                      ...svParametersData.entries
                                          .where((entry) {
                                            String paramName = entry.key;
                                            List<ChartData> data = entry.value;
                                            List<String> excludedParams = [
                                              'Longitude',
                                              'Latitude',
                                              'SignalStrength',
                                              // 'BatteryVoltage',
                                              'MaximumTemperature',
                                              'MinimumTemperature',
                                              'AverageTemperature',
                                              'RainfallDaily',
                                              'RainfallWeekly',
                                              'RainfallMinutly',
                                              'AverageHumidity',
                                              'MinimumHumidity',
                                              'MaximumHumidity',
                                              'HumidityHourlyComulative',
                                              'PressureHourlyComulative',
                                              'LuxHourlyComulative',
                                              'TemperatureHourlyComulative',
                                            ];
                                            return !excludedParams
                                                    .contains(paramName) &&
                                                data.isNotEmpty;
                                          })
                                          .map((entry) {
                                            String paramName = entry.key;
                                            List<ChartData> data = entry.value;
                                            final displayInfo =
                                                _getParameterDisplayInfo(
                                                    paramName);
                                            String displayName =
                                                displayInfo['displayName'];
                                            String unit = displayInfo['unit'];
                                            String chartTitle;
                                            if (paramName.toLowerCase() ==
                                                'currenthumidity') {
                                              chartTitle = '($unit)';
                                            } else if (paramName
                                                    .toLowerCase() ==
                                                'currenttemperature') {
                                              chartTitle = '($unit)';
                                            } else {
                                              chartTitle = unit.isNotEmpty
                                                  ? '($unit)'
                                                  : displayName;
                                            }
                                            return _buildChartContainer(
                                                displayName,
                                                data,
                                                chartTitle,
                                                ChartType.line,
                                                isDarkMode);
                                          })
                                          .where((widget) =>
                                              widget != const SizedBox.shrink())
                                          .toList(),
                                    if (!widget.deviceName.startsWith('SM') &&
                                        !widget.deviceName.startsWith('CF') &&
                                        !widget.deviceName.startsWith('VD') &&
                                        !widget.deviceName.startsWith('KD') &&
                                        !widget.deviceName.startsWith('NA') &&
                                        !widget.deviceName.startsWith('KJ') &&
                                        !widget.deviceName.startsWith('MY') &&
                                        !widget.deviceName.startsWith('CP') &&
                                        !widget.deviceName.startsWith('SV'))
                                      ...[
                                        if (hasNonZeroValues(chlorineData))
                                          _buildChartContainer(
                                              'Chlorine',
                                              chlorineData,
                                              '(mg/L)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(temperatureData))
                                          _buildChartContainer(
                                              'Temperature',
                                              temperatureData,
                                              '(°C)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(humidityData))
                                          _buildChartContainer(
                                              'Humidity',
                                              humidityData,
                                              '(%)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(
                                            lightIntensityData))
                                          _buildChartContainer(
                                              'Light Intensity',
                                              lightIntensityData,
                                              '(Lux)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(windSpeedData))
                                          _buildChartContainer(
                                              'Wind Speed',
                                              windSpeedData,
                                              '(m/s)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(
                                            solarIrradianceData))
                                          _buildChartContainer(
                                              'Solar Irradiance',
                                              solarIrradianceData,
                                              '(W/M^2)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(tempData))
                                          _buildChartContainer(
                                              'Temperature',
                                              tempData,
                                              '(°C)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(tdsData))
                                          _buildChartContainer(
                                              'TDS',
                                              tdsData,
                                              '(ppm)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(codData))
                                          _buildChartContainer(
                                              'COD',
                                              codData,
                                              '(mg/L)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(bodData))
                                          _buildChartContainer(
                                              'BOD',
                                              bodData,
                                              '(mg/L)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(pHData))
                                          _buildChartContainer('pH', pHData,
                                              'pH', ChartType.line, isDarkMode),
                                        if (hasNonZeroValues(doData))
                                          _buildChartContainer(
                                              'DO',
                                              doData,
                                              '(mg/L)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(ecData))
                                          _buildChartContainer(
                                              'EC',
                                              ecData,
                                              '(mS/cm)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(temppData))
                                          _buildChartContainer(
                                              'Temperature',
                                              temppData,
                                              '(°C)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(
                                            electrodeSignalData))
                                          _buildChartContainer(
                                              'Electrode Signal',
                                              electrodeSignalData,
                                              '(mV)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(
                                            residualchlorineData))
                                          _buildChartContainer(
                                              'Chlorine',
                                              residualchlorineData,
                                              '(mg/L)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(hypochlorousData))
                                          _buildChartContainer(
                                              'Hypochlorous',
                                              hypochlorousData,
                                              '(mg/L)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(temmppData))
                                          _buildChartContainer(
                                              'Temperature',
                                              temmppData,
                                              '(°C)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(humidityyData))
                                          _buildChartContainer(
                                              'Humidity',
                                              humidityyData,
                                              '(%)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(
                                            lightIntensityyData))
                                          _buildChartContainer(
                                              'Light Intensity',
                                              lightIntensityyData,
                                              '(Lux)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(windSpeeddData))
                                          _buildChartContainer(
                                              'Wind Speed',
                                              windSpeeddData,
                                              '(m/s)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(ttempData))
                                          _buildChartContainer(
                                              'Temperature',
                                              ttempData,
                                              '(°C)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(dovaluedata))
                                          _buildChartContainer(
                                              'DO Value',
                                              dovaluedata,
                                              '(mg/L)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(dopercentagedata))
                                          _buildChartContainer(
                                              'DO Percentage',
                                              dopercentagedata,
                                              '(%)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(temperaturData))
                                          _buildChartContainer(
                                              'Temperature',
                                              temperaturData,
                                              '(°C)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(humData))
                                          _buildChartContainer(
                                              'Humidity',
                                              humData,
                                              '(%)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(luxData))
                                          _buildChartContainer(
                                              'Light Intensity',
                                              luxData,
                                              '(Lux)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(coddata))
                                          _buildChartContainer(
                                              'COD',
                                              coddata,
                                              '(mg/L)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(boddata))
                                          _buildChartContainer(
                                              'BOD',
                                              boddata,
                                              '(mg/L)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(phdata))
                                          _buildChartContainer('pH', phdata,
                                              'pH', ChartType.line, isDarkMode),
                                        if (hasNonZeroValues(temperattureData))
                                          _buildChartContainer(
                                              'Temperature',
                                              temperattureData,
                                              '(°C)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(humidittyData))
                                          _buildChartContainer(
                                              'Humidity',
                                              humidittyData,
                                              '(%)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(ammoniaData))
                                          _buildChartContainer(
                                              'Ammonia',
                                              ammoniaData,
                                              '(PPM)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(temperaturedata))
                                          _buildChartContainer(
                                              'Temperature',
                                              temperaturedata,
                                              '(°C)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(humiditydata))
                                          _buildChartContainer(
                                              'Humidity',
                                              humiditydata,
                                              '(%)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(ittempData))
                                          _buildChartContainer(
                                              'Temperature',
                                              ittempData,
                                              '(°C)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(itpressureData))
                                          _buildChartContainer(
                                              'Pressure',
                                              itpressureData,
                                              '(hPa)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(ithumidityData))
                                          _buildChartContainer(
                                              'Humidity',
                                              ithumidityData,
                                              '(%)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(itrainData))
                                          _buildChartContainer(
                                              'Rain Level',
                                              itrainData,
                                              '(mm)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(itwindspeedData))
                                          _buildChartContainer(
                                              'Wind Speed',
                                              itwindspeedData,
                                              '(m/s)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(itradiationData))
                                          _buildChartContainer(
                                              'Radiation',
                                              itradiationData,
                                              '(W/m²)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(itvisibilityData))
                                          _buildChartContainer(
                                              'Visibility',
                                              itvisibilityData,
                                              '(m)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(fstempData))
                                          _buildChartContainer(
                                              'Temperature',
                                              fstempData,
                                              '(°C)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(fspressureData))
                                          _buildChartContainer(
                                              'Pressure',
                                              fspressureData,
                                              '(hPa)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(fshumidityData))
                                          _buildChartContainer(
                                              'Humidity',
                                              fshumidityData,
                                              '(%)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(fsrainData))
                                          _buildChartContainer(
                                              'Rain Level',
                                              fsrainData,
                                              '(mm)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(fsradiationData))
                                          _buildChartContainer(
                                              'Radiation',
                                              fsradiationData,
                                              '(W/m²)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(fswindspeedData))
                                          _buildChartContainer(
                                              'Wind Speed',
                                              fswindspeedData,
                                              '(m/s)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(
                                            fswinddirectionData))
                                          _buildChartContainer(
                                              'Wind Direction',
                                              fswinddirectionData,
                                              '(°)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(temp2Data))
                                          _buildChartContainer(
                                              'Temperature',
                                              temp2Data,
                                              '(°C)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(cod2Data))
                                          _buildChartContainer(
                                              'COD',
                                              cod2Data,
                                              '(mg/L)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(bod2Data))
                                          _buildChartContainer(
                                              'BOD',
                                              bod2Data,
                                              '(mg/L)',
                                              ChartType.line,
                                              isDarkMode),
                                        if (hasNonZeroValues(
                                            wfAverageTemperatureData))
                                          _buildChartContainer(
                                              'Temperature',
                                              wfAverageTemperatureData,
                                              '(°C)',
                                              ChartType.line,
                                              isDarkMode),
                                        _buildChartContainer(
                                            'Rain Level',
                                            wfrainfallData,
                                            '(mm)',
                                            ChartType.line,
                                            isDarkMode),
                                      ]
                                          .where((widget) =>
                                              widget != const SizedBox.shrink())
                                          .toList(),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

          // Layout for mobile and smaller screens
          if (isMobile)
            Column(
              children: [
                // AppBar for mobile
                AppBar(
                  backgroundColor:
                      isDarkMode ? Colors.blueGrey[900] : Colors.grey[200],
                  elevation: 0,
                  title: Text.rich(
                    TextSpan(
                      text: "${widget.sequentialName}\n", // Sequential name
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        TextSpan(
                          text:
                              "(${widget.deviceName})", // Device name + extra space
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  leading: Builder(
                    builder: (context) => IconButton(
                      icon: Icon(
                        Icons.menu,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  actions: [
                    if (widget.deviceName.startsWith('WD'))
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getBatteryIcon(
                                _parseBatteryPercentage(_lastBatteryPercentage),
                              ),
                              size: 26,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                            SizedBox(width: 4),
                            Text(
                              ': $_lastBatteryPercentage',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (widget.deviceName.startsWith('FS'))
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getpercentBatteryIcon(_lastfsBattery),
                                  color:
                                      _getpercentBatteryColor(_lastfsBattery),
                                  size: 28,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '${_convertVoltageToPercentage(_lastfsBattery).toStringAsFixed(2)} %',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    if (widget.deviceName.startsWith('SM'))
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getpercentBatteryIcon(_lastsmBattery),
                                  color:
                                      _getpercentBatteryColor(_lastsmBattery),
                                  size: 28,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '${_convertVoltageToPercentage(_lastsmBattery).toStringAsFixed(2)} %',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    if (widget.deviceName.startsWith('CF'))
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getpercentBatteryIcon(_lastcfBattery),
                                  color:
                                      _getpercentBatteryColor(_lastcfBattery),
                                  size: 28,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '${_convertVoltageToPercentage(_lastcfBattery).toStringAsFixed(2)} %',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    if (widget.deviceName.startsWith('VD'))
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getpercentBatteryIcon(_lastvdBattery),
                                  color:
                                      _getpercentBatteryColor(_lastvdBattery),
                                  size: 28,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '${_convertVoltageToPercentage(_lastvdBattery).toStringAsFixed(2)} %',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    if (widget.deviceName.startsWith('KD'))
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getpercentBatteryIcon(_lastkdBattery),
                                  color:
                                      _getpercentBatteryColor(_lastkdBattery),
                                  size: 28,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '${_convertVoltageToPercentage(_lastkdBattery).toStringAsFixed(2)} %',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    if (widget.deviceName.startsWith('NA'))
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getpercentBatteryIcon(_lastNARLBattery),
                                  color:
                                      _getpercentBatteryColor(_lastNARLBattery),
                                  size: 28,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '${_convertVoltageToPercentage(_lastNARLBattery).toStringAsFixed(2)} %',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    if (widget.deviceName.startsWith('KJ'))
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getpercentBatteryIcon(_lastKJBattery),
                                  color:
                                      _getpercentBatteryColor(_lastKJBattery),
                                  size: 28,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '${_convertVoltageToPercentage(_lastKJBattery).toStringAsFixed(2)} %',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    if (widget.deviceName.startsWith('MY'))
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getpercentBatteryIcon(_lastMYBattery),
                                  color:
                                      _getpercentBatteryColor(_lastMYBattery),
                                  size: 28,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '${_convertVoltageToPercentage(_lastMYBattery).toStringAsFixed(2)} %',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    if (widget.deviceName.startsWith('CP'))
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getpercentBatteryIcon(_lastcsBattery),
                                  color:
                                      _getpercentBatteryColor(_lastcsBattery),
                                  size: 28,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '${_convertVoltageToPercentage(_lastcsBattery).toStringAsFixed(2)} %',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    if (widget.deviceName.startsWith('SV'))
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getpercentBatteryIcon(_lastsvBattery),
                                  color:
                                      _getpercentBatteryColor(_lastsvBattery),
                                  size: 28,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '${_convertVoltageToPercentage(_lastsvBattery).toStringAsFixed(2)} %',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: RotationTransition(
                        turns: Tween(begin: 0.0, end: 1.0)
                            .animate(_rotationController),
                        child: IconButton(
                          icon: Icon(
                            Icons.refresh,
                            color: isDarkMode ? Colors.white : Colors.black,
                            size: 26,
                          ),
                          onPressed: _isLoading
                              ? null
                              : () {
                                  _reloadData(range: _lastSelectedRange);
                                },
                        ),
                      ),
                    ),
                  ],
                ),
                // Colored line for differentiation
                Container(
                  height: 2.0,
                  color: isDarkMode
                      ? Colors.white
                      : Colors.black, // Adjust color as needed
                ),
                // Content area below AppBar
                Expanded(
                  child: Row(
                    children: [
                      // Left Sidebar - Only show on large screens
                      if (!isMobile)
                        Container(
                          width: sidebarWidth,
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.blueGrey[900]
                                : Colors.grey[200],
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(2, 0),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 64,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.blueGrey[900]
                                      : Colors.grey[200],
                                  border: Border(
                                    bottom: BorderSide(
                                      color: isDarkMode
                                          ? Colors.blueGrey[900]!
                                          : Colors.grey[200]!,
                                      width: 0,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                      size: 24,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Select Time Period',
                                      style: TextStyle(
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                        fontSize:
                                            MediaQuery.of(context).size.width <
                                                    800
                                                ? 14
                                                : 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      _buildSidebarButton(
                                        '1 Day : ${DateFormat('dd-MM-yyyy').format(_selectedDay)}',
                                        'date',
                                        Icons.today,
                                        isDarkMode,
                                        onPressed: () {
                                          _selectDate();
                                          setState(() {
                                            _activeButton = 'date';
                                          });
                                        },
                                      ),
                                      SizedBox(height: 8),
                                      _buildSidebarButton(
                                        'Last 7 Days',
                                        '7days',
                                        Icons.calendar_view_week,
                                        isDarkMode,
                                        onPressed: () {
                                          _fetchDataForRange('7days');
                                          setState(() {
                                            _activeButton = '7days';
                                          });
                                        },
                                      ),
                                      SizedBox(height: 8),
                                      _buildSidebarButton(
                                        'Last 30 Days',
                                        '30days',
                                        Icons.calendar_view_month,
                                        isDarkMode,
                                        onPressed: () {
                                          _fetchDataForRange('30days');
                                          setState(() {
                                            _activeButton = '30days';
                                          });
                                        },
                                      ),
                                      SizedBox(height: 8),
                                      _buildSidebarButton(
                                        'Last 3 Months',
                                        '3months',
                                        Icons.calendar_today,
                                        isDarkMode,
                                        onPressed: () {
                                          _fetchDataForRange('3months');
                                          setState(() {
                                            _activeButton = '3months';
                                          });
                                        },
                                      ),
                                      SizedBox(height: 8),
                                      _buildSidebarButton(
                                        'Last 1 Year',
                                        '1year',
                                        Icons.date_range,
                                        isDarkMode,
                                        onPressed: () {
                                          _fetchDataForRange('1year');
                                          setState(() {
                                            _activeButton = '1year';
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Main content area
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              color: isDarkMode
                                  ? Colors.blueGrey[900]
                                  : Colors.grey[200],
                              child: MediaQuery.of(context).size.width < 1200
                                  ? SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child:
                                          _buildHorizontalStatsRow(isDarkMode),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Expanded(
                                          child: _buildHorizontalStatsRow(
                                              isDarkMode),
                                        ),
                                      ],
                                    ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                controller:
                                    _scrollController, // Use ScrollController for scrolling
                                child: Container(
                                  padding: EdgeInsets.only(top: 10),
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(0.0),
                                        child: LayoutBuilder(
                                          builder: (context, constraints) {
                                            return Column(
                                                // children: [
                                                // SizedBox(height: 0),
                                                // if (widget.deviceName
                                                //         .startsWith('WD') &&
                                                //     isWindDirectionValid(
                                                //         _lastWindDirection) &&
                                                //     _lastWindDirection !=
                                                //         null &&
                                                //     _lastWindDirection
                                                //         .isNotEmpty)
                                                // Column(
                                                //   children: [
                                                //     Icon(
                                                //       Icons.wind_power,
                                                //       size: 40,
                                                //       color: Colors.white,
                                                //     ),
                                                //     SizedBox(height: 0),
                                                //     Text(
                                                //       'Wind Direction : $_lastWindDirection',
                                                //       style: TextStyle(
                                                //         fontWeight:
                                                //             FontWeight.bold,
                                                //         fontSize: 20,
                                                //         color: Colors.white,
                                                //       ),
                                                //     ),
                                                //   ],
                                                // ),
                                                // if (widget.deviceName
                                                //     .startsWith('WF'))
                                                //   Column(
                                                //     children: [
                                                //       SizedBox(height: 0),
                                                //       InkWell(
                                                //         onTap: () {
                                                //           Navigator.push(
                                                //             context,
                                                //             MaterialPageRoute(
                                                //               builder: (context) =>
                                                //                   WeatherForecastPage(
                                                //                 deviceName: widget
                                                //                     .deviceName,
                                                //                 sequentialName:
                                                //                     widget
                                                //                         .sequentialName,
                                                //               ),
                                                //             ),
                                                //           );
                                                //         },
                                                //         child: Column(
                                                //           children: [
                                                //             Icon(
                                                //               Icons.cloud,
                                                //               size: 40,
                                                //               color:
                                                //                   Colors.white,
                                                //             ),
                                                //             SizedBox(height: 8),
                                                //             Text(
                                                //               'Weather Forecast',
                                                //               style: TextStyle(
                                                //                 fontWeight:
                                                //                     FontWeight
                                                //                         .bold,
                                                //                 fontSize: 20,
                                                //                 color: Colors
                                                //                     .white,
                                                //               ),
                                                //             ),
                                                //           ],
                                                //         ),
                                                //       ),
                                                //     ],
                                                //   ),
                                                // SizedBox(height: 0),
                                                // if (widget.deviceName
                                                //     .startsWith('TE'))
                                                //   Text(
                                                //     'RSSI Value : $_lastRSSI_Value',
                                                //     style: TextStyle(
                                                //       fontWeight:
                                                //           FontWeight.bold,
                                                //       fontSize: 20,
                                                //       color: Colors.white,
                                                //     ),
                                                //   ),
                                                // ],
                                                );
                                          },
                                        ),
                                      ),
                                      // Padding(
                                      //   padding: const EdgeInsets.all(0.0),
                                      //   child: Column(
                                      //     children: [
                                      //       if (widget.deviceName
                                      //           .startsWith('CL'))
                                      //         _buildCurrentValue(
                                      //             'Chlorine Level',
                                      //             _currentChlorineValue,
                                      //             'mg/L'),
                                      //       if (widget.deviceName
                                      //           .startsWith('20'))
                                      //         _buildCurrentValue('Rain Level ',
                                      //             _currentrfdValue, 'mm'),
                                      //       () {
                                      //         if (widget.deviceName
                                      //                 .startsWith('IT') &&
                                      //             iswinddirectionValid(
                                      //                 _lastwinddirection) &&
                                      //             _lastwinddirection != null &&
                                      //             _lastwinddirection
                                      //                 .isNotEmpty) {
                                      //           return _buildWindCompass(
                                      //               _lastwinddirection);
                                      //         } else {
                                      //           return SizedBox.shrink();
                                      //         }
                                      //       }(),
                                      //     ],
                                      //   ),
                                      // ),
                                      if (widget.deviceName.startsWith('WQ'))
                                        buildStatisticsTable(),
                                      if (widget.deviceName.startsWith('CB'))
                                        buildCBStatisticsTable(),
                                      if (widget.deviceName.startsWith('NH'))
                                        buildNHStatisticsTable(),
                                      if (widget.deviceName.startsWith('DO'))
                                        buildDOStatisticsTable(),
                                      if (widget.deviceName.startsWith('IT'))
                                        buildITStatisticsTable(),

                                      if (widget.deviceName
                                              .startsWith('WD211') ||
                                          (widget.deviceName
                                              .startsWith('WD511')))
                                        SingleChildScrollView(
                                          child: Center(
                                            child: LayoutBuilder(
                                              builder: (context, constraints) {
                                                double screenWidth =
                                                    constraints.maxWidth;
                                                bool isLargeScreen =
                                                    screenWidth > 800;
                                                return isLargeScreen
                                                    ? Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          buildWeatherStatisticsTable(),
                                                          SizedBox(width: 5),
                                                          buildRainDataTable(),
                                                        ],
                                                      )
                                                    : Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          buildWeatherStatisticsTable(),
                                                          SizedBox(height: 5),
                                                          buildRainDataTable(),
                                                        ],
                                                      );
                                              },
                                            ),
                                          ),
                                        ),
                                      Column(
                                        children: [
                                          if (widget.deviceName
                                              .startsWith('SM'))
                                            ...[
                                              if (hasNonZeroValues(
                                                  smParametersData[
                                                          'CurrentTemperature'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Temperature',
                                                    smParametersData[
                                                            'CurrentTemperature'] ??
                                                        [],
                                                    '(°C)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  smParametersData[
                                                          'AtmPressure'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Pressure',
                                                    smParametersData[
                                                            'AtmPressure'] ??
                                                        [],
                                                    '(hPa)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  smParametersData[
                                                          'CurrentHumidity'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Humidity',
                                                    smParametersData[
                                                            'CurrentHumidity'] ??
                                                        [],
                                                    '(%)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  smParametersData[
                                                          'LightIntensity'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Light Intensity',
                                                    smParametersData[
                                                            'LightIntensity'] ??
                                                        [],
                                                    '(Lux)',
                                                    ChartType.line,
                                                    isDarkMode),
                                            ]
                                                .where((widget) =>
                                                    widget !=
                                                    const SizedBox.shrink())
                                                .toList(),
                                          if (widget.deviceName
                                              .startsWith('SM'))
                                            _buildWindChartContainer(
                                              'Wind',
                                              smParametersData['WindSpeed'] ??
                                                  [],
                                              smParametersData[
                                                      'WindDirection'] ??
                                                  [],
                                              isDarkMode,
                                            ),
                                          if (widget.deviceName
                                              .startsWith('SM'))
                                            ...smParametersData.entries
                                                .where((entry) {
                                                  String paramName = entry.key;
                                                  List<ChartData> data =
                                                      entry.value;
                                                  List<String> excludedParams =
                                                      [
                                                    'Longitude',
                                                    'Latitude',
                                                    'SignalStrength',
                                                    // 'BatteryVoltage',
                                                    'WindSpeed',
                                                    'WindDirection',
                                                    'TemperatureHourlyComulative',
                                                    'LuxHourlyComulative',
                                                    'PressureHourlyComulative',
                                                    'HumidityHourlyComulative'
                                                  ];
                                                  return !excludedParams
                                                          .contains(
                                                              paramName) &&
                                                      data.isNotEmpty;
                                                })
                                                .map((entry) {
                                                  String paramName = entry.key;
                                                  List<ChartData> data =
                                                      entry.value;
                                                  final displayInfo =
                                                      _getParameterDisplayInfo(
                                                          paramName);
                                                  String displayName =
                                                      displayInfo[
                                                          'displayName'];
                                                  String unit =
                                                      displayInfo['unit'];
                                                  String chartTitle;
                                                  if (paramName.toLowerCase() ==
                                                      'currenthumidity') {
                                                    chartTitle = '($unit)';
                                                  } else if (paramName
                                                          .toLowerCase() ==
                                                      'currenttemperature') {
                                                    chartTitle = '($unit)';
                                                  } else {
                                                    chartTitle = unit.isNotEmpty
                                                        ? '($unit)'
                                                        : displayName;
                                                  }
                                                  if ([
                                                    'CurrentTemperature',
                                                    'AtmPressure',
                                                    'CurrentHumidity',
                                                    'LightIntensity'
                                                  ].contains(paramName)) {
                                                    return const SizedBox
                                                        .shrink(); // Skip these as they are handled above
                                                  }
                                                  return _buildChartContainer(
                                                      displayName,
                                                      data,
                                                      chartTitle,
                                                      ChartType.line,
                                                      isDarkMode);
                                                })
                                                .where((widget) =>
                                                    widget !=
                                                    const SizedBox.shrink())
                                                .toList(),
                                          if (widget.deviceName
                                              .startsWith('CF'))
                                            ...[
                                              if (hasNonZeroValues(
                                                  cfParametersData[
                                                          'CurrentTemperature'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Temperature',
                                                    cfParametersData[
                                                            'CurrentTemperature'] ??
                                                        [],
                                                    '(°C)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  cfParametersData[
                                                          'AtmPressure'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Pressure',
                                                    cfParametersData[
                                                            'AtmPressure'] ??
                                                        [],
                                                    '(hPa)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  cfParametersData[
                                                          'CurrentHumidity'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Humidity',
                                                    cfParametersData[
                                                            'CurrentHumidity'] ??
                                                        [],
                                                    '(%)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  cfParametersData[
                                                          'LightIntensity'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Light Intensity',
                                                    cfParametersData[
                                                            'LightIntensity'] ??
                                                        [],
                                                    '(Lux)',
                                                    ChartType.line,
                                                    isDarkMode),
                                            ]
                                                .where((widget) =>
                                                    widget !=
                                                    const SizedBox.shrink())
                                                .toList(),
                                          if (widget.deviceName
                                              .startsWith('CF'))
                                            _buildWindChartContainer(
                                              'Wind',
                                              cfParametersData['WindSpeed'] ??
                                                  [],
                                              cfParametersData[
                                                      'WindDirection'] ??
                                                  [],
                                              isDarkMode,
                                            ),
                                          if (widget.deviceName
                                              .startsWith('CF'))
                                            ...cfParametersData.entries
                                                .where((entry) {
                                                  String paramName = entry.key;
                                                  List<ChartData> data =
                                                      entry.value;
                                                  List<String> excludedParams =
                                                      [
                                                    'Longitude',
                                                    'Latitude',
                                                    'SignalStrength',
                                                    // 'BatteryVoltage',
                                                    'WindSpeed',
                                                    'WindDirection',
                                                    'MaximumTemperature',
                                                    'MinimumTemperature',
                                                    'AverageTemperature',
                                                    'RainfallDaily',
                                                    'RainfallWeekly',
                                                    'RainfallMinutly',
                                                    'AverageHumidity',
                                                    'MinimumHumidity',
                                                    'MaximumHumidity',
                                                    'HumidityHourlyComulative',
                                                    'PressureHourlyComulative',
                                                    'LuxHourlyComulative',
                                                    'TemperatureHourlyComulative',
                                                  ];
                                                  return !excludedParams
                                                          .contains(
                                                              paramName) &&
                                                      data.isNotEmpty;
                                                })
                                                .map((entry) {
                                                  String paramName = entry.key;
                                                  List<ChartData> data =
                                                      entry.value;
                                                  final displayInfo =
                                                      _getParameterDisplayInfo(
                                                          paramName);
                                                  String displayName =
                                                      displayInfo[
                                                          'displayName'];
                                                  String unit =
                                                      displayInfo['unit'];
                                                  String chartTitle;
                                                  if (paramName.toLowerCase() ==
                                                      'currenthumidity') {
                                                    chartTitle = '($unit)';
                                                  } else if (paramName
                                                          .toLowerCase() ==
                                                      'currenttemperature') {
                                                    chartTitle = '($unit)';
                                                  } else {
                                                    chartTitle = unit.isNotEmpty
                                                        ? '($unit)'
                                                        : displayName;
                                                  }
                                                  if ([
                                                    'CurrentTemperature',
                                                    'AtmPressure',
                                                    'CurrentHumidity',
                                                    'LightIntensity'
                                                  ].contains(paramName)) {
                                                    return const SizedBox
                                                        .shrink(); // Skip these as they are handled above
                                                  }
                                                  return _buildChartContainer(
                                                      displayName,
                                                      data,
                                                      chartTitle,
                                                      ChartType.line,
                                                      isDarkMode);
                                                })
                                                .where((widget) =>
                                                    widget !=
                                                    const SizedBox.shrink())
                                                .toList(),
                                          if (widget.deviceName
                                              .startsWith('VD'))
                                            ...[
                                              if (hasNonZeroValues(
                                                  vdParametersData[
                                                          'CurrentTemperature'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Temperature',
                                                    vdParametersData[
                                                            'CurrentTemperature'] ??
                                                        [],
                                                    '(°C)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  vdParametersData[
                                                          'AtmPressure'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Pressure',
                                                    vdParametersData[
                                                            'AtmPressure'] ??
                                                        [],
                                                    '(hPa)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  vdParametersData[
                                                          'CurrentHumidity'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Humidity',
                                                    vdParametersData[
                                                            'CurrentHumidity'] ??
                                                        [],
                                                    '(%)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  vdParametersData[
                                                          'LightIntensity'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Light Intensity',
                                                    vdParametersData[
                                                            'LightIntensity'] ??
                                                        [],
                                                    '(Lux)',
                                                    ChartType.line,
                                                    isDarkMode),
                                            ]
                                                .where((widget) =>
                                                    widget !=
                                                    const SizedBox.shrink())
                                                .toList(),
                                          if (widget.deviceName
                                              .startsWith('VD'))
                                            _buildWindChartContainer(
                                              'Wind',
                                              vdParametersData['WindSpeed'] ??
                                                  [],
                                              vdParametersData[
                                                      'WindDirection'] ??
                                                  [],
                                              isDarkMode,
                                            ),
                                          if (widget.deviceName
                                              .startsWith('VD'))
                                            ...vdParametersData.entries
                                                .where((entry) {
                                                  String paramName = entry.key;
                                                  List<ChartData> data =
                                                      entry.value;
                                                  List<String> excludedParams =
                                                      [
                                                    'Longitude',
                                                    'Latitude',
                                                    'SignalStrength',
                                                    // 'BatteryVoltage',
                                                    'WindSpeed',
                                                    'WindDirection',
                                                    'MaximumTemperature',
                                                    'MinimumTemperature',
                                                    'AverageTemperature',
                                                    'RainfallDaily',
                                                    'RainfallWeekly',
                                                    'AverageHumidity',
                                                    'MinimumHumidity',
                                                    'MaximumHumidity',
                                                  ];
                                                  return !excludedParams
                                                          .contains(
                                                              paramName) &&
                                                      data.isNotEmpty;
                                                })
                                                .map((entry) {
                                                  String paramName = entry.key;
                                                  List<ChartData> data =
                                                      entry.value;
                                                  final displayInfo =
                                                      _getParameterDisplayInfo(
                                                          paramName);
                                                  String displayName =
                                                      displayInfo[
                                                          'displayName'];
                                                  String unit =
                                                      displayInfo['unit'];
                                                  String chartTitle;
                                                  if (paramName.toLowerCase() ==
                                                      'currenthumidity') {
                                                    chartTitle = '($unit)';
                                                  } else if (paramName
                                                          .toLowerCase() ==
                                                      'currenttemperature') {
                                                    chartTitle = '($unit)';
                                                  } else {
                                                    chartTitle = unit.isNotEmpty
                                                        ? '$displayName ($unit)'
                                                        : displayName;
                                                  }
                                                  if ([
                                                    'CurrentTemperature',
                                                    'AtmPressure',
                                                    'CurrentHumidity',
                                                    'LightIntensity'
                                                  ].contains(paramName)) {
                                                    return const SizedBox
                                                        .shrink(); // Skip these as they are handled above
                                                  }
                                                  return _buildChartContainer(
                                                      displayName,
                                                      data,
                                                      chartTitle,
                                                      ChartType.line,
                                                      isDarkMode);
                                                })
                                                .where((widget) =>
                                                    widget !=
                                                    const SizedBox.shrink())
                                                .toList(),
                                          if (widget.deviceName
                                              .startsWith('KD'))
                                            ...[
                                              if (hasNonZeroValues(
                                                  kdParametersData[
                                                          'CurrentTemperature'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Temperature',
                                                    kdParametersData[
                                                            'CurrentTemperature'] ??
                                                        [],
                                                    '(°C)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  kdParametersData[
                                                          'AtmPressure'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Pressure',
                                                    kdParametersData[
                                                            'AtmPressure'] ??
                                                        [],
                                                    '(hPa)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  kdParametersData[
                                                          'CurrentHumidity'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Humidity',
                                                    kdParametersData[
                                                            'CurrentHumidity'] ??
                                                        [],
                                                    '(%)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  kdParametersData[
                                                          'LightIntensity'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Light Intensity',
                                                    kdParametersData[
                                                            'LightIntensity'] ??
                                                        [],
                                                    '(Lux)',
                                                    ChartType.line,
                                                    isDarkMode),
                                            ]
                                                .where((widget) =>
                                                    widget !=
                                                    const SizedBox.shrink())
                                                .toList(),
                                          if (widget.deviceName
                                              .startsWith('KD'))
                                            _buildWindChartContainer(
                                              'Wind',
                                              kdParametersData['WindSpeed'] ??
                                                  [],
                                              kdParametersData[
                                                      'WindDirection'] ??
                                                  [],
                                              isDarkMode,
                                            ),
                                          if (widget.deviceName
                                              .startsWith('KD'))
                                            ...kdParametersData.entries
                                                .where((entry) {
                                                  String paramName = entry.key;
                                                  List<ChartData> data =
                                                      entry.value;
                                                  List<String> excludedParams =
                                                      [
                                                    'Longitude',
                                                    'Latitude',
                                                    'SignalStrength',
                                                    // 'BatteryVoltage',
                                                    'WindSpeed',
                                                    'WindDirection',
                                                    'MaximumTemperature',
                                                    'MinimumTemperature',
                                                    'AverageTemperature',
                                                    'RainfallDaily',
                                                    'RainfallWeekly',
                                                    'AverageHumidity',
                                                    'MinimumHumidity',
                                                    'MaximumHumidity',
                                                  ];
                                                  return !excludedParams
                                                          .contains(
                                                              paramName) &&
                                                      data.isNotEmpty;
                                                })
                                                .map((entry) {
                                                  String paramName = entry.key;
                                                  List<ChartData> data =
                                                      entry.value;
                                                  final displayInfo =
                                                      _getParameterDisplayInfo(
                                                          paramName);
                                                  String displayName =
                                                      displayInfo[
                                                          'displayName'];
                                                  String unit =
                                                      displayInfo['unit'];
                                                  String chartTitle;
                                                  if (paramName.toLowerCase() ==
                                                      'currenthumidity') {
                                                    chartTitle = '($unit)';
                                                  } else if (paramName
                                                          .toLowerCase() ==
                                                      'currenttemperature') {
                                                    chartTitle = '($unit)';
                                                  } else {
                                                    chartTitle = unit.isNotEmpty
                                                        ? '$displayName ($unit)'
                                                        : displayName;
                                                  }
                                                  if ([
                                                    'CurrentTemperature',
                                                    'AtmPressure',
                                                    'CurrentHumidity',
                                                    'LightIntensity'
                                                  ].contains(paramName)) {
                                                    return const SizedBox
                                                        .shrink(); // Skip these as they are handled above
                                                  }
                                                  return _buildChartContainer(
                                                      displayName,
                                                      data,
                                                      chartTitle,
                                                      ChartType.line,
                                                      isDarkMode);
                                                })
                                                .where((widget) =>
                                                    widget !=
                                                    const SizedBox.shrink())
                                                .toList(),
                                          if (widget.deviceName
                                              .startsWith('NA'))
                                            ...[
                                              if (hasNonZeroValues(
                                                  NARLParametersData[
                                                          'CurrentTemperature'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Temperature',
                                                    NARLParametersData[
                                                            'CurrentTemperature'] ??
                                                        [],
                                                    '(°C)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  NARLParametersData[
                                                          'AtmPressure'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Pressure',
                                                    NARLParametersData[
                                                            'AtmPressure'] ??
                                                        [],
                                                    '(hPa)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  NARLParametersData[
                                                          'CurrentHumidity'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Humidity',
                                                    NARLParametersData[
                                                            'CurrentHumidity'] ??
                                                        [],
                                                    '(%)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  NARLParametersData[
                                                          'LightIntensity'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Light Intensity',
                                                    NARLParametersData[
                                                            'LightIntensity'] ??
                                                        [],
                                                    '(Lux)',
                                                    ChartType.line,
                                                    isDarkMode),
                                            ]
                                                .where((widget) =>
                                                    widget !=
                                                    const SizedBox.shrink())
                                                .toList(),
                                          if (widget.deviceName
                                              .startsWith('NA'))
                                            _buildWindChartContainer(
                                              'Wind',
                                              NARLParametersData['WindSpeed'] ??
                                                  [],
                                              NARLParametersData[
                                                      'WindDirection'] ??
                                                  [],
                                              isDarkMode,
                                            ),
                                          if (widget.deviceName
                                              .startsWith('NA'))
                                            ...NARLParametersData.entries
                                                .where((entry) {
                                                  String paramName = entry.key;
                                                  List<ChartData> data =
                                                      entry.value;
                                                  List<String> excludedParams =
                                                      [
                                                    'Longitude',
                                                    'Latitude',
                                                    'SignalStrength',
                                                    // 'BatteryVoltage',
                                                    'WindSpeed',
                                                    'WindDirection',
                                                    'MaximumTemperature',
                                                    'MinimumTemperature',
                                                    'AverageTemperature',
                                                    'RainfallDaily',
                                                    'RainfallWeekly',
                                                    'RainfallMinutly',
                                                    'AverageHumidity',
                                                    'MinimumHumidity',
                                                    'MaximumHumidity',
                                                    'HumidityHourlyComulative',
                                                    'PressureHourlyComulative',
                                                    'LuxHourlyComulative',
                                                    'TemperatureHourlyComulative',
                                                  ];
                                                  return !excludedParams
                                                          .contains(
                                                              paramName) &&
                                                      data.isNotEmpty;
                                                })
                                                .map((entry) {
                                                  String paramName = entry.key;
                                                  List<ChartData> data =
                                                      entry.value;
                                                  final displayInfo =
                                                      _getParameterDisplayInfo(
                                                          paramName);
                                                  String displayName =
                                                      displayInfo[
                                                          'displayName'];
                                                  String unit =
                                                      displayInfo['unit'];
                                                  String chartTitle;
                                                  if (paramName.toLowerCase() ==
                                                      'currenthumidity') {
                                                    chartTitle = '($unit)';
                                                  } else if (paramName
                                                          .toLowerCase() ==
                                                      'currenttemperature') {
                                                    chartTitle = '($unit)';
                                                  } else {
                                                    chartTitle = unit.isNotEmpty
                                                        ? '($unit)'
                                                        : displayName;
                                                  }
                                                  if ([
                                                    'CurrentTemperature',
                                                    'AtmPressure',
                                                    'CurrentHumidity',
                                                    'LightIntensity'
                                                  ].contains(paramName)) {
                                                    return const SizedBox
                                                        .shrink(); // Skip these as they are handled above
                                                  }
                                                  return _buildChartContainer(
                                                      displayName,
                                                      data,
                                                      chartTitle,
                                                      ChartType.line,
                                                      isDarkMode);
                                                })
                                                .where((widget) =>
                                                    widget !=
                                                    const SizedBox.shrink())
                                                .toList(),
                                          if (widget.deviceName
                                              .startsWith('KJ'))
                                            ...[
                                              if (hasNonZeroValues(
                                                  KJParametersData[
                                                          'CurrentTemperature'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Temperature',
                                                    KJParametersData[
                                                            'CurrentTemperature'] ??
                                                        [],
                                                    '(°C)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  KJParametersData[
                                                          'AtmPressure'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Pressure',
                                                    KJParametersData[
                                                            'AtmPressure'] ??
                                                        [],
                                                    '(hPa)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  KJParametersData[
                                                          'CurrentHumidity'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Humidity',
                                                    KJParametersData[
                                                            'CurrentHumidity'] ??
                                                        [],
                                                    '(%)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  KJParametersData[
                                                          'LightIntensity'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Light Intensity',
                                                    KJParametersData[
                                                            'LightIntensity'] ??
                                                        [],
                                                    '(Lux)',
                                                    ChartType.line,
                                                    isDarkMode),
                                            ]
                                                .where((widget) =>
                                                    widget !=
                                                    const SizedBox.shrink())
                                                .toList(),
                                          if (widget.deviceName
                                              .startsWith('KJ'))
                                            _buildWindChartContainer(
                                              'Wind',
                                              KJParametersData['WindSpeed'] ??
                                                  [],
                                              KJParametersData[
                                                      'WindDirection'] ??
                                                  [],
                                              isDarkMode,
                                            ),
                                          if (widget.deviceName
                                              .startsWith('KJ'))
                                            ...KJParametersData.entries
                                                .where((entry) {
                                                  String paramName = entry.key;
                                                  List<ChartData> data =
                                                      entry.value;
                                                  List<String> excludedParams =
                                                      [
                                                    'Longitude',
                                                    'Latitude',
                                                    'SignalStrength',
                                                    // 'BatteryVoltage',
                                                    'WindSpeed',
                                                    'WindDirection',
                                                    'MaximumTemperature',
                                                    'MinimumTemperature',
                                                    'AverageTemperature',
                                                    'RainfallDaily',
                                                    'RainfallWeekly',
                                                    'RainfallHourly',
                                                    'RainfallMinutly',
                                                    'AverageHumidity',
                                                    'MinimumHumidity',
                                                    'MaximumHumidity',
                                                    'HumidityHourlyComulative',
                                                    'PressureHourlyComulative',
                                                    'LuxHourlyComulative',
                                                    'TemperatureHourlyComulative',
                                                    'AtmPressure',
                                                    'Light Intensity',
                                                    'Wind Direction',
                                                    'Wind Speed',
                                                  ];
                                                  return !excludedParams
                                                          .contains(
                                                              paramName) &&
                                                      data.isNotEmpty;
                                                })
                                                .map((entry) {
                                                  String paramName = entry.key;
                                                  List<ChartData> data =
                                                      entry.value;
                                                  final displayInfo =
                                                      _getParameterDisplayInfo(
                                                          paramName);
                                                  String displayName =
                                                      displayInfo[
                                                          'displayName'];
                                                  String unit =
                                                      displayInfo['unit'];
                                                  String chartTitle;
                                                  if (paramName.toLowerCase() ==
                                                      'currenthumidity') {
                                                    chartTitle = '($unit)';
                                                  } else if (paramName
                                                          .toLowerCase() ==
                                                      'currenttemperature') {
                                                    chartTitle = '($unit)';
                                                  } else {
                                                    chartTitle = unit.isNotEmpty
                                                        ? '($unit)'
                                                        : displayName;
                                                  }
                                                  if ([
                                                    'CurrentTemperature',
                                                    'AtmPressure',
                                                    'CurrentHumidity',
                                                    'LightIntensity'
                                                  ].contains(paramName)) {
                                                    return const SizedBox
                                                        .shrink(); // Skip these as they are handled above
                                                  }
                                                  return _buildChartContainer(
                                                      displayName,
                                                      data,
                                                      chartTitle,
                                                      ChartType.line,
                                                      isDarkMode);
                                                })
                                                .where((widget) =>
                                                    widget !=
                                                    const SizedBox.shrink())
                                                .toList(),
                                          if (widget.deviceName
                                              .startsWith('MY'))
                                            ...[
                                              if (hasNonZeroValues(
                                                  MYParametersData[
                                                          'CurrentTemperature'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Temperature',
                                                    MYParametersData[
                                                            'CurrentTemperature'] ??
                                                        [],
                                                    '(°C)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  MYParametersData[
                                                          'AtmPressure'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Pressure',
                                                    MYParametersData[
                                                            'AtmPressure'] ??
                                                        [],
                                                    '(hPa)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  MYParametersData[
                                                          'CurrentHumidity'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Humidity',
                                                    MYParametersData[
                                                            'CurrentHumidity'] ??
                                                        [],
                                                    '(%)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  MYParametersData[
                                                          'LightIntensity'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Light Intensity',
                                                    MYParametersData[
                                                            'LightIntensity'] ??
                                                        [],
                                                    '(Lux)',
                                                    ChartType.line,
                                                    isDarkMode),
                                            ]
                                                .where((widget) =>
                                                    widget !=
                                                    const SizedBox.shrink())
                                                .toList(),
                                          if (widget.deviceName
                                              .startsWith('MY'))
                                            _buildWindChartContainer(
                                              'Wind',
                                              MYParametersData['WindSpeed'] ??
                                                  [],
                                              MYParametersData[
                                                      'WindDirection'] ??
                                                  [],
                                              isDarkMode,
                                            ),
                                          if (widget.deviceName
                                              .startsWith('MY'))
                                            ...MYParametersData.entries
                                                .where((entry) {
                                                  String paramName = entry.key;
                                                  List<ChartData> data =
                                                      entry.value;
                                                  List<String> excludedParams =
                                                      [
                                                    'Longitude',
                                                    'Latitude',
                                                    'SignalStrength',
                                                    'BatteryVoltage',
                                                    'MaximumTemperature',
                                                    'MinimumTemperature',
                                                    'AverageTemperature',
                                                    'RainfallDaily',
                                                    'RainfallWeekly',
                                                    'RainfallMinutly',
                                                    'AverageHumidity',
                                                    'MinimumHumidity',
                                                    'MaximumHumidity',
                                                    'HumidityHourlyComulative',
                                                    'PressureHourlyComulative',
                                                    'LuxHourlyComulative',
                                                    'TemperatureHourlyComulative',
                                                    'WindSpeed',
                                                    'WindDirection',
                                                  ];
                                                  return !excludedParams
                                                          .contains(
                                                              paramName) &&
                                                      data.isNotEmpty;
                                                })
                                                .map((entry) {
                                                  String paramName = entry.key;
                                                  List<ChartData> data =
                                                      entry.value;
                                                  final displayInfo =
                                                      _getParameterDisplayInfo(
                                                          paramName);
                                                  String displayName =
                                                      displayInfo[
                                                          'displayName'];
                                                  String unit =
                                                      displayInfo['unit'];
                                                  String chartTitle;
                                                  if (paramName.toLowerCase() ==
                                                      'currenthumidity') {
                                                    chartTitle = '($unit)';
                                                  } else if (paramName
                                                          .toLowerCase() ==
                                                      'currenttemperature') {
                                                    chartTitle = '($unit)';
                                                  } else {
                                                    chartTitle = unit.isNotEmpty
                                                        ? '($unit)'
                                                        : displayName;
                                                  }
                                                  if ([
                                                    'CurrentTemperature',
                                                    'AtmPressure',
                                                    'CurrentHumidity',
                                                    'LightIntensity'
                                                  ].contains(paramName)) {
                                                    return const SizedBox
                                                        .shrink(); // Skip these as they are handled above
                                                  }
                                                  return _buildChartContainer(
                                                      displayName,
                                                      data,
                                                      chartTitle,
                                                      ChartType.line,
                                                      isDarkMode);
                                                })
                                                .where((widget) =>
                                                    widget !=
                                                    const SizedBox.shrink())
                                                .toList(),
                                          if (widget.deviceName
                                              .startsWith('CP'))
                                            ...[
                                              if (hasNonZeroValues(
                                                  csParametersData[
                                                          'CurrentTemperature'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Temperature',
                                                    csParametersData[
                                                            'CurrentTemperature'] ??
                                                        [],
                                                    '(°C)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  csParametersData[
                                                          'AtmPressure'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Pressure',
                                                    csParametersData[
                                                            'AtmPressure'] ??
                                                        [],
                                                    '(hPa)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  csParametersData[
                                                          'CurrentHumidity'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Humidity',
                                                    csParametersData[
                                                            'CurrentHumidity'] ??
                                                        [],
                                                    '(%)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  csParametersData[
                                                          'LightIntensity'] ??
                                                      []))
                                                _buildChartContainer(
                                                    'Light Intensity',
                                                    csParametersData[
                                                            'LightIntensity'] ??
                                                        [],
                                                    '(Lux)',
                                                    ChartType.line,
                                                    isDarkMode),
                                            ]
                                                .where((widget) =>
                                                    widget !=
                                                    const SizedBox.shrink())
                                                .toList(),
                                          if (widget.deviceName
                                              .startsWith('CP'))
                                            _buildWindChartContainer(
                                              'Wind',
                                              csParametersData['WindSpeed'] ??
                                                  [],
                                              csParametersData[
                                                      'WindDirection'] ??
                                                  [],
                                              isDarkMode,
                                            ),
                                          if (widget.deviceName
                                              .startsWith('CP'))
                                            ...csParametersData.entries
                                                .where((entry) {
                                                  String paramName = entry.key;
                                                  List<ChartData> data =
                                                      entry.value;
                                                  List<String> excludedParams =
                                                      [
                                                    'Longitude',
                                                    'Latitude',
                                                    'SignalStrength',
                                                    // 'BatteryVoltage',
                                                    'WindSpeed',
                                                    'WindDirection',
                                                    'MaximumTemperature',
                                                    'MinimumTemperature',
                                                    'AverageTemperature',
                                                    'RainfallMinutly',
                                                    'RainfallDaily',
                                                    'RainfallWeekly',
                                                    'AverageHumidity',
                                                    'MinimumHumidity',
                                                    'MaximumHumidity',
                                                    'HumidityHourlyComulative',
                                                    'PressureHourlyComulative',
                                                    'LuxHourlyComulative',
                                                    'TemperatureHourlyComulative',
                                                  ];
                                                  return !excludedParams
                                                          .contains(
                                                              paramName) &&
                                                      data.isNotEmpty;
                                                })
                                                .map((entry) {
                                                  String paramName = entry.key;
                                                  List<ChartData> data =
                                                      entry.value;
                                                  final displayInfo =
                                                      _getParameterDisplayInfo(
                                                          paramName);
                                                  String displayName =
                                                      displayInfo[
                                                          'displayName'];
                                                  String unit =
                                                      displayInfo['unit'];
                                                  String chartTitle;
                                                  if (paramName.toLowerCase() ==
                                                      'currenthumidity') {
                                                    chartTitle = '($unit)';
                                                  } else if (paramName
                                                          .toLowerCase() ==
                                                      'currenttemperature') {
                                                    chartTitle = '($unit)';
                                                  } else {
                                                    chartTitle = unit.isNotEmpty
                                                        ? '($unit)'
                                                        : displayName;
                                                  }
                                                  if ([
                                                    'CurrentTemperature',
                                                    'AtmPressure',
                                                    'CurrentHumidity',
                                                    'LightIntensity'
                                                  ].contains(paramName)) {
                                                    return const SizedBox
                                                        .shrink(); // Skip these as they are handled above
                                                  }
                                                  return _buildChartContainer(
                                                      displayName,
                                                      data,
                                                      chartTitle,
                                                      ChartType.line,
                                                      isDarkMode);
                                                })
                                                .where((widget) =>
                                                    widget !=
                                                    const SizedBox.shrink())
                                                .toList(),
                                          if (widget.deviceName
                                              .startsWith('SV'))
                                            ...svParametersData.entries
                                                .where((entry) {
                                                  String paramName = entry.key;
                                                  List<ChartData> data =
                                                      entry.value;
                                                  List<String> excludedParams =
                                                      [
                                                    'Longitude',
                                                    'Latitude',
                                                    'SignalStrength',
                                                    // 'BatteryVoltage',
                                                    'MaximumTemperature',
                                                    'MinimumTemperature',
                                                    'AverageTemperature',
                                                    'RainfallDaily',
                                                    'RainfallWeekly',
                                                    'RainfallMinutly',
                                                    'AverageHumidity',
                                                    'MinimumHumidity',
                                                    'MaximumHumidity',
                                                    'HumidityHourlyComulative',
                                                    'PressureHourlyComulative',
                                                    'LuxHourlyComulative',
                                                    'TemperatureHourlyComulative',
                                                  ];
                                                  return !excludedParams
                                                          .contains(
                                                              paramName) &&
                                                      data.isNotEmpty;
                                                })
                                                .map((entry) {
                                                  String paramName = entry.key;
                                                  List<ChartData> data =
                                                      entry.value;
                                                  final displayInfo =
                                                      _getParameterDisplayInfo(
                                                          paramName);
                                                  String displayName =
                                                      displayInfo[
                                                          'displayName'];
                                                  String unit =
                                                      displayInfo['unit'];
                                                  String chartTitle;
                                                  if (paramName.toLowerCase() ==
                                                      'currenthumidity') {
                                                    chartTitle = '($unit)';
                                                  } else if (paramName
                                                          .toLowerCase() ==
                                                      'currenttemperature') {
                                                    chartTitle = '($unit)';
                                                  } else {
                                                    chartTitle = unit.isNotEmpty
                                                        ? '($unit)'
                                                        : displayName;
                                                  }
                                                  return _buildChartContainer(
                                                      displayName,
                                                      data,
                                                      chartTitle,
                                                      ChartType.line,
                                                      isDarkMode);
                                                })
                                                .where((widget) =>
                                                    widget !=
                                                    const SizedBox.shrink())
                                                .toList(),
                                          if (!widget.deviceName
                                                  .startsWith('SM') &&
                                              !widget.deviceName
                                                  .startsWith('CF') &&
                                              !widget.deviceName
                                                  .startsWith('VD') &&
                                              !widget.deviceName
                                                  .startsWith('KD') &&
                                              !widget.deviceName
                                                  .startsWith('NA') &&
                                              !widget.deviceName
                                                  .startsWith('KJ') &&
                                              !widget.deviceName
                                                  .startsWith('MY') &&
                                              !widget.deviceName
                                                  .startsWith('CP') &&
                                              !widget.deviceName
                                                  .startsWith('SV'))
                                            ...[
                                              if (hasNonZeroValues(
                                                  chlorineData))
                                                _buildChartContainer(
                                                    'Chlorine',
                                                    chlorineData,
                                                    '(mg/L)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  temperatureData))
                                                _buildChartContainer(
                                                    'Temperature',
                                                    temperatureData,
                                                    '(°C)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  humidityData))
                                                _buildChartContainer(
                                                    'Humidity',
                                                    humidityData,
                                                    '(%)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  lightIntensityData))
                                                _buildChartContainer(
                                                    'Light Intensity',
                                                    lightIntensityData,
                                                    '(Lux)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  windSpeedData))
                                                _buildChartContainer(
                                                    'Wind Speed',
                                                    windSpeedData,
                                                    '(m/s)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  solarIrradianceData))
                                                _buildChartContainer(
                                                    'Solar Irradiance',
                                                    solarIrradianceData,
                                                    '(W/M^2)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(tempData))
                                                _buildChartContainer(
                                                    'Temperature',
                                                    tempData,
                                                    '(°C)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(tdsData))
                                                _buildChartContainer(
                                                    'TDS',
                                                    tdsData,
                                                    '(ppm)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(codData))
                                                _buildChartContainer(
                                                    'COD',
                                                    codData,
                                                    '(mg/L)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(bodData))
                                                _buildChartContainer(
                                                    'BOD',
                                                    bodData,
                                                    '(mg/L)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(pHData))
                                                _buildChartContainer(
                                                    'pH',
                                                    pHData,
                                                    'pH',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(doData))
                                                _buildChartContainer(
                                                    'DO',
                                                    doData,
                                                    '(mg/L)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(ecData))
                                                _buildChartContainer(
                                                    'EC',
                                                    ecData,
                                                    '(mS/cm)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(temppData))
                                                _buildChartContainer(
                                                    'Temperature',
                                                    temppData,
                                                    '(°C)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  electrodeSignalData))
                                                _buildChartContainer(
                                                    'Electrode Signal',
                                                    electrodeSignalData,
                                                    '(mV)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  residualchlorineData))
                                                _buildChartContainer(
                                                    'Chlorine',
                                                    residualchlorineData,
                                                    '(mg/L)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  hypochlorousData))
                                                _buildChartContainer(
                                                    'Hypochlorous',
                                                    hypochlorousData,
                                                    '(mg/L)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(temmppData))
                                                _buildChartContainer(
                                                    'Temperature',
                                                    temmppData,
                                                    '(°C)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  humidityyData))
                                                _buildChartContainer(
                                                    'Humidity',
                                                    humidityyData,
                                                    '(%)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  lightIntensityyData))
                                                _buildChartContainer(
                                                    'Light Intensity',
                                                    lightIntensityyData,
                                                    '(Lux)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  windSpeeddData))
                                                _buildChartContainer(
                                                    'Wind Speed',
                                                    windSpeeddData,
                                                    '(m/s)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(ttempData))
                                                _buildChartContainer(
                                                    'Temperature',
                                                    ttempData,
                                                    '(°C)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(dovaluedata))
                                                _buildChartContainer(
                                                    'DO Value',
                                                    dovaluedata,
                                                    '(mg/L)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  dopercentagedata))
                                                _buildChartContainer(
                                                    'DO Percentage',
                                                    dopercentagedata,
                                                    '(%)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  temperaturData))
                                                _buildChartContainer(
                                                    'Temperature',
                                                    temperaturData,
                                                    '(°C)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(humData))
                                                _buildChartContainer(
                                                    'Humidity',
                                                    humData,
                                                    '(%)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(luxData))
                                                _buildChartContainer(
                                                    'Light Intensity',
                                                    luxData,
                                                    '(Lux)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(coddata))
                                                _buildChartContainer(
                                                    'COD',
                                                    coddata,
                                                    '(mg/L)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(boddata))
                                                _buildChartContainer(
                                                    'BOD',
                                                    boddata,
                                                    '(mg/L)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(phdata))
                                                _buildChartContainer(
                                                    'pH',
                                                    phdata,
                                                    'pH',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  temperattureData))
                                                _buildChartContainer(
                                                    'Temperature',
                                                    temperattureData,
                                                    '(°C)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  humidittyData))
                                                _buildChartContainer(
                                                    'Humidity',
                                                    humidittyData,
                                                    '(%)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(ammoniaData))
                                                _buildChartContainer(
                                                    'Ammonia',
                                                    ammoniaData,
                                                    '(PPM)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  temperaturedata))
                                                _buildChartContainer(
                                                    'Temperature',
                                                    temperaturedata,
                                                    '(°C)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  humiditydata))
                                                _buildChartContainer(
                                                    'Humidity',
                                                    humiditydata,
                                                    '(%)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(ittempData))
                                                _buildChartContainer(
                                                    'Temperature',
                                                    ittempData,
                                                    '(°C)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  itpressureData))
                                                _buildChartContainer(
                                                    'Pressure',
                                                    itpressureData,
                                                    '(hPa)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  ithumidityData))
                                                _buildChartContainer(
                                                    'Humidity',
                                                    ithumidityData,
                                                    '(%)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(itrainData))
                                                _buildChartContainer(
                                                    'Rain Level',
                                                    itrainData,
                                                    '(mm)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  itwindspeedData))
                                                _buildChartContainer(
                                                    'Wind Speed',
                                                    itwindspeedData,
                                                    '(m/s)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  itradiationData))
                                                _buildChartContainer(
                                                    'Radiation',
                                                    itradiationData,
                                                    '(W/m²)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  itvisibilityData))
                                                _buildChartContainer(
                                                    'Visibility',
                                                    itvisibilityData,
                                                    '(m)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(fstempData))
                                                _buildChartContainer(
                                                    'Temperature',
                                                    fstempData,
                                                    '(°C)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  fspressureData))
                                                _buildChartContainer(
                                                    'Pressure',
                                                    fspressureData,
                                                    '(hPa)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  fshumidityData))
                                                _buildChartContainer(
                                                    'Humidity',
                                                    fshumidityData,
                                                    '(%)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(fsrainData))
                                                _buildChartContainer(
                                                    'Rain Level',
                                                    fsrainData,
                                                    '(mm)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  fsradiationData))
                                                _buildChartContainer(
                                                    'Radiation',
                                                    fsradiationData,
                                                    '(W/m²)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  fswindspeedData))
                                                _buildChartContainer(
                                                    'Wind Speed',
                                                    fswindspeedData,
                                                    '(m/s)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  fswinddirectionData))
                                                _buildChartContainer(
                                                    'Wind Direction',
                                                    fswinddirectionData,
                                                    '(°)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(temp2Data))
                                                _buildChartContainer(
                                                    'Temperature',
                                                    temp2Data,
                                                    '(°C)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(cod2Data))
                                                _buildChartContainer(
                                                    'COD',
                                                    cod2Data,
                                                    '(mg/L)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(bod2Data))
                                                _buildChartContainer(
                                                    'BOD',
                                                    bod2Data,
                                                    '(mg/L)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              if (hasNonZeroValues(
                                                  wfAverageTemperatureData))
                                                _buildChartContainer(
                                                    'Temperature',
                                                    wfAverageTemperatureData,
                                                    '(°C)',
                                                    ChartType.line,
                                                    isDarkMode),
                                              _buildChartContainer(
                                                  'Rain Level',
                                                  wfrainfallData,
                                                  '(mm)',
                                                  ChartType.line,
                                                  isDarkMode),
                                            ]
                                                .where((widget) =>
                                                    widget !=
                                                    const SizedBox.shrink())
                                                .toList(),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
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

          // Loader overlay
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                // child: Center(
                //   child: CircularProgressIndicator(
                //     valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                //   ),
                // ),
              ),
            ),
          // Download CSV button
          Positioned(
            bottom: 16,
            right: 16,
            child: MouseRegion(
              onEnter: (_) => setState(() => _isHovering = true),
              onExit: (_) => setState(() => _isHovering = false),
              child: ElevatedButton(
                onPressed: () {
                  _showDownloadOptionsDialog(context);
                },
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

// Helper method to build sidebar buttons
  Widget _buildSidebarButton(
    String title,
    String value,
    IconData icon,
    bool isDarkMode, {
    required VoidCallback onPressed,
  }) {
    bool isActive = _activeButton == value;

    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive
              ? (isDarkMode ? Colors.blue[700] : Colors.blue[600])
              : (isDarkMode
                  ? Colors.grey[700]!.withOpacity(0.7)
                  : Colors.white.withOpacity(0.9)),
          foregroundColor: isActive
              ? Colors.white
              : (isDarkMode ? Colors.white : Colors.black),
          elevation: isActive ? 4 : 1,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isActive
                  ? (isDarkMode ? Colors.blue[400]! : Colors.blue[300]!)
                  : (isDarkMode ? Colors.grey[600]! : Colors.grey[400]!),
              width: isActive ? 2 : 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive
                  ? Colors.white
                  : (isDarkMode ? Colors.white70 : Colors.black54),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentValue(
      String parameterName, String currentValue, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Align text to the top
        children: [
          // Display both parameter and value together in a single text widget
          Text(
            '$parameterName: $currentValue $unit',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

// This method will parse the percentage string (e.g., "84%") and return the numeric value
  int _parseBatteryPercentage(String batteryPercentage) {
    try {
      // Remove the '%' symbol and parse the number
      return int.parse(batteryPercentage.replaceAll('%', ''));
    } catch (e) {
      // If parsing fails, return a default value (e.g., 0)
      return 0;
    }
  }

  IconData _getBatteryIcon(int batteryPercentage) {
    if (batteryPercentage <= 0) {
      return Icons.battery_0_bar; // Empty battery
    } else if (batteryPercentage > 0 && batteryPercentage <= 20) {
      return Icons.battery_1_bar; // 20% battery
    } else if (batteryPercentage > 20 && batteryPercentage <= 40) {
      return Icons.battery_2_bar; // 40% battery
    } else if (batteryPercentage > 40 && batteryPercentage <= 60) {
      return Icons.battery_3_bar; // 60% battery
    } else if (batteryPercentage > 60 && batteryPercentage <= 80) {
      return Icons.battery_4_bar; // 80% battery
    } else if (batteryPercentage > 80 && batteryPercentage < 100) {
      return Icons.battery_5_bar; // 90% battery
    } else {
      return Icons.battery_full; // Full battery
    }
  }

  Color _getBatteryColor(double voltage) {
    if (voltage < 3.3) {
      return Colors.red;
    } else if (voltage < 4.0) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  IconData _getfsBatteryIcon(double voltage) {
    if (voltage < 3.3) {
      return Icons.battery_2_bar; // Low battery
    } else if (voltage < 4.0) {
      return Icons.battery_5_bar; // Medium battery
    } else {
      return Icons.battery_full; // Full battery
    }
  }

  IconData _getpercentBatteryIcon(double voltage) {
    double percentage = _convertVoltageToPercentage(voltage);
    if (percentage >= 80) return Icons.battery_full;
    if (percentage >= 50) return Icons.battery_5_bar;
    if (percentage >= 20) return Icons.battery_3_bar;
    return Icons.battery_alert;
  }

  Color _getpercentBatteryColor(double voltage) {
    double percentage = _convertVoltageToPercentage(voltage);
    if (percentage >= 80) return Colors.green;
    if (percentage >= 50) return Colors.yellow;
    if (percentage >= 20) return Colors.orange;
    return Colors.red;
  }

// Add this new method for the combined wind chart (copy/adapted from _buildChartContainer)
  Widget _buildWindChartContainer(
    String title,
    List<ChartData> speedData,
    List<ChartData> directionData,
    bool isDarkMode,
  ) {
    if (speedData.isEmpty) return const SizedBox.shrink();

    // No conversion to km/h, keep original units (assuming m/s from API)
    final convertedSpeed = speedData; // No transformation needed

    final double maxSpeed =
        convertedSpeed.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final double offset = maxSpeed * 0.1 + 1; // Small buffer for arrows

    final bool hasDirection =
        directionData.isNotEmpty && directionData.length == speedData.length;

    List<CartesianChartAnnotation> annotations = [];
    if (hasDirection) {
      for (int i = 0; i < convertedSpeed.length; i++) {
        final double degrees = directionData[i].value;
        annotations.add(
          CartesianChartAnnotation(
            // Corrected to use ChartAnnotation from Syncfusion
            coordinateUnit:
                CoordinateUnit.point, // Changed from 'data' to 'point'
            region: AnnotationRegion.chart,
            x: convertedSpeed[i].timestamp,
            y: maxSpeed + offset,
            widget: Transform.rotate(
              angle: (degrees * math.pi / 180) +
                  math.pi / 2, // Adjust rotation for "from" direction
              child: const Icon(
                Icons.arrow_forward,
                size: 20,
                color: Colors.black,
              ),
            ),
          ),
        );
      }
    }

    bool isSelected = _selectedParam == title;

    return Padding(
      padding: const EdgeInsets.all(0.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        key: _chartKeys[title],
        width: double.infinity,
        height: MediaQuery.of(context).size.width < 800 ? 400 : 500,
        margin: EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.0),
          color: isDarkMode
              ? Color.fromARGB(150, 0, 0, 0)
              : Color.fromARGB(173, 227, 220, 220),
          border: isSelected
              ? Border.all(
                  color: isDarkMode ? Colors.deepOrange : Colors.deepOrange,
                  width: 2.0,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: isSelected || _selectedParam == null ? 0.0 : 100.0,
              sigmaY: isSelected || _selectedParam == null ? 0.0 : 100.0,
            ),
            child: Opacity(
              opacity: isSelected || _selectedParam == null ? 1.0 : 0.2,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize:
                            MediaQuery.of(context).size.width < 800 ? 18 : 22,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Focus(
                      autofocus: true,
                      child: RawKeyboardListener(
                        focusNode: _focusNode,
                        autofocus: true,
                        onKey: (RawKeyEvent event) {
                          if (event is RawKeyDownEvent &&
                              (event.logicalKey ==
                                      LogicalKeyboardKey.shiftLeft ||
                                  event.logicalKey ==
                                      LogicalKeyboardKey.shiftRight)) {
                            setState(() {
                              isShiftPressed = true;
                            });
                          } else if (event is RawKeyUpEvent &&
                              (event.logicalKey ==
                                      LogicalKeyboardKey.shiftLeft ||
                                  event.logicalKey ==
                                      LogicalKeyboardKey.shiftRight)) {
                            setState(() {
                              isShiftPressed = false;
                            });
                          }
                        },
                        child: MouseRegion(
                          onEnter: (_) => _focusNode.requestFocus(),
                          child: Listener(
                            onPointerSignal: (PointerSignalEvent event) {
                              if (event is PointerScrollEvent &&
                                  isShiftPressed) {}
                            },
                            child: SfCartesianChart(
                              annotations: annotations, // Add this for arrows
                              plotAreaBackgroundColor: isDarkMode
                                  ? Color.fromARGB(100, 0, 0, 0)
                                  : Color.fromARGB(189, 222, 218, 218),
                              primaryXAxis: DateTimeAxis(
                                dateFormat: _lastSelectedRange == 'single'
                                    ? DateFormat('MM/dd hh:mm a')
                                    : (_lastSelectedRange == '3months' ||
                                            _lastSelectedRange == '1year'
                                        ? DateFormat('MM/dd')
                                        : DateFormat('MM/dd')),
                                title: AxisTitle(
                                  text: 'Time',
                                  textStyle: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                labelStyle: TextStyle(
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                ),
                                labelRotation: 70,
                                edgeLabelPlacement: EdgeLabelPlacement.shift,
                                intervalType: _lastSelectedRange == 'single' ||
                                        _lastSelectedRange == '3months' ||
                                        _lastSelectedRange == '1year'
                                    ? DateTimeIntervalType.auto
                                    : DateTimeIntervalType.days,
                                interval: _lastSelectedRange == 'single' ||
                                        _lastSelectedRange == '3months' ||
                                        _lastSelectedRange == '1year'
                                    ? null
                                    : 1.0,
                                enableAutoIntervalOnZooming: true,
                                majorGridLines: _lastSelectedRange ==
                                            'single' ||
                                        _lastSelectedRange == '3months' ||
                                        _lastSelectedRange == '1year'
                                    ? MajorGridLines(
                                        width: 1.0,
                                        dashArray: [5, 5],
                                        color: isDarkMode
                                            ? Color.fromARGB(255, 141, 144, 148)
                                            : Color.fromARGB(255, 48, 48, 48),
                                      )
                                    : MajorGridLines(width: 0),
                                majorTickLines: MajorTickLines(
                                  size: 6.0,
                                  width: 1.0,
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                ),
                                plotBands: _lastSelectedRange == 'single' ||
                                        _lastSelectedRange == '3months' ||
                                        _lastSelectedRange == '1year'
                                    ? []
                                    : _generateNoonPlotBands(convertedSpeed,
                                        isDarkMode), // Fixed data reference
                              ),
                              primaryYAxis: NumericAxis(
                                minimum: 0,
                                title: AxisTitle(
                                  text:
                                      '(m/s)', // Updated to reflect original unit
                                  textStyle: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                labelStyle: TextStyle(
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                ),
                                axisLine: AxisLine(width: 1),
                                majorGridLines: MajorGridLines(width: 0),
                              ),
                              trackballBehavior: TrackballBehavior(
                                enable: true,
                                activationMode: ActivationMode.singleTap,
                                lineType: TrackballLineType.vertical,
                                lineColor: isDarkMode
                                    ? Colors.blue
                                    : Color.fromARGB(255, 42, 147, 212),
                                lineWidth: 1,
                                markerSettings: TrackballMarkerSettings(
                                  markerVisibility:
                                      TrackballVisibilityMode.visible,
                                  width: 8,
                                  height: 8,
                                  borderWidth: 2,
                                  color: isDarkMode
                                      ? Colors.blue
                                      : Color.fromARGB(255, 42, 147, 212),
                                ),
                                builder: (BuildContext context,
                                    TrackballDetails details) {
                                  try {
                                    final DateTime? time = details.point?.x;
                                    final num? value = details.point?.y;
                                    if (time == null || value == null) {
                                      return const SizedBox();
                                    }
                                    String formattedDate;
                                    if (_lastSelectedRange == '1year') {
                                      formattedDate =
                                          DateFormat('MM/dd').format(time);
                                    } else {
                                      formattedDate =
                                          DateFormat('MM/dd hh:mm a')
                                              .format(time);
                                    }
                                    String valueText =
                                        'Speed: ${value.toStringAsFixed(1)} m/s'; // 1 decimal for precision
                                    String directionText = '';
                                    if (hasDirection &&
                                        details.pointIndex != null) {
                                      final double dir =
                                          directionData[details.pointIndex!]
                                              .value;
                                      final String dirStr =
                                          _getWindDirection(dir);
                                      directionText = ' from $dirStr';
                                    }
                                    return Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isDarkMode
                                            ? Color.fromARGB(200, 0, 0, 0)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            formattedDate,
                                            style: TextStyle(
                                              color: isDarkMode
                                                  ? Colors.white
                                                  : Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '$valueText$directionText',
                                            style: TextStyle(
                                              color: isDarkMode
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  } catch (e) {
                                    return const SizedBox();
                                  }
                                },
                              ),
                              zoomPanBehavior: ZoomPanBehavior(
                                zoomMode: ZoomMode.x,
                                enablePanning: true,
                                enablePinching: true,
                                enableMouseWheelZooming: isShiftPressed,
                              ),
                              series: <CartesianSeries<ChartData, DateTime>>[
                                _getChartSeries(
                                    ChartType.line, convertedSpeed, title),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartContainer(
    String title,
    List<ChartData> data,
    String yAxisTitle,
    ChartType chartType,
    bool isDarkMode,
  ) {
    // Determine if this chart corresponds to the selected parameter
    bool isSelected = _selectedParam == title;

    return data.isNotEmpty
        ? Padding(
            padding: const EdgeInsets.all(0.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              key: _chartKeys[title],
              width: double.infinity,
              height: MediaQuery.of(context).size.width < 800 ? 400 : 500,
              margin: EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.0),
                color: isDarkMode
                    ? Color.fromARGB(150, 0, 0, 0)
                    : Color.fromARGB(173, 227, 220, 220),
                border: isSelected
                    ? Border.all(
                        color:
                            isDarkMode ? Colors.deepOrange : Colors.deepOrange,
                        width: 2.0,
                      )
                    : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color.fromARGB(255, 0, 0, 0)
                              .withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.0),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: isSelected || _selectedParam == null ? 0.0 : 100.0,
                    sigmaY: isSelected || _selectedParam == null ? 0.0 : 100.0,
                  ),
                  child: Opacity(
                    opacity: isSelected || _selectedParam == null ? 1.0 : 0.2,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text(
                            '$title',
                            style: TextStyle(
                              fontSize: MediaQuery.of(context).size.width < 800
                                  ? 18
                                  : 22,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        if (widget.deviceName.startsWith('CL'))
                          Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Builder(
                              builder: (BuildContext context) {
                                final screenWidth =
                                    MediaQuery.of(context).size.width;
                                double boxSize;
                                double textSize;
                                double spacing;

                                if (screenWidth < 800) {
                                  boxSize = 15.0;
                                  textSize = 15.0;
                                  spacing = 12.0;
                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _buildColorBox(Colors.white, '< 0.01 ',
                                            boxSize, textSize),
                                        SizedBox(width: spacing),
                                        _buildColorBox(Colors.green,
                                            '> 0.01 - 0.5', boxSize, textSize),
                                        SizedBox(width: spacing),
                                        _buildColorBox(Colors.yellow,
                                            '> 0.5 - 1.0', boxSize, textSize),
                                        SizedBox(width: spacing),
                                        _buildColorBox(Colors.orange,
                                            '> 1.0 - 4.0', boxSize, textSize),
                                        SizedBox(width: spacing),
                                        _buildColorBox(Colors.red, ' Above 4.0',
                                            boxSize, textSize),
                                      ],
                                    ),
                                  );
                                } else {
                                  boxSize = 20.0;
                                  textSize = 16.0;
                                  spacing = 45.0;
                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildColorBox(Colors.white, '< 0.01 ',
                                            boxSize, textSize),
                                        SizedBox(width: spacing),
                                        _buildColorBox(Colors.green,
                                            '> 0.01 - 0.5', boxSize, textSize),
                                        SizedBox(width: spacing),
                                        _buildColorBox(Colors.yellow,
                                            '> 0.5 - 1.0', boxSize, textSize),
                                        SizedBox(width: spacing),
                                        _buildColorBox(Colors.orange,
                                            '> 1.0 - 4.0', boxSize, textSize),
                                        SizedBox(width: spacing),
                                        _buildColorBox(Colors.red, ' Above 4.0',
                                            boxSize, textSize),
                                      ],
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        Expanded(
                          child: Focus(
                            autofocus: true,
                            child: RawKeyboardListener(
                              focusNode: _focusNode,
                              autofocus: true,
                              onKey: (RawKeyEvent event) {
                                if (event is RawKeyDownEvent &&
                                    (event.logicalKey ==
                                            LogicalKeyboardKey.shiftLeft ||
                                        event.logicalKey ==
                                            LogicalKeyboardKey.shiftRight)) {
                                  setState(() {
                                    isShiftPressed = true;
                                  });
                                } else if (event is RawKeyUpEvent &&
                                    (event.logicalKey ==
                                            LogicalKeyboardKey.shiftLeft ||
                                        event.logicalKey ==
                                            LogicalKeyboardKey.shiftRight)) {
                                  setState(() {
                                    isShiftPressed = false;
                                  });
                                }
                              },
                              child: MouseRegion(
                                onEnter: (_) => _focusNode.requestFocus(),
                                child: Listener(
                                  onPointerSignal: (PointerSignalEvent event) {
                                    if (event is PointerScrollEvent &&
                                        isShiftPressed) {}
                                  },
                                  child: SfCartesianChart(
                                    plotAreaBackgroundColor: isDarkMode
                                        ? Color.fromARGB(100, 0, 0, 0)
                                        : Color.fromARGB(189, 222, 218, 218),
                                    primaryXAxis: DateTimeAxis(
                                      dateFormat: _lastSelectedRange == 'single'
                                          ? DateFormat('MM/dd hh:mm a')
                                          : (_lastSelectedRange == '3months' ||
                                                  _lastSelectedRange == '1year'
                                              ? DateFormat('MM/dd')
                                              : DateFormat('MM/dd')),
                                      title: AxisTitle(
                                        text: 'Time',
                                        textStyle: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      labelStyle: TextStyle(
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                      labelRotation: 70,
                                      edgeLabelPlacement:
                                          EdgeLabelPlacement.shift,
                                      intervalType: _lastSelectedRange ==
                                                  'single' ||
                                              _lastSelectedRange == '3months' ||
                                              _lastSelectedRange == '1year'
                                          ? DateTimeIntervalType.auto
                                          : DateTimeIntervalType.days,
                                      interval: _lastSelectedRange ==
                                                  'single' ||
                                              _lastSelectedRange == '3months' ||
                                              _lastSelectedRange == '1year'
                                          ? null
                                          : 1.0,
                                      enableAutoIntervalOnZooming: true,
                                      majorGridLines: _lastSelectedRange ==
                                                  'single' ||
                                              _lastSelectedRange == '3months' ||
                                              _lastSelectedRange == '1year'
                                          ? MajorGridLines(
                                              width: 1.0,
                                              dashArray: [5, 5],
                                              color: isDarkMode
                                                  ? Color.fromARGB(
                                                      255, 141, 144, 148)
                                                  : Color.fromARGB(
                                                      255, 48, 48, 48),
                                            )
                                          : MajorGridLines(width: 0),
                                      majorTickLines: MajorTickLines(
                                        size: 6.0,
                                        width: 1.0,
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                      plotBands: _lastSelectedRange ==
                                                  'single' ||
                                              _lastSelectedRange == '3months' ||
                                              _lastSelectedRange == '1year'
                                          ? []
                                          : _generateNoonPlotBands(
                                              data, isDarkMode),
                                    ),
                                    primaryYAxis: NumericAxis(
                                      minimum: 0,
                                      title: AxisTitle(
                                        text: yAxisTitle,
                                        textStyle: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      labelStyle: TextStyle(
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                      axisLine: AxisLine(width: 1),
                                      majorGridLines: MajorGridLines(width: 0),
                                    ),
                                    trackballBehavior: TrackballBehavior(
                                      enable: true,
                                      activationMode: ActivationMode.singleTap,
                                      lineType: TrackballLineType.vertical,
                                      lineColor: isDarkMode
                                          ? Colors.blue
                                          : Color.fromARGB(255, 42, 147, 212),
                                      lineWidth: 1,
                                      markerSettings: TrackballMarkerSettings(
                                        markerVisibility:
                                            TrackballVisibilityMode.visible,
                                        width: 8,
                                        height: 8,
                                        borderWidth: 2,
                                        color: isDarkMode
                                            ? Colors.blue
                                            : Color.fromARGB(255, 42, 147, 212),
                                      ),
                                      builder: (BuildContext context,
                                          TrackballDetails details) {
                                        try {
                                          final DateTime? time =
                                              details.point?.x;
                                          final num? value = details.point?.y;

                                          if (time == null || value == null) {
                                            return const SizedBox();
                                          }

                                          String formattedDate;
                                          if (_lastSelectedRange == '1year') {
                                            formattedDate = DateFormat('MM/dd')
                                                .format(time);
                                          } else {
                                            formattedDate =
                                                DateFormat('MM/dd hh:mm a')
                                                    .format(time);
                                          }

                                          return Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isDarkMode
                                                  ? Color.fromARGB(200, 0, 0, 0)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  formattedDate,
                                                  style: TextStyle(
                                                    color: isDarkMode
                                                        ? Colors.white
                                                        : Colors.black,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  'Value: $value',
                                                  style: TextStyle(
                                                    color: isDarkMode
                                                        ? Colors.white
                                                        : Colors.black,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        } catch (e) {
                                          return const SizedBox();
                                        }
                                      },
                                    ),
                                    zoomPanBehavior: ZoomPanBehavior(
                                      zoomMode: ZoomMode.x,
                                      enablePanning: true,
                                      enablePinching: true,
                                      enableMouseWheelZooming: isShiftPressed,
                                    ),
                                    series: <CartesianSeries<ChartData,
                                        DateTime>>[
                                      _getChartSeries(chartType, data, title),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ))
        : Container();
  }

  Widget _buildColorBox(
      Color color, String range, double boxSize, double textSize) {
    return Row(
      children: [
        Container(
          width: boxSize,
          height: boxSize,
          color: color,
        ),
        SizedBox(width: 8), // Fixed width between box and text
        Text(
          range,
          style: TextStyle(
            color: Colors.white,
            fontSize: textSize,
          ),
        ),
      ],
    );
  }

  CartesianSeries<ChartData, DateTime> _getChartSeries(
      ChartType chartType, List<ChartData> data, String title) {
    switch (chartType) {
      case ChartType.line:
        if (widget.deviceName.startsWith('CL')) {
          // Chlorine sensor
          return LineSeries<ChartData, DateTime>(
            markerSettings: const MarkerSettings(
              height: 6.0,
              width: 6.0,
              isVisible: true,
            ),
            dataSource: data,
            xValueMapper: (ChartData data, _) => data.timestamp,
            yValueMapper: (ChartData data, _) => data.value,
            name: title,
            color: Colors.blue,
            pointColorMapper: (ChartData data, _) {
              // Color range for chlorine sensor
              if (data.value >= 0.01 && data.value <= 0.5) {
                return Colors.green;
              } else if (data.value > 0.5 && data.value <= 1.0) {
                return Colors.yellow;
              } else if (data.value > 1.0 && data.value <= 4.0) {
                return Colors.orange;
              } else if (data.value > 4.0) {
                return Colors.red;
              }
              return Colors.white; // Default color
            },
          );
        } else {
          // Other devices — blue gradient
          return AreaSeries<ChartData, DateTime>(
            dataSource: data,
            xValueMapper: (ChartData data, _) => data.timestamp,
            yValueMapper: (ChartData data, _) => data.value,
            name: title,
            borderColor: Theme.of(context).brightness == Brightness.light
                ? Color.fromARGB(
                    255, 0, 120, 215) // Light mode: vibrant cyan-blue
                : Colors.blue, // Dark mode: original blue
            borderWidth: 3,
            gradient: LinearGradient(
              colors: [
                (Theme.of(context).brightness == Brightness.light
                    ? Color.fromARGB(255, 0, 120, 215).withOpacity(
                        0.4) // Light mode: vibrant cyan-blue with opacity
                    : Colors.blue.withOpacity(
                        0.4)), // Dark mode: original blue with opacity
                (Theme.of(context).brightness == Brightness.light
                    ? Color.fromARGB(255, 0, 120, 215).withOpacity(
                        0.0) // Light mode: vibrant cyan-blue with no opacity
                    : Colors.blue.withOpacity(
                        0.0)), // Dark mode: original blue with no opacity
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            markerSettings: const MarkerSettings(isVisible: false),
          );
        }

      default:
        return AreaSeries<ChartData, DateTime>(
          dataSource: data,
          xValueMapper: (ChartData data, _) => data.timestamp,
          yValueMapper: (ChartData data, _) => data.value,
          name: title,
          borderColor: Colors.blue,
          borderWidth: 2,
          gradient: LinearGradient(
            colors: [
              Colors.blue.withOpacity(0.4),
              Colors.blue.withOpacity(0.0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          markerSettings: const MarkerSettings(isVisible: false),
        );
    }
  }
}

enum ChartType {
  line,
}

class ChartData {
  final DateTime timestamp;
  final double value;

  ChartData({required this.timestamp, required this.value});
}
