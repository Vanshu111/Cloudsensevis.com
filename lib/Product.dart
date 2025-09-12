




import 'package:cloud_sense_webapp/Datasheet_Download.dart';
import 'package:cloud_sense_webapp/drawer.dart';
import 'package:cloud_sense_webapp/footer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_sense_webapp/appbar.dart';

final List<Map<String, dynamic>> allSensors = [
  {
    "title": "Temperature and Humidity ",
    "highlightText": "Probe",
    "subtitle":  "Accurate measurements for temperature and humidity",
    "bannerPoints": [
       "Real-time temperature & humidity sensing for critical applications",
    "Provides both analog (0-1000)mV and digital (RS485) output",
    "Reliable Industrial grade monitoring with CRC validated communications"
    ],
    "features": [
      "High precision temperature and humidity sensing probe",
    "Compact low power design suitable for IoT and embedded applications",
    "Robust RS485/MODBUS RTU communications for industrial use",
    "CRC validations provide reliable and error free data transfer",
    "Output provides both analog and digital value"
    ],
    "applications": [
       "Healthcare and Medical Facilities",
    "Agriculture and Farming",
    "Cold Storage and Warehouse",
    "Food and Beverage Industry",
    "Transportation and Logistics"

    ],
    "specifications": [
           "Supply Voltage : 5-12 V DC",
      "Range of Temperature : -40 to +60 °C",
      "Range of Humidity : 0-100%",
      "Communications Protocol : RS485 & 0-1V (ADC)",
      "Temperature Accuracy : ±0.1°C",
      "Humidity Accuracy: ±1.0% RH",
    ],
    "imagePath":    "assets/thprobe.png",
    "email": "sharmasejal2701@gmail.com",
    "datasheetKey":  "TempHumidityProbe",
  },

  {
   "title": "Temperature Humidity Light Intensity and Pressure",
    "highlightText": "Sensor",
    "subtitle": "Compact environmental sensing unit for precise measurements",
    "bannerPoints": [
      "High-precision measurements with cutting-edge sensor",
      "Robust design for long-term reliability",
      "Flexible model to diverse applications",
    ],
    "features": [
      "Accurate Wide Environmental Measurement Range",
      "Maintenance-free for long-term field deployment",
      "Low power consumption, suitable for remote station",
      "Robust, IP66 Compact design",
      "All-weather protection",
      "Compact & lightweight, easy to install with radiation shield",
    ],
    "applications": [
      "Agriculture and smart irrigation system",
      "Environmental monitoring",
      "Healthcare & Medical Facilities",
      "Greenhouses and Indoor Farming",
      "Industrial Process monitoring (HVAC, Food processing)",
      "Safety and Security",
    ],
    "specifications": [
      "Supply Voltage : 3.3 V DC",
      "Range of Temperature : -40 to +85 °C",
      "Range of Humidity : 0-100%",
      "Range of Pressure : 300-1100 hPa",
      "Range of Light Intensity: 0-140000 Lux",
      "Communications Protocol : I2C",
      "Temperature Accuracy : ±1°C",
      "Humidity Accuracy:±3.0% RH",
      "Pressure Accuracy:±1hPa",
      "LUX Accuracy:±3%"
    ],
    "imagePath": "assets/luxpressure.png",
    "email": "sharmasejal2701@gmail.com",
    "datasheetKey": "ARTH",
  },
  // wind
  { "title":"Ultrasonic ",
    "highlightText":"Anemometer",
    "subtitle":  "Ultrasonic Anemometer for precise wind speed and wind direction",
    "bannerPoints": [
        "Accurate wind monitoring",
    "Real time speed and direction measurement",
    "Robust and compact design"
    ],
    "features": [
   "High Quality measurement up to 60m/s (216km/h)",
    "High accuracy with fast response time",
    "0°-360° wind direction coverage with 1° resolution",
    "Low Maintenance, ensuring low cost of ownership",
    "Robust design for all weather conditions"
    ],
    "applications": [
         "Weather monitoring stations",
    "Smart agriculture and precision farming",
    "Ports and harbours",
    "Runways and helipads",
    "Wind turbine performance monitoring"

    ],
    "specifications": [
         "Input Supply voltage: 2V - 16V",
      "Measure wind speed and wind direction via Δ ToF",
      "Communication protocols: RS232 or RS485 (Modbus)",
      "Ultra low power sleep mode",
      "Weight : 0.6kg",
      "Heating option (-40℃ to +70℃)",
    ],
    "imagePath":  "assets/ultrasonic.png",
    "email": "sharmasejal2701@gmail.com",
    "datasheetKey": "WindSensor",
  },
  // rain
  { "title": "Rain",
    "highlightText":  "Gauge",
    "subtitle":     "Tipping Bucket Rain Gauge",
    "bannerPoints": [
      "Measure rain via Tipping Bucket Mechanism",
    "Accurate and Low Maintenance",
    "Robust design for all weather conditions"
    ],
    "features": [
     "Balanced tipping bucket mechanism ensures high accuracy",
    "Minimal moving parts → long-term reliability with low maintenance",
    "Reed switch / magnetic sensor for precise detection",
    "Durable ABS body with weather resistance",
    "Easy integration with data loggers and weather stations for automated rainfall recording"
    ],
    "applications": [
      "Meteorological stations for rainfall monitoring",
    "Agriculture & irrigation planning",
    "Environmental monitoring & climate research",
    "Suitable for precise/general purpose rain monitoring",
    "Urban drainage & stormwater management"
    ],
    "specifications": [
           "Made of ABS material, offering durability and weather resistance",
      "Available in two diameter options: 159.5 mm and 200 mm",
      "Collection areas: 200 cm² and 314 cm²",
      "Resolution: 0.2 mm or 0.5 mm depending on the model",
      "Equipped with reed switch or magnetic sensor for tip detection",
      "Data Output: Number of tips × Resolution = Total Rainfall",
    ],
    "imagePath":  "assets/gauge.png",
    "email": "sharmasejal2701@gmail.com",
    "datasheetKey":"RainGauge",
  },
  // logger
   {"title":  "Data ",
    "highlightText":"Logger",
    "subtitle":  "Reliable Data Logging & seamless Connectivity",
    "bannerPoints": [
       "4G Dual sim With multi protocol Support",
    "Advance power management with solar charging",
    "Robust Design with IP66 Rating."
    ],
    "features": [
   "4G Dual sim connectivity",
    "25-30 Days Data Backup",
    "Support Multi protocol communication Interfaces",
    "Robust IP66 Enclosure for harsh weather condition",
    "Solar and Battery Powered option for remote site."
    ],
    "applications": [
 "Remote weather monitoring stations",
    "Smart agriculture and irrigation management",
    "Industrial and environmental monitoring",
    "Smart cities and IoT projects",
    "Cold storage management"
    ],
    "specifications": [
         "Input Supply voltage: 5V - 16",
      "Communication interfaces: ADC, UART, I2C, SPI, RS232, RS485",
      "Data Support: HTTP, HTTPS, MQTT, FTP",
      "Flexible Power input options : USB Type C or LiIon Battery",
      "Support SD card",
      "Built in LTE and GPS Antennas",
      "Inbuild Real Time clock",
      "Ultra low power sleep mode",
    ],
    "imagePath":  "assets/dataloggerrender.png",
    "email": "sharmasejal2701@gmail.com",
    "datasheetKey":  "DataLogger",
  },
  // gATEWAY
   {"title": "BLE",
    "highlightText": "Gateway",
    "subtitle":"BLE Gateway For industrial IoT Applications",
    "bannerPoints": [
        "Multi-Industry IoT Gateway Solution",
    "Real-Time Data Aggregation",
    "Scalable Gateway for 100+ nodes"
    ],
    "features": [
    "Real Time Monitoring with low power consumptions",
    "FOTA (Firmware Over the Air)",
    "Supports 100+ nodes with BLE range up to 1 km Line of sight",
    "IP66 & Compact design",
    "Connectivity option: 4G, WIFI, LAN"
    ],
    "applications": [
      "Smart Agriculture & Precision farming",
    "Logistics and asset tracking",
    "Industrial equipment and health monitoring",
    "Healthcare wearable data collections",
    "Home Automations and energy management"
    ],
    "specifications": [
          "Input Voltage Range : 5 - 30 v",
      "On board led indications for networking , cloud and BLE connectivity.",
      "Processor : Dual- Core Arm Cortex-M33.",
      "Controller used is nrf5340.",
      "Bluetooth version: BLE 5.4",
      "On board flash memory, sd card slot, MIC , sim card, gsm and BLE Antenna.",
      "Support Multiple Communications protocol such as SPI,I2C,I2S,UART etc.",
      "Integrated with both battery and solar panel.",
      "512KB RAM +1MB Flash",
    ],
    "imagePath":  "assets/blegateway.png",
    "email": "sharmasejal2701@gmail.com",
    "datasheetKey":"Gateway",
  },
];


class ProductPage extends StatelessWidget {
  final int sensorIndex;
  const ProductPage({super.key, required this.sensorIndex});

  @override
  Widget build(BuildContext context) {
    final sensor = allSensors[sensorIndex];

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    final isWideScreen = screenWidth > 1024;
    final isTablet = screenWidth > 700 && screenWidth <= 1024;

    final heroHeight = isWideScreen ? 450.0 : (isTablet ? 400.0 : 350.0);

    double headlineSize;
    double bannerTextSize;
    double bannerPointSize;

    if (isWideScreen) {
      headlineSize = 45;
      bannerTextSize = 20;
      bannerPointSize = 16;
    } else if (isTablet) {
      headlineSize = 35;
      bannerTextSize = 18;
      bannerPointSize = 16;
    } else {
      headlineSize = 28;
      bannerTextSize = 14;
      bannerPointSize = 13;
    }

    return Scaffold(
      appBar: AppBarWidget(),
      endDrawer: !isWideScreen ? const EndDrawerWidget() : null,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkMode
                  ? [const Color(0xFF393939), const Color(0xFF02364C)]
                  : [const Color(0xFFBFF2ED), const Color(0xFF4F6A70)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (isWideScreen)
                  _buildHeroDesktop(heroHeight, headlineSize, bannerTextSize,
                          bannerPointSize, context, isDarkMode, sensor)
                      .animate()
                      .slideX(begin: -0.2, duration: 1600.ms)
                      .fadeIn(duration: 1600.ms)
                else if (isTablet)
                  _buildHeroTablet(heroHeight, headlineSize, bannerTextSize,
                          bannerPointSize, context, isDarkMode, sensor)
                      .animate()
                      .slideY(begin: -0.2, duration: 1600.ms)
                      .fadeIn(duration: 1600.ms)
                else
                  _buildHeroMobile(heroHeight, headlineSize, bannerTextSize,
                          bannerPointSize, context, isDarkMode, sensor)
                      .animate()
                      .slideY(begin: -0.2, duration: 1600.ms)
                      .fadeIn(duration: 1600.ms),

                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: (isWideScreen || isTablet)
                      ? _buildIpadLayout(isDarkMode, sensor)
                          .animate()
                          .fadeIn(duration: 1600.ms)
                          .slideY(begin: 0.2, duration: 1600.ms)
                      : Column(
                          children: [
                            _buildFeaturesCard(isDarkMode, sensor)
                                .animate()
                                .fadeIn(duration: 1500.ms)
                                .slideX(begin: -0.2, duration: 1500.ms),
                            const SizedBox(height: 16),
                            _buildApplicationsCard(isDarkMode, sensor)
                                .animate()
                                .fadeIn(duration: 1600.ms)
                                .slideX(begin: 0.2, duration: 1600.ms),
                          ],
                        ),
                ),

                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isWideScreen ? 1000 : double.infinity,
                      ),
                      child: _buildSpecificationsCard(context, isDarkMode, sensor)
                          .animate()
                          .fadeIn(duration: 1700.ms)
                          .slideY(begin: 0.3, duration: 1700.ms),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Footer()
                    .animate()
                    .fadeIn(duration: 1800.ms)
                    .slideY(begin: 0.2, duration: 1800.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroDesktop(double heroHeight, double headlineSize,
      double bannerTextSize, double bannerPointSize, BuildContext context, bool isDarkMode, Map sensor) {
    return Container(
      color: isDarkMode ? const Color(0xFF1C3B4B) : const Color(0xFF4E7F85),
      padding: const EdgeInsets.symmetric(horizontal: 92, vertical: 24),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: _buildHeroText(
              headlineSize,
              bannerTextSize,
              bannerPointSize,
              context,
              sensor,
            )
                .animate()
                .fadeIn(duration: 1500.ms)
                .slideX(begin: -0.2, duration: 1600.ms),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 450),
              child: Image.asset(sensor["imagePath"], fit: BoxFit.contain)
                  .animate()
                  .fadeIn(duration: 1600.ms)
                  .scale(duration: 1800.ms, curve: Curves.easeOutBack),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroTablet(double heroHeight, double headlineSize,
      double bannerTextSize, double bannerPointSize, BuildContext context, bool isDarkMode, Map sensor) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: isDarkMode ? const Color(0xFF1C3B4B) : const Color(0xFF4E7F85),
          padding: const EdgeInsets.all(16),
          child: _buildHeroText(
                  headlineSize, bannerTextSize, bannerPointSize, context, sensor)
              .animate()
              .fadeIn(duration: 1400.ms)
              .slideX(begin: -0.2, duration: 1400.ms),
        ),
        SizedBox(
          height: heroHeight * 0.6,
          child: Image.asset(sensor["imagePath"], fit: BoxFit.contain)
              .animate()
              .fadeIn(duration: 1600.ms)
              .scale(duration: 1800.ms, curve: Curves.easeOutBack),
        ),
      ],
    );
  }

  Widget _buildHeroMobile(double heroHeight, double headlineSize,
      double bannerTextSize, double bannerPointSize, BuildContext context, bool isDarkMode, Map sensor) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: isDarkMode ? const Color(0xFF1C3B4B) : const Color(0xFF4E7F85),
          padding: const EdgeInsets.all(16),
          child: _buildHeroText(
                  headlineSize, bannerTextSize, bannerPointSize, context, sensor)
              .animate()
              .fadeIn(duration: 1400.ms)
              .slideX(begin: -0.2, duration: 1400.ms),
        ),
        SizedBox(
          height: heroHeight * 0.6,
          child: Image.asset(sensor["imagePath"], fit: BoxFit.contain)
              .animate()
              .fadeIn(duration: 1600.ms)
              .scale(duration: 1800.ms, curve: Curves.easeOutBack),
        ),
      ],
    );
  }

  // ---------------- HERO TEXT ----------------
  Widget _buildHeroText(double headlineSize, double bannerTextSize,
      double bannerPointSize, BuildContext context, Map sensor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: "${sensor["title"]} ",
                style: TextStyle(
                    fontSize: headlineSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.lightBlueAccent),
              ),
              TextSpan(
                text: sensor["highlightText"],
                style: TextStyle(
                    fontSize: headlineSize,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(255, 219, 80, 145)),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 6, bottom: 16),
          height: 3,
          width: headlineSize * 5,
          color: Colors.lightBlueAccent,
        ),
        Text(
          sensor["subtitle"],
          style: TextStyle(
              fontSize: bannerTextSize,
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ).animate().fadeIn(duration: 1400.ms).slideY(begin: 0.2, duration: 1400.ms),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: (sensor["bannerPoints"] as List<dynamic>)
              .map((point) => BannerPoint(point, fontSize: bannerPointSize)
                  .animate()
                  .fadeIn(duration: 1300.ms)
                  .slideX(begin: -0.1, duration: 1300.ms))
              .toList(),
        ),
        const SizedBox(height: 20),
        _buildBannerButton(
          "Enquire",
          Colors.teal,
          () => _sendEmail(context, sensor["email"]),
        ).animate().scale(duration: 1400.ms, curve: Curves.easeOutBack),
      ],
    );
  }

  Future<void> _sendEmail(BuildContext context, String email) async {
    final subject = "Product Enquiry";
    final body = "Hello, I am interested in your product.";
    final Uri mailtoUri =
        Uri(scheme: 'mailto', path: email, query: "subject=$subject&body=$body");

    if (await canLaunchUrl(mailtoUri)) {
      await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open email client")),
      );
    }
  }

  // ---------------- FEATURES & APPLICATIONS ----------------
  Widget _buildIpadLayout(bool isDarkMode, Map sensor) {
    return Row(
      children: [
        Expanded(
            child: _buildFeaturesCard(isDarkMode, sensor)
                .animate()
                .fadeIn(duration: 1400.ms)
                .slideX(begin: -0.2, duration: 1400.ms)),
        const SizedBox(width: 16),
        Expanded(
            child: _buildApplicationsCard(isDarkMode, sensor)
                .animate()
                .fadeIn(duration: 1400.ms)
                .slideX(begin: 0.2, duration: 1400.ms)),
      ],
    );
  }

  Widget _buildFeaturesCard(bool isDarkMode, Map sensor) {
    return HoverCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Key Features",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.blue.shade800)),
            const SizedBox(height: 10),
            ...(sensor["features"] as List<dynamic>)
                .map((f) => featureItem(f, isDarkMode)
                    .animate()
                    .fadeIn(duration: 1300.ms)
                    .slideY(begin: 0.1, duration: 1300.ms))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationsCard(bool isDarkMode, Map sensor) {
    return HoverCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Applications",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.blue.shade800)),
            const SizedBox(height: 10),
            ...(sensor["applications"] as List<dynamic>)
                .map((a) => featureItem(a, isDarkMode)
                    .animate()
                    .fadeIn(duration: 1300.ms)
                    .slideY(begin: 0.1, duration: 1300.ms))
                .toList(),
          ],
        ),
      ),
    );
  }

  // ---------------- SPECIFICATIONS ----------------
  Widget _buildSpecificationsCard(
      BuildContext context, bool isDarkMode, Map sensor) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 800;
    final specs = sensor["specifications"] as List<dynamic>;

    return HoverCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Specifications",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.blue.shade800)),
            const SizedBox(height: 20),
            if (isWideScreen)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: specs
                            .sublist(0, (specs.length / 2).ceil())
                            .map((s) => featureItem(s, isDarkMode)
                                .animate()
                                .fadeIn(duration: 1300.ms)
                                .slideX(begin: -0.1, duration: 1300.ms))
                            .toList()),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: specs
                            .sublist((specs.length / 2).ceil())
                            .map((s) => featureItem(s, isDarkMode)
                                .animate()
                                .fadeIn(duration: 1300.ms)
                                .slideX(begin: 0.1, duration: 1300.ms))
                            .toList()),
                  ),
                ],
              )
            else
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: specs
                      .map((s) => featureItem(s, isDarkMode)
                          .animate()
                          .fadeIn(duration: 1300.ms)
                          .slideY(begin: 0.1, duration: 1300.ms))
                      .toList()),
            const SizedBox(height: 40),
            Center(
              child: _buildBannerButton(
                "Download Datasheet",
                Colors.teal,
                () {
                  DownloadManager.downloadFile(
                      context: context,
                      sensorKey: sensor["datasheetKey"],
                      fileType: "datasheet");
                },
              ).animate().scale(duration: 1400.ms, curve: Curves.easeOutBack),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- HELPERS ----------------

static Widget _buildBannerButton(
    String label, Color color, VoidCallback onPressed) {
  return ElevatedButton.icon(
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      elevation: 8, 
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ),
    onPressed: onPressed,
    icon: const Icon(Icons.arrow_forward, color: Colors.white),
    label: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    ),
  )
    
      .animate(
        onPlay: (controller) => controller.repeat(reverse: true),
      )
      .scale(
        duration: 1200.ms,
        begin: const Offset(1, 1),
        end: const Offset(1.08, 1.08),
        curve: Curves.easeInOut,
      )
 
      .then() 
      .shimmer(
        duration: 1500.ms,
        color: Colors.white.withOpacity(0.2), 
      )
      .then()
      .blurXY(
        begin: 0,
        end: 4, 
        duration: 1200.ms,
        curve: Curves.easeInOut,
      );
}


 Widget featureItem(String text, bool isDarkMode) {
  return Card(
    elevation: 3,
    color: isDarkMode ? const Color.fromARGB(255, 44, 44, 44) : const Color.fromARGB(255, 243, 243, 243),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.check_circle,
              color: isDarkMode ? Colors.tealAccent : Colors.teal, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : Colors.black87))),
        ],
      ),
    ),
  );
}

}

  


// ------------------- REUSABLE SUPPORT -------------------
class HoverCard extends StatefulWidget {
  final Widget child;
  const HoverCard({super.key, required this.child});

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hovering = false;
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      transform: _hovering ? (Matrix4.identity()..scale(1.01)) : Matrix4.identity(),
      decoration: BoxDecoration(
        color: _hovering
            ? (isDarkMode ? Colors.blueGrey.shade700 : Colors.teal.shade50)
            : (isDarkMode ? Colors.grey.shade900 : Colors.white),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (_hovering)
            BoxShadow(
              color: isDarkMode ? Colors.black54 : Colors.black26,
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: widget.child,
      ),
    );
  }
}

class BannerPoint extends StatelessWidget {
  final String text;
  final double? fontSize;
  const BannerPoint(this.text, {super.key, this.fontSize});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
              child: Text(text,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize ?? 14,
                      fontWeight: FontWeight.w500,
                      height: 1.4))),
        ],
      ),
    );
  }
}
