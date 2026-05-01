import 'package:flutter/material.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/presentation/resources/assets_manager.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';

/// Modern responsive web layout shell with sidebar navigation
class WebLayoutShell extends StatefulWidget {
  final int currentIndex;
  final Function(int) onNavigationChanged;
  final Widget child;
  final String? userName;
  final String? userRole;
  final String? userAvatar;
  final bool isAdmin;
  final VoidCallback? onLogout;

  const WebLayoutShell({
    super.key,
    required this.currentIndex,
    required this.onNavigationChanged,
    required this.child,
    this.userName,
    this.userRole,
    this.userAvatar,
    this.isAdmin = false,
    this.onLogout,
  });

  @override
  State<WebLayoutShell> createState() => _WebLayoutShellState();
}

class _WebLayoutShellState extends State<WebLayoutShell> {
  bool _isCollapsed = false;
  bool _isHovering = false;
  final GlobalKey _contentKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 1200;

    if (screenWidth < 900) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: _buildMobileAppBar(),
        drawer: Drawer(
          child: _buildSidebar(false),
        ),
        body: Column(
          children: [
            if (screenWidth >= 768) _buildHeader(),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                child: KeyedSubtree(
                  key: _contentKey,
                  child: widget.child,
                ),
              ),
            ),
          ],
        ),
      );
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
                    child: KeyedSubtree(
                      key: _contentKey,
                      child: widget.child,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                ImageAssets.appIcon,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
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
      actions: const [],
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
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                ImageAssets.appIcon,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
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
                    'Interbridge Platform',
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
    final isInterpreter = widget.userRole == 'interpreter';
    
    return [
      _NavItem(Icons.dashboard_rounded, 'Dashboard', 'Home'),
      _NavItem(Icons.description_outlined, 'Documents', 'Translations'),
      _NavItem(Icons.person_outline_rounded, 'Profile', 'Your profile'),
      if (isInterpreter)
        _NavItem(Icons.workspace_premium_rounded, 'Badges', 'Specializations'),
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
              horizontal: collapsed ? 0 : 16,
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
      margin: EdgeInsets.symmetric(
        horizontal: collapsed ? 8 : 12,
        vertical: 12,
      ),
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
              onPressed:
                  widget.onLogout ??
                  () {
                    _showLogoutDialog(context);
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

  void _showLogoutDialog(BuildContext outerContext) {
    showDialog(
      context: outerContext,
      builder:
          (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Sign Out'),
            content: const Text('Are you sure you want to sign out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Capture navigator before any async work
                  final navigator = Navigator.of(outerContext);
                  Navigator.pop(dialogContext);

                  // Navigate FIRST to prevent disposed BLoCs from reacting
                  navigator.pushNamedAndRemoveUntil(
                    Routes.loginRoute,
                    (route) => false,
                  );

                  // THEN sign out (so auth state change fires on login page)
                  try {
                    final supabaseService = instance<SupabaseService>();
                    final appPreferences = instance<AppPreferences>();
                    await supabaseService.signOut();
                    await appPreferences.logout();
                  } catch (_) {}
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sign Out'),
              ),
            ],
          ),
    );
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
    final navItems = _getNavItems();
    final idx = widget.currentIndex.clamp(0, navItems.length - 1);
    final item = navItems[idx];

    String headerSubtitle = item.subtitle;
    if (item.label == 'Dashboard') headerSubtitle = 'Overview & activity';
    if (item.label == 'Documents') headerSubtitle = 'Translations & uploads';
    if (item.label == 'Profile') headerSubtitle = 'Your information';
    if (item.label == 'Settings') headerSubtitle = 'Preferences';
    if (item.label == 'Badges') headerSubtitle = 'Medical specializations';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                headerSubtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
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
