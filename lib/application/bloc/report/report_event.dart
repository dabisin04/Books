import 'package:equatable/equatable.dart';
import '../../../domain/entities/interaction/report.dart';
import '../../../domain/entities/interaction/strikes.dart';
import '../../../domain/entities/interaction/alerts.dart';

abstract class ReportEvent extends Equatable {
  const ReportEvent();

  @override
  List<Object?> get props => [];
}

class SubmitReport extends ReportEvent {
  final Report report;

  const SubmitReport(this.report);

  @override
  List<Object?> get props => [report];
}

class LoadPendingReports extends ReportEvent {}

class LoadReportsByTarget extends ReportEvent {
  final String targetId;

  const LoadReportsByTarget(this.targetId);

  @override
  List<Object?> get props => [targetId];
}

class UpdateReportStatus extends ReportEvent {
  final String reportId;
  final String status;
  final String? adminId;

  const UpdateReportStatus({
    required this.reportId,
    required this.status,
    this.adminId,
  });

  @override
  List<Object?> get props => [reportId, status, adminId];
}

class AddStrike extends ReportEvent {
  final Strike strike;

  const AddStrike(this.strike);

  @override
  List<Object?> get props => [strike];
}

class LoadUserStrikes extends ReportEvent {
  final String userId;

  const LoadUserStrikes(this.userId);

  @override
  List<Object?> get props => [userId];
}

class AddAlert extends ReportEvent {
  final Alert alert;

  const AddAlert(this.alert);

  @override
  List<Object?> get props => [alert];
}

class LoadBookAlerts extends ReportEvent {
  final String bookId;

  const LoadBookAlerts(this.bookId);

  @override
  List<Object?> get props => [bookId];
}

class ResolveAlert extends ReportEvent {
  final String alertId;
  final String status;

  const ResolveAlert({
    required this.alertId,
    required this.status,
  });

  @override
  List<Object?> get props => [alertId, status];
}
