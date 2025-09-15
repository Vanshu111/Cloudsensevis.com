import 'package:flutter/material.dart';

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 800;

    return Container(
      color: isDarkMode ? const Color.fromARGB(255, 18, 33, 41) : Colors.white,
      padding: EdgeInsets.symmetric(
        vertical: isWideScreen ? 16 : 12, // Reduced from 32/24 to 16/12
        horizontal: isWideScreen ? 84 : 16,
      ),
      child: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Contact Us',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isWideScreen ? 22 : 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.teal.shade800,
              ),
            ),
            const SizedBox(height: 8), // Reduced from 16 to 8
            _buildContactItem(
              icon: Icons.location_on,
              text: 'IIT Ropar',
              isDarkMode: isDarkMode,
              isWideScreen: isWideScreen,
            ),
            const SizedBox(height: 6), // Reduced from 12 to 6
            _buildContactItem(
              icon: Icons.email,
              text: 'iot.aihub@gmail.com',
              isDarkMode: isDarkMode,
              isWideScreen: isWideScreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String text,
    required bool isDarkMode,
    required bool isWideScreen,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: isDarkMode ? Colors.tealAccent : Colors.teal,
          size: isWideScreen ? 24 : 20,
        ),
        const SizedBox(width: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isWideScreen ? 16 : 14,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }
}
