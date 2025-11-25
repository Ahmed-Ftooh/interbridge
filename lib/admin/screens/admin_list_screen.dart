import 'package:flutter/material.dart';
import 'package:interbridge/admin/screens/admin_details_screen.dart';
import 'package:interbridge/admin/services/admin_service.dart';
import 'package:interbridge/data/services/supabase_service.dart';
import 'package:interbridge/app/app_prf.dart';
import 'package:interbridge/app/di.dart';
import 'package:interbridge/presentation/resources/routes_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminListScreen extends StatefulWidget {
  const AdminListScreen({super.key});

  @override
  State<AdminListScreen> createState() => _AdminListScreenState();
}

class _AdminListScreenState extends State<AdminListScreen> {
  final _adminService = AdminService();
  final _supabaseService = SupabaseService();
  final _appPreferences = instance<AppPreferences>();
  final _searchCtrl = TextEditingController();

  List<dynamic> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;

  // Filters
  String _filterStatus = 'all'; // all, verified, unverified
  String _filterAccount = 'all'; // all, active, suspended

  bool _isAdmin = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _verifyAdminAndLoad();
  }

  Future<void> _verifyAdminAndLoad() async {
    try {
      // Retry getting user if null (auth state might be syncing)
      User? user = _supabaseService.getCurrentUser();
      if (user == null) {
        await Future.delayed(const Duration(seconds: 1));
        user = _supabaseService.getCurrentUser();
      }

      if (user == null) throw Exception('Not authenticated');

      final profile = await _supabaseService.getUserProfile(user.id);
      final isAdmin = profile?.role == 'admin' || profile?.role == 'superadmin';
      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
          _checking = false;
        });
      }
      if (isAdmin) {
        _load(reset: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _checking = false;
          _isAdmin = false;
        });
      }
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_isLoading) return;
    if (reset) {
      setState(() {
        _items = [];
        _offset = 0;
        _hasMore = true;
      });
    }
    if (!_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final newItems = await _adminService.listInterpreters(
        search: _searchCtrl.text.trim(),
        limit: _limit,
        offset: _offset,
        filterStatus: _filterStatus,
        filterAccount: _filterAccount,
      );

      if (mounted) {
        setState(() {
          _items.addAll(newItems);
          _offset += newItems.length;
          if (newItems.length < _limit) {
            _hasMore = false;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading items: $e')));
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Forbidden: Admins only')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => _load(reset: true),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: () async {
              await _supabaseService.signOut();
              await _appPreferences.logout();
              if (context.mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(Routes.loginRoute, (route) => false);
              }
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).primaryColor.withOpacity(0.05),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search interpreters...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _load(reset: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => _load(reset: true),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Search'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterDropdown(
                        value: _filterStatus,
                        items: [
                          {'label': 'All Status', 'value': 'all'},
                          {'label': 'Verified', 'value': 'verified'},
                          {'label': 'Unverified', 'value': 'unverified'},
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _filterStatus = val);
                            _load(reset: true);
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                      _buildFilterDropdown(
                        value: _filterAccount,
                        items: [
                          {'label': 'All Accounts', 'value': 'all'},
                          {'label': 'Active', 'value': 'active'},
                          {'label': 'Suspended', 'value': 'suspended'},
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _filterAccount = val);
                            _load(reset: true);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _items.isEmpty && !_isLoading
                    ? const Center(child: Text('No interpreters found'))
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _items.length) {
                          return _hasMore
                              ? Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Center(
                                  child:
                                      _isLoading
                                          ? const CircularProgressIndicator()
                                          : ElevatedButton(
                                            onPressed: () => _load(),
                                            child: const Text('Load More'),
                                          ),
                                ),
                              )
                              : const SizedBox.shrink();
                        }

                        final item = _items[index] as Map;
                        final userId = item['user_id']?.toString() ?? '';
                        final username =
                            item['username']?.toString() ?? 'Unknown';
                        final email = item['email']?.toString() ?? '';
                        final isVerified = item['is_verified'] == true;

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (_) => AdminDetailsScreen(userId: userId),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor:
                                        isVerified
                                            ? Colors.green.shade100
                                            : Colors.grey.shade200,
                                    child: Text(
                                      username.isNotEmpty
                                          ? username[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color:
                                            isVerified
                                                ? Colors.green.shade800
                                                : Colors.grey.shade800,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              username,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            if (isVerified) ...[
                                              const SizedBox(width: 6),
                                              const Icon(
                                                Icons.verified,
                                                size: 16,
                                                color: Colors.green,
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (email.isNotEmpty)
                                          Text(
                                            email,
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                        Text(
                                          'ID: ${userId.substring(0, 8)}...',
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<Map<String, String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items:
              items.map((item) {
                return DropdownMenuItem(
                  value: item['value'],
                  child: Text(item['label']!),
                );
              }).toList(),
          onChanged: onChanged,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
        ),
      ),
    );
  }
}
