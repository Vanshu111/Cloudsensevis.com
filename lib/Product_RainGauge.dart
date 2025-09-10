import 'package:cloud_sense_webapp/appbar.dart';
import 'package:cloud_sense_webapp/Datasheet_Download.dart';
import 'package:cloud_sense_webapp/drawer.dart';
import 'package:cloud_sense_webapp/footer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

class ProductPage extends StatelessWidget {
  const ProductPage({super.key});

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
      color: const Color.fromARGB(
          255, 78, 127, 133), // background same as you want
      padding: const EdgeInsets.symmetric(horizontal: 92, vertical: 24),
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
                "assets/gauge.png",
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
          color: const Color.fromARGB(255, 78, 127, 133),
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
            "assets/gauge.png",
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
          color: const Color.fromARGB(255, 78, 127, 133),
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
            "assets/gauge.png",
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
                text: "Rain ",
                style: TextStyle(
                    fontSize: headlineSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.lightBlueAccent),
              ),
              TextSpan(
                text: "Gauge",
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
          "Tipping Bucket Rain Gauge",
          style: TextStyle(
              fontSize: bannerTextSize,
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ).animate().fadeIn(duration: 900.ms),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BannerPoint("Measure rain via Tipping Bucket Mechanism",
                fontSize: bannerPointSize),
            BannerPoint("Accurate and Low Maintenance",
                fontSize: bannerPointSize),
            BannerPoint("Robust design for all weather conditions",
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

  // ---------- iPad Layout for Card Alignment ----------
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

        // Get the height of both cards
        final featuresKey = GlobalKey();
        final applicationsKey = GlobalKey();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final featuresBox =
              featuresKey.currentContext?.findRenderObject() as RenderBox?;
          final applicationsBox =
              applicationsKey.currentContext?.findRenderObject() as RenderBox?;
          if (featuresBox != null && applicationsBox != null) {
            final featuresHeight = featuresBox.size.height;
            final applicationsHeight = applicationsBox.size.height;
            if (featuresHeight != applicationsHeight) {
              // If heights differ, adjust the smaller card to be centered
              final maxHeight = featuresHeight > applicationsHeight
                  ? featuresHeight
                  : applicationsHeight;
              featuresBox.size = Size(featuresBox.size.width, maxHeight);
              applicationsBox.size =
                  Size(applicationsBox.size.width, maxHeight);
            }
          }
        });

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: SizedBox(
                  key: featuresKey,
                  child: featuresCard,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Center(
                child: SizedBox(
                  key: applicationsKey,
                  child: applicationsCard,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------- Specifications Card ----------
  Widget _buildSpecificationsCard(BuildContext context, isDarkMode) {
    final List<String> specItems = [
      "Made of ABS material, offering durability and weather resistance",
      "Available in two diameter options: 159.5 mm and 200 mm",
      "Collection areas: 200 cm² and 314 cm²",
      "Resolution: 0.2 mm or 0.5 mm depending on the model",
      "Equipped with reed switch or magnetic sensor for tip detection",
      "Data Output: Number of tips × Resolution = Total Rainfall",
    ];
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 800;
    final int splitIndex = (specItems.length / 2).ceil();
    final List<String> leftColumnItems = specItems.sublist(0, splitIndex);
    final List<String> rightColumnItems = specItems.sublist(splitIndex);

    return HoverCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: isWideScreen
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Text(
              "Specifications",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.blue.shade800,
              ),
            ),

            const SizedBox(height: 20),
            // Use a LayoutBuilder to determine screen width and adjust layout
            LayoutBuilder(
              builder: (context, constraints) {
                // final screenWidth = MediaQuery.of(context).size.width;
                // final isWideScreen = screenWidth > 800;

                if (isWideScreen) {
                  // Two-column layout for wide screens
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
                  // Single-column layout for mobile
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
              child: _buildBannerButton(
                "Download Datasheet",
                Colors.teal,
                () {
                  DownloadManager.downloadFile(
                    context: context,
                    sensorKey: "RainGauge",
                    fileType: "datasheet",
                  );
                },
              ),
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
                  color: isDarkMode ? Colors.white : Colors.blue.shade800,
                )),
            const SizedBox(height: 10),
            featureItem(
                "Balanced tipping bucket mechanism ensures high accuracy",
                isDarkMode),
            featureItem(
                "Minimal moving parts → long-term reliability with low maintenance",
                isDarkMode),
            featureItem("Reed switch / magnetic sensor for precise detection",
                isDarkMode),
            featureItem(
                "Accurate even under varying rainfall intensities", isDarkMode),
            featureItem("Durable ABS body with weather resistance", isDarkMode),
            featureItem(
                "Easy integration with data loggers and weather stations for automated rainfall recording",
                isDarkMode),
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
                  color: isDarkMode ? Colors.white : Colors.blue.shade800,
                )),
            const SizedBox(height: 10),
            featureItem(
                "Meteorological stations for rainfall monitoring", isDarkMode),
            featureItem("Agriculture & irrigation planning", isDarkMode),
            featureItem(
                "Environmental monitoring & climate research", isDarkMode),
            featureItem("Suitable for precise/general purpose rain monitoring",
                isDarkMode),
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
                vertical: isWideScreen ? 14 : 10,
              ),
              minimumSize: Size(isWideScreen ? 160 : 100, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              elevation: 4,
            ),
            onPressed: onPressed,
            icon:
                const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
            label: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: isWideScreen ? 15 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
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
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }
}

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

class BannerPoint extends StatelessWidget {
  final String text;
  final double? fontSize;
  const BannerPoint(this.text, {super.key, this.fontSize});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 1024;
    final effectiveFontSize = fontSize ?? (isWideScreen ? 16 : 13);

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
                fontSize: effectiveFontSize,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
