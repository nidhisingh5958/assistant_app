// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:listen_iq/services/router_constants.dart';

class SideMenu extends StatefulWidget {
  const SideMenu({super.key});

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  @override
  void initState() {
    super.initState();
  }

  // Helper method to close drawer and navigate
  void _navigateAndClose(String routeName) {
    // Close the drawer
    Navigator.of(context).pop();

    // Add a small delay to ensure drawer is fully closed
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        context.goNamed(routeName);
      }
    });
  }

  // Helper method to just close drawer without navigation
  void _closeDrawer() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF1A1A1A),
      width: MediaQuery.of(context).size.width * 0.7,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildServicesSection(context),
          const SizedBox(height: 24),
          _buildSettingsSection(context),
          const SizedBox(height: 24),
          _buildSupportSection(context),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Menu",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Choose a service",
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Services"),
        const SizedBox(height: 12),
        _buildMenuItem(
          icon: Icons.videocam,
          label: 'Video',
          color: const Color(0xFFEC4899),
          onTap: () {
            _closeDrawer();
            // Navigate to video service when route is available
            // _navigateAndClose(RouteConstants.videoService);
          },
        ),
        _buildMenuItem(
          icon: Icons.screen_share,
          label: 'Screen Recording',
          color: const Color(0xFF8B5CF6),
          onTap: () {
            _closeDrawer();
            // Navigate to screen recording service when route is available
            // _navigateAndClose(RouteConstants.screenRecording);
          },
        ),
        _buildMenuItem(
          icon: Icons.audiotrack,
          label: 'Audio',
          color: const Color(0xFFF59E0B),
          onTap: () {
            _closeDrawer();
            // Navigate to audio service when route is available
            // _navigateAndClose(RouteConstants.audioService);
          },
        ),
      ],
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Settings"),
        const SizedBox(height: 12),
        _buildMenuItem(
          icon: Icons.settings,
          label: 'Settings & Privacy',
          onTap: () {
            _navigateAndClose(RouteConstants.profileSettings);
          },
        ),
        _buildMenuItem(
          icon: Icons.report_problem,
          label: 'Report a problem',
          onTap: () {
            _closeDrawer();
            // Handle report problem functionality
          },
        ),
      ],
    );
  }

  Widget _buildSupportSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Support"),
        const SizedBox(height: 12),
        _buildMenuItem(
          icon: Icons.help,
          label: 'Help & Support',
          onTap: () {
            _closeDrawer();
            // Navigate to help & support when route is available
            // _navigateAndClose(RouteConstants.helpSupport);
          },
        ),
        _buildMenuItem(
          icon: Icons.language,
          label: 'Language',
          onTap: () {
            _closeDrawer();
            // Handle language selection
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    Color? color,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: color ?? Colors.white.withOpacity(0.8),
                  size: 22,
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
