import 'package:equatable/equatable.dart';

/// Base class for all organization dashboard events
abstract class OrganizationDashboardEvent extends Equatable {
  const OrganizationDashboardEvent();

  @override
  List<Object?> get props => [];
}

/// Load all organization dashboard data
class LoadOrganizationData extends OrganizationDashboardEvent {
  const LoadOrganizationData();
}

/// Refresh data from the server
class RefreshOrganizationData extends OrganizationDashboardEvent {
  const RefreshOrganizationData();
}

/// Send an invitation to a doctor
class SendDoctorInvitation extends OrganizationDashboardEvent {
  final String email;
  const SendDoctorInvitation(this.email);

  @override
  List<Object?> get props => [email];
}

/// Cancel a pending invitation
class CancelInvitation extends OrganizationDashboardEvent {
  final String inviteId;
  const CancelInvitation(this.inviteId);

  @override
  List<Object?> get props => [inviteId];
}

/// Process a top-up to the organization wallet
class ProcessTopUp extends OrganizationDashboardEvent {
  final double amount;
  const ProcessTopUp(this.amount);

  @override
  List<Object?> get props => [amount];
}

/// Update member status (activate/deactivate)
class UpdateMemberStatus extends OrganizationDashboardEvent {
  final String memberId;
  final bool isActive;
  const UpdateMemberStatus(this.memberId, this.isActive);

  @override
  List<Object?> get props => [memberId, isActive];
}

/// Load invoices for the organization
class LoadInvoices extends OrganizationDashboardEvent {
  const LoadInvoices();
}

/// Generate a monthly invoice
class GenerateInvoice extends OrganizationDashboardEvent {
  final int year;
  final int month;
  final bool sendEmail;
  const GenerateInvoice({
    required this.year,
    required this.month,
    this.sendEmail = false,
  });

  @override
  List<Object?> get props => [year, month, sendEmail];
}

/// Open Stripe Checkout for wallet top-up
class OpenStripeCheckout extends OrganizationDashboardEvent {
  final double amount;
  const OpenStripeCheckout(this.amount);

  @override
  List<Object?> get props => [amount];
}

/// Open Stripe native Payment Sheet on mobile
class OpenMobilePaymentSheet extends OrganizationDashboardEvent {
  final double amount;
  const OpenMobilePaymentSheet(this.amount);

  @override
  List<Object?> get props => [amount];
}

/// Clear the checkout URL after it has been consumed by the UI
class ClearCheckoutUrl extends OrganizationDashboardEvent {
  const ClearCheckoutUrl();
}

/// Clear payment sheet data after it has been consumed by the UI
class ClearPaymentSheetData extends OrganizationDashboardEvent {
  const ClearPaymentSheetData();
}

/// Payment completed successfully (mobile Payment Sheet)
class PaymentSheetCompleted extends OrganizationDashboardEvent {
  final double amount;
  const PaymentSheetCompleted(this.amount);

  @override
  List<Object?> get props => [amount];
}

/// Clear payment success amount after showing the success dialog
class ClearPaymentSuccess extends OrganizationDashboardEvent {
  const ClearPaymentSuccess();
}
