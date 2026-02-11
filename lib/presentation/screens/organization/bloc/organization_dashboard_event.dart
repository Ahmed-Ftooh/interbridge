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
