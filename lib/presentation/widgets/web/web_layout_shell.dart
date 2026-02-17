import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:interbridge/presentation/resources/color_manager.dart';

/// Modern responsive web layout shell with sidebar navigation
class WebLayoutShell extends StatefulWidget {
  final int currentIndex;
  final Function(int) onNavigationChanged;
  final Widget child;
  final String? userName;
  final String? userRole;
  final String? userAvatar;
  final bool isAdmin;

  const WebLayoutShell({
    super.key,
    required this.currentIndex,
    required this.onNavigationChanged,
    required this.child,
    this.userName,
    this.userRole,
    this.userAvatar,
    this.isAdmin = false,
  });

  @override
  State<WebLayoutShell> createState() => _WebLayoutShellState();
}

class _WebLayoutShellState extends State<WebLayoutShell> {
  bool _isCollapsed = false;
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 1200;
    final isMobile = screenWidth < 768;

    // On mobile, use bottom nav instead
    if (isMobile) {
      return _buildMobileLayout();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // Sidebar
          _buildSidebar(isCompact),
          // Main content
          Expanded(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildMobileAppBar(),
      body: widget.child,
      bottomNavigationBar: _buildMobileBottomNav(),
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0955FA), Color(0xFF6366F1)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.translate, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            'Interbridge',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.notifications_outlined,
            color: Color(0xFF64748B),
          ),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildMobileBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children:
                _getNavItems()
                    .asMap()
                    .entries
                    .map((e) => _buildMobileNavItem(e.key, e.value))
                    .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileNavItem(int index, _NavItem item) {
    final isSelected = widget.currentIndex == index;
    return InkWell(
      onTap: () => widget.onNavigationChanged(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFF0955FA).withValues(alpha: 0.1)
                  : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              color:
                  isSelected
                      ? const Color(0xFF0955FA)
                      : const Color(0xFF94A3B8),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                color:
                    isSelected
                        ? const Color(0xFF0955FA)
                        : const Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(bool isCompact) {
    final collapsed = _isCollapsed || isCompact;
    final sidebarWidth = collapsed ? 80.0 : 280.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: sidebarWidth,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(2, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // Logo section
            _buildLogo(collapsed),
            const SizedBox(height: 8),
            // Navigation items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                children:
                    _getNavItems()
                        .asMap()
                        .entries
                        .map((e) => _buildNavItem(e.key, e.value, collapsed))
                        .toList(),
              ),
            ),
            // User section
            _buildUserSection(collapsed),
            // Collapse button (desktop only)
            if (!isCompact) _buildCollapseButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(bool collapsed) {
    return Container(
      padding: EdgeInsets.all(collapsed ? 16 : 24),
      child: Row(
        mainAxisAlignment:
            collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0955FA), Color(0xFF6366F1)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0955FA).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.translate, color: Colors.white, size: 24),
          ),
          if (!collapsed) ...[
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Interbridge',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Medical Interpretation',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<_NavItem> _getNavItems() {
    return [
      _NavItem(Icons.dashboard_rounded, 'Dashboard', 'Home'),
      _NavItem(Icons.description_outlined, 'Documents', 'Translations'),
      _NavItem(Icons.person_outline_rounded, 'Profile', 'Your profile'),
      _NavItem(Icons.settings_outlined, 'Settings', 'Preferences'),
    ];
  }

  Widget _buildNavItem(int index, _NavItem item, bool collapsed) {
    final isSelected = widget.currentIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => widget.onNavigationChanged(index),
          borderRadius: BorderRadius.circular(12),
          hoverColor: const Color(0xFFF1F5F9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 16 : 16,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? const Color(0xFF0955FA).withValues(alpha: 0.08)
                      : null,
              borderRadius: BorderRadius.circular(12),
              border:
                  isSelected
                      ? Border.all(
                        color: const Color(0xFF0955FA).withValues(alpha: 0.2),
                      )
                      : null,
            ),
            child: Row(
              mainAxisAlignment:
                  collapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? const Color(0xFF0955FA).withValues(alpha: 0.1)
                            : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.icon,
                    size: 20,
                    color:
                        isSelected
                            ? const Color(0xFF0955FA)
                            : const Color(0xFF64748B),
                  ),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color:
                                isSelected
                                    ? const Color(0xFF0955FA)
                                    : const Color(0xFF475569),
                          ),
                        ),
                        Text(
                          item.subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0955FA),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserSection(bool collapsed) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.all(collapsed ? 8 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0955FA).withValues(alpha: 0.05),
            const Color(0xFF6366F1).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF0955FA).withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment:
            collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0955FA), Color(0xFF6366F1)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                widget.userAvatar != null
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        widget.userAvatar!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              (widget.userName ?? 'U')[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                    : Center(
                      child: Text(
                        (widget.userName ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
          ),
          if (!collapsed) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userName ?? 'User',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _capitalizeRole(widget.userRole ?? 'user'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.logout_rounded,
                size: 18,
                color: Color(0xFF64748B),
              ),
              onPressed: () {
                // Handle logout
              },
              tooltip: 'Logout',
            ),
          ],
        ],
      ),
    );
  }

  String _capitalizeRole(String role) {
    if (role.isEmpty) return role;
    return role[0].toUpperCase() + role.substring(1);
  }

  Widget _buildCollapseButton() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _isCollapsed = !_isCollapsed),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _isCollapsed ? Icons.chevron_right : Icons.chevron_left,
              size: 20,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          // Search bar
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: const Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0955FA)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Notifications
          _buildHeaderButton(
            Icons.notifications_outlined,
            badge: 3,
            onTap: () {},
          ),
          const SizedBox(width: 12),
          // Help
          _buildHeaderButton(Icons.help_outline_rounded, onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildHeaderButton(IconData icon, {int? badge, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, color: const Color(0xFF64748B), size: 22),
              if (badge != null && badge > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badge > 9 ? '9+' : badge.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String subtitle;

  _NavItem(this.icon, this.label, this.subtitle);
}
