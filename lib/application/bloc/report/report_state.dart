import 'package:equatable/equatable.dart';
import '../../../domain/entities/interaction/report.dart';
import '../../../domain/entities/interaction/strikes.dart';
import '../../../domain/entities/interaction/alerts.dart';

abstract class ReportState extends Equatable {
  const ReportState();

  @override
  List<Object?> get props => [];
}

class ReportInitial extends ReportState {}

class ReportLoading extends ReportState {}

class ReportError extends ReportState {
  final String message;

  const ReportError(this.message);

  @override
  List<Object?> get props => [message];
}

class ReportsLoaded extends ReportState {
  final List<Report> reports;

  const ReportsLoaded(this.reports);

  @override
  List<Object?> get props => [reports];
}

class StrikesLoaded extends ReportState {
  final List<Strike> strikes;

  const StrikesLoaded(this.strikes);

  @override
  List<Object?> get props => [strikes];
}

class AlertsLoaded extends ReportState {
  final List<Alert> alerts;

  const AlertsLoaded(this.alerts);

  @override
  List<Object?> get props => [alerts];
}

class ReportSubmitted extends ReportState {
  final Report report;

  const ReportSubmitted(this.report);

  @override
  List<Object?> get props => [report];
}

class StrikeAdded extends ReportState {
  final Strike strike;

  const StrikeAdded(this.strike);

  @override
  List<Object?> get props => [strike];
}

class AlertAdded extends ReportState {
  final Alert alert;

  const AlertAdded(this.alert);

  @override
  List<Object?> get props => [alert];
}

class ReportStatusUpdated extends ReportState {
  final String reportId;
  final String status;

  const ReportStatusUpdated({
    required this.reportId,
    required this.status,
  });

  @override
  List<Object?> get props => [reportId, status];
}

class AlertResolved extends ReportState {
  final String alertId;
  final String status;

  const AlertResolved({
    required this.alertId,
    required this.status,
  });

  @override
  List<Object?> get props => [alertId, status];
}
