import 'package:cloud_sense_webapp/Datasheet_Download.dart';
import 'package:cloud_sense_webapp/drawer.dart';
import 'package:cloud_sense_webapp/footer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_sense_webapp/appbar.dart';

class ProbePage extends StatelessWidget {
  const ProbePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    final isWideScreen = screenWidth > 1024; // Desktop
    final isTablet = screenWidth > 700 && screenWidth <= 1024; // iPad
    final isMobile = screenWidth <= 700; // Mobile

    // Hero section height
    final heroHeight = isWideScreen
        ? 450.0
        : (isTablet ? 400.0 : 350.0); // iPad thoda bada height

    // Responsive font sizes
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
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---------- Hero Section ----------
                if (isWideScreen)
                  _buildHeroDesktop(heroHeight, headlineSize, bannerTextSize,
                      bannerPointSize, context)
                else if (isTablet)
                  _buildHeroTablet(heroHeight, headlineSize, bannerTextSize,
                      bannerPointSize, context)
                else
                  _buildHeroMobile(heroHeight, headlineSize, bannerTextSize,
                      bannerPointSize, context),

                // ---------- Features & Applications ----------
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: (isWideScreen || isTablet)
                      ? _buildIpadLayout(isDarkMode)
                      : Column(
                          children: [
                            _buildFeaturesCard(isDarkMode).animate().fadeIn(),
                            const SizedBox(height: 16),
                            _buildApplicationsCard(isDarkMode)
                                .animate()
                                .fadeIn(),
                          ],
                        ),
                ),

                // ---------- Specs ----------
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isWideScreen ? 1000 : double.infinity,
                      ),
                      child: _buildSpecificationsCard(context, isDarkMode)
                          .animate()
                          .fadeIn()
                          .slideY(begin: 0.2),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const Footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Hero Widgets ----------
  Widget _buildHeroDesktop(
    double heroHeight,
    double headlineSize,
    double bannerTextSize,
    double bannerPointSize,
    BuildContext context,
  ) {
    return Container(
      color:
          const Color.fromARGB(255, 28, 59, 75), // background same as you want
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left side text
          Expanded(
            flex: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: _buildHeroText(
                headlineSize,
                bannerTextSize,
                bannerPointSize,
                context,
              ),
            ),
          ),

          const SizedBox(width: 20),

          // Right side image with height limit ✅
          Expanded(
            flex: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 450, // 👈 PC par max 400px height
              ),
              child: Image.asset(
                "assets/thprobe.png",
                fit: BoxFit.contain,
              ).animate().fadeIn(duration: 600.ms).scale(
                    duration: 800.ms,
                    curve: Curves.easeOutBack,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroTablet(double heroHeight, double headlineSize,
      double bannerTextSize, double bannerPointSize, BuildContext context) {
    return Column(
      children: [
        // Text section with grey background and overlay
        Container(
          width: double.infinity,
          color: Colors.blueGrey.shade600, // text background
          child: Stack(
            children: [
              // Overlay
              Container(
                height: heroHeight * 0.4,
                decoration: BoxDecoration(
                    // gradient: LinearGradient(
                    //   colors: [Colors.black.withOpacity(0.6), Colors.black.withOpacity(0.3)],
                    //   begin: Alignment.topCenter,
                    //   end: Alignment.bottomCenter,
                    // ),
                    ),
              ),

              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // IconButton(
                    //   icon: const Icon(Icons.arrow_back,
                    //       color: Colors.white, size: 22),
                    //   onPressed: () {
                    //     if (Navigator.of(context).canPop()) {
                    //       Navigator.of(context).pop();
                    //     } else {
                    //       Navigator.of(context).pushReplacementNamed("/");
                    //     }
                    //   },
                    // ).animate().fadeIn(duration: 500.ms),
                    const SizedBox(height: 8),
                    _buildHeroText(
                        headlineSize, bannerTextSize, bannerPointSize, context),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Image below text
        Container(
          height: heroHeight * 0.6,
          child: Image.asset(
            "assets/thprobe.png",
            fit: BoxFit.contain,
          ).animate().fadeIn(duration: 600.ms).scale(
                duration: 800.ms,
                curve: Curves.easeOutBack,
              ),
        ),
      ],
    );
  }

  Widget _buildHeroMobile(double heroHeight, double headlineSize,
      double bannerTextSize, double bannerPointSize, BuildContext context) {
    return Column(
      children: [
        // Text section with grey background and overlay
        Container(
          width: double.infinity,
          color: Colors.grey.shade600, // text background
          child: Stack(
            children: [
              // Overlay
              Container(
                height: heroHeight * 0.4,
                decoration: BoxDecoration(
                    // gradient: LinearGradient(
                    //   colors: [Colors.black.withOpacity(0.6), Colors.black.withOpacity(0.3)],
                    //   begin: Alignment.topCenter,
                    //   end: Alignment.bottomCenter,
                    // ),
                    ),
              ),

              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // IconButton(
                    //   icon: const Icon(Icons.arrow_back,
                    //       color: Colors.white, size: 22),
                    //   onPressed: () {
                    //     if (Navigator.of(context).canPop()) {
                    //       Navigator.of(context).pop();
                    //     } else {
                    //       Navigator.of(context).pushReplacementNamed("/");
                    //     }
                    //   },
                    // ).animate().fadeIn(duration: 500.ms),
                    const SizedBox(height: 8),
                    _buildHeroText(
                        headlineSize, bannerTextSize, bannerPointSize, context),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Image below text
        Container(
          height: heroHeight * 0.6,
          child: Image.asset(
            "assets/thprobe.png",
            fit: BoxFit.contain,
          ).animate().fadeIn(duration: 600.ms).scale(
                duration: 800.ms,
                curve: Curves.easeOutBack,
              ),
        ),
      ],
    );
  }

  // ---------- Hero Text ----------
  Widget _buildHeroText(double headlineSize, double bannerTextSize,
      double bannerPointSize, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: "Temperature and Humidity ",
                style: TextStyle(
                    fontSize: headlineSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.lightBlueAccent),
              ),
              TextSpan(
                text: "Probe",
                style: TextStyle(
                    fontSize: headlineSize,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(255, 219, 80, 145)),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 700.ms).slideX(),
        Container(
          margin: const EdgeInsets.only(top: 6, bottom: 16),
          height: 3,
          width: headlineSize * 5.5,
          color: Colors.lightBlueAccent,
        ).animate().scaleX(duration: 800.ms, curve: Curves.easeOut),
        Text(
          "Accurate measurements for temperature and humidity",
          style: TextStyle(
              fontSize: bannerTextSize,
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ).animate().fadeIn(duration: 900.ms),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BannerPoint(
                "Real-time temperature & humidity sensing for critical applications",
                fontSize: bannerPointSize),
            BannerPoint(
                "Provides both analog (0-1000)mV and digital (RS485) output",
                fontSize: bannerPointSize),
            BannerPoint(
                "Reliable Industrial grade monitoring with CRC validated communications",
                fontSize: bannerPointSize),
          ],
        ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
        const SizedBox(height: 20),
        // ---------- Enquire Button ----------
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildBannerButton(
              "Enquire",
              Colors.teal,
              () async {
                final email = "sharmasejal2701@gmail.com";
                final subject = "Product Enquiry";
                final body = "Hello, I am interested in your product.";

                final Uri mailtoUri = Uri(
                  scheme: 'mailto',
                  path: email,
                  query: Uri.encodeFull("subject=$subject&body=$body"),
                );

                if (kIsWeb) {
                  final isMobileBrowser =
                      defaultTargetPlatform == TargetPlatform.iOS ||
                          defaultTargetPlatform == TargetPlatform.android;

                  if (!isMobileBrowser) {
                    final Uri gmailUrl = Uri.parse(
                      "https://mail.google.com/mail/?view=cm&fs=1"
                      "&to=$email"
                      "&su=${Uri.encodeComponent(subject)}"
                      "&body=${Uri.encodeComponent(body)}",
                    );

                    if (await canLaunchUrl(gmailUrl)) {
                      await launchUrl(gmailUrl,
                          mode: LaunchMode.externalApplication);
                      return;
                    }
                  }

                  if (await canLaunchUrl(mailtoUri)) {
                    await launchUrl(mailtoUri,
                        mode: LaunchMode.externalApplication);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Could not open email client")),
                    );
                  }
                } else {
                  if (await canLaunchUrl(mailtoUri)) {
                    await launchUrl(mailtoUri,
                        mode: LaunchMode.externalApplication);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Could not open email app")),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  // ---------- iPad/Desktop Layout for Cards ----------
  Widget _buildIpadLayout(bool isDarkMode) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final featuresCard = _buildFeaturesCard(isDarkMode)
            .animate()
            .slideX(begin: -0.3)
            .fadeIn();
        final applicationsCard = _buildApplicationsCard(isDarkMode)
            .animate()
            .slideX(begin: 0.3)
            .fadeIn();

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: featuresCard),
            const SizedBox(width: 16),
            Expanded(child: applicationsCard),
          ],
        );
      },
    );
  }

  // ---------- Other cards & buttons remain same ----------
  Widget _buildSpecificationsCard(BuildContext context, bool isDarkMode) {
    final List<String> specItems = [
      "Supply Voltage : 5-12 V DC",
      "Range of Temperature : -40 to +60 °C",
      "Range of Humidity : 0-100%",
      "Communications Protocol : RS485 & 0-1V (ADC)",
      "Temperature Accuracy : ±0.1°C",
      "Humidity Accuracy: ±1.0% RH",
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 800;

    return HoverCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: isWideScreen
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Text("Specifications",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.blue.shade800)),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                if (isWideScreen) {
                  final int splitIndex = (specItems.length / 2).ceil();
                  final List<String> leftColumnItems =
                      specItems.sublist(0, splitIndex);
                  final List<String> rightColumnItems =
                      specItems.sublist(splitIndex);

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: leftColumnItems
                              .map((item) => featureItem(item, isDarkMode))
                              .toList(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: rightColumnItems
                              .map((item) => featureItem(item, isDarkMode))
                              .toList(),
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: specItems
                        .map((item) => featureItem(item, isDarkMode))
                        .toList(),
                  );
                }
              },
            ),
            const SizedBox(height: 40),
            Center(
              child: _buildBannerButton("Download Datasheet", Colors.teal, () {
                DownloadManager.downloadFile(
                    context: context,
                    sensorKey: "TempHumidityProbe",
                    fileType: "datasheet");
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesCard(bool isDarkMode) {
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
            featureItem("High precision temperature and humidity sensing probe",
                isDarkMode),
            featureItem(
                "Compact low power design suitable for iot and embedded applications",
                isDarkMode),
            featureItem(
                "Robust RS485/MODBUS RTU communications for industrial use",
                isDarkMode),
            featureItem(
                "CRC validations provide reliable and error free data transfer",
                isDarkMode),
            featureItem(
                "Output provides both analog and digital value", isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationsCard(bool isDarkMode) {
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
            featureItem("Healthcare and Medical Facilities", isDarkMode),
            featureItem("Agriculture and Farming", isDarkMode),
            featureItem("Cold Storage and Warehouse", isDarkMode),
            featureItem("Food and Beverage Industry", isDarkMode),
            featureItem("Transportation and Logistics", isDarkMode),
          ],
        ),
      ),
    );
  }

  static Widget _buildBannerButton(
      String label, Color color, VoidCallback onPressed) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isWideScreen = screenWidth > 800;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              padding: EdgeInsets.symmetric(
                  horizontal: isWideScreen ? 20 : 12,
                  vertical: isWideScreen ? 14 : 10),
              minimumSize: Size(isWideScreen ? 160 : 100, 40),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              elevation: 4,
            ),
            onPressed: onPressed,
            // icon:
            //     const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
            label: Text(label,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: isWideScreen ? 15 : 12,
                    fontWeight: FontWeight.w600)),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
            ..scale(
                begin: const Offset(1, 1),
                end: const Offset(1.05, 1.05),
                duration: 1200.ms,
                curve: Curves.easeInOut),
        );
      },
    );
  }

  Widget featureItem(String text, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle,
              color: isDarkMode ? Colors.tealAccent : Colors.teal, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 15,
                      color: isDarkMode ? Colors.white : Colors.black87))),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }
}

// ---------- HoverCard ----------
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

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        transform:
            _hovering ? (Matrix4.identity()..scale(1.01)) : Matrix4.identity(),
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
        child: widget.child,
      ),
    );
  }
}

// ---------- Banner Point ----------
class BannerPoint extends StatelessWidget {
  final String text;
  final double fontSize;
  const BannerPoint(this.text, {super.key, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
