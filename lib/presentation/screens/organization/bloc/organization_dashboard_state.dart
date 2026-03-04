import 'package:equatable/equatable.dart';

/// Base class for all organization dashboard states
abstract class OrganizationDashboardState extends Equatable {
  const OrganizationDashboardState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any data is loaded
class OrganizationDashboardInitial extends OrganizationDashboardState {}

/// Loading state while fetching data
class OrganizationDashboardLoading extends OrganizationDashboardState {}

/// Main state when data is loaded
class OrganizationDashboardLoaded extends OrganizationDashboardState {
  final Map<String, dynamic> organization;
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> pendingInvites;
  final List<Map<String, dynamic>> callHistory;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> invoices;

  // UI state flags
  final bool isSendingInvite;
  final bool isCancellingInvite;
  final bool isProcessingTopUp;
  final bool isGeneratingInvoice;
  final String? checkoutUrl;
  final Map<String, String>? paymentSheetData;
  final double? paymentSuccessAmount;
  final String? message;
  final bool isError;

  const OrganizationDashboardLoaded({
    required this.organization,
    this.members = const [],
    this.pendingInvites = const [],
    this.callHistory = const [],
    this.transactions = const [],
    this.invoices = const [],
    this.isSendingInvite = false,
    this.isCancellingInvite = false,
    this.isProcessingTopUp = false,
    this.isGeneratingInvoice = false,
    this.checkoutUrl,
    this.paymentSheetData,
    this.paymentSuccessAmount,
    this.message,
    this.isError = false,
  });

  /// Get the wallet balance
  double get walletBalance =>
      (organization['wallet_balance'] as num?)?.toDouble() ?? 0.0;

  /// Get the rate per minute
  double get ratePerMinute =>
      (organization['rate_per_minute'] as num?)?.toDouble() ?? 1.0;

  /// Get the invite code
  String get inviteCode => organization['invite_code'] as String? ?? '';

  /// Get the organization name
  String get organizationName =>
      organization['name'] as String? ?? 'Organization';

  /// Get the organization ID
  String get organizationId => organization['id'] as String? ?? '';

  /// Get the number of calls this month
  int get thisMonthCalls {
    final now = DateTime.now();
    return callHistory.where((call) {
      final startedAt = DateTime.tryParse(call['started_at'] ?? '');
      if (startedAt == null) return false;
      return startedAt.month == now.month && startedAt.year == now.year;
    }).length;
  }

  @override
  List<Object?> get props => [
    organization,
    members,
    pendingInvites,
    callHistory,
    transactions,
    invoices,
    isSendingInvite,
    isCancellingInvite,
    isProcessingTopUp,
    isGeneratingInvoice,
    checkoutUrl,
    paymentSheetData,
    paymentSuccessAmount,
    message,
    isError,
  ];

  OrganizationDashboardLoaded copyWith({
    Map<String, dynamic>? organization,
    List<Map<String, dynamic>>? members,
    List<Map<String, dynamic>>? pendingInvites,
    List<Map<String, dynamic>>? callHistory,
    List<Map<String, dynamic>>? transactions,
    List<Map<String, dynamic>>? invoices,
    bool? isSendingInvite,
    bool? isCancellingInvite,
    bool? isProcessingTopUp,
    bool? isGeneratingInvoice,
    String? checkoutUrl,
    Map<String, String>? paymentSheetData,
    double? paymentSuccessAmount,
    String? message,
    bool? isError,
  }) {
    return OrganizationDashboardLoaded(
      organization: organization ?? this.organization,
      members: members ?? this.members,
      pendingInvites: pendingInvites ?? this.pendingInvites,
      callHistory: callHistory ?? this.callHistory,
      transactions: transactions ?? this.transactions,
      invoices: invoices ?? this.invoices,
      isSendingInvite: isSendingInvite ?? this.isSendingInvite,
      isCancellingInvite: isCancellingInvite ?? this.isCancellingInvite,
      isProcessingTopUp: isProcessingTopUp ?? this.isProcessingTopUp,
      isGeneratingInvoice: isGeneratingInvoice ?? this.isGeneratingInvoice,
      checkoutUrl: checkoutUrl,
      paymentSheetData: paymentSheetData,
      paymentSuccessAmount: paymentSuccessAmount,
      message: message, // Don't use ?? to allow clearing message
      isError: isError ?? false,
    );
  }

  /// Create a copy that clears any message
  OrganizationDashboardLoaded clearMessage() {
    return copyWith(message: null, isError: false);
  }
}

/// State when no organization is found for the user
class OrganizationNotFound extends OrganizationDashboardState {
  final String userId;
  const OrganizationNotFound(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Error state when loading fails
class OrganizationDashboardError extends OrganizationDashboardState {
  final String message;
  const OrganizationDashboardError(this.message);

  @override
  List<Object?> get props => [message];
}
