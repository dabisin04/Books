import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/ports/interaction/report_repository.dart';
import 'report_event.dart';
import 'report_state.dart';

class ReportBloc extends Bloc<ReportEvent, ReportState> {
  final ReportRepository _reportRepository;

  ReportBloc(this._reportRepository) : super(ReportInitial()) {
    on<SubmitReport>(_onSubmitReport);
    on<LoadPendingReports>(_onLoadPendingReports);
    on<LoadReportsByTarget>(_onLoadReportsByTarget);
    on<UpdateReportStatus>(_onUpdateReportStatus);
    on<AddStrike>(_onAddStrike);
    on<LoadUserStrikes>(_onLoadUserStrikes);
    on<AddAlert>(_onAddAlert);
    on<LoadBookAlerts>(_onLoadBookAlerts);
    on<ResolveAlert>(_onResolveAlert);
  }

  Future<void> _onSubmitReport(
    SubmitReport event,
    Emitter<ReportState> emit,
  ) async {
    try {
      emit(ReportLoading());
      await _reportRepository.reportContent(event.report);
      emit(ReportSubmitted(event.report));
    } catch (e) {
      emit(ReportError(e.toString()));
    }
  }

  Future<void> _onLoadPendingReports(
    LoadPendingReports event,
    Emitter<ReportState> emit,
  ) async {
    try {
      emit(ReportLoading());
      final reports = await _reportRepository.getPendingReports();
      emit(ReportsLoaded(reports));
    } catch (e) {
      emit(ReportError(e.toString()));
    }
  }

  Future<void> _onLoadReportsByTarget(
    LoadReportsByTarget event,
    Emitter<ReportState> emit,
  ) async {
    try {
      emit(ReportLoading());
      final reports =
          await _reportRepository.getReportsByTarget(event.targetId);
      emit(ReportsLoaded(reports));
    } catch (e) {
      emit(ReportError(e.toString()));
    }
  }

  Future<void> _onUpdateReportStatus(
    UpdateReportStatus event,
    Emitter<ReportState> emit,
  ) async {
    try {
      emit(ReportLoading());
      await _reportRepository.updateReportStatus(
        event.reportId,
        event.status,
        event.adminId,
      );
      emit(ReportStatusUpdated(
        reportId: event.reportId,
        status: event.status,
      ));
    } catch (e) {
      emit(ReportError(e.toString()));
    }
  }

  Future<void> _onAddStrike(
    AddStrike event,
    Emitter<ReportState> emit,
  ) async {
    try {
      emit(ReportLoading());
      await _reportRepository.addStrike(event.strike);
      emit(StrikeAdded(event.strike));
    } catch (e) {
      emit(ReportError(e.toString()));
    }
  }

  Future<void> _onLoadUserStrikes(
    LoadUserStrikes event,
    Emitter<ReportState> emit,
  ) async {
    try {
      emit(ReportLoading());
      final strikes = await _reportRepository.getStrikesByUser(event.userId);
      emit(StrikesLoaded(strikes));
    } catch (e) {
      emit(ReportError(e.toString()));
    }
  }

  Future<void> _onAddAlert(
    AddAlert event,
    Emitter<ReportState> emit,
  ) async {
    try {
      emit(ReportLoading());
      await _reportRepository.addAlert(event.alert);
      emit(AlertAdded(event.alert));
    } catch (e) {
      emit(ReportError(e.toString()));
    }
  }

  Future<void> _onLoadBookAlerts(
    LoadBookAlerts event,
    Emitter<ReportState> emit,
  ) async {
    try {
      emit(ReportLoading());
      final alerts = await _reportRepository.getAlertsByBook(event.bookId);
      emit(AlertsLoaded(alerts));
    } catch (e) {
      emit(ReportError(e.toString()));
    }
  }

  Future<void> _onResolveAlert(
    ResolveAlert event,
    Emitter<ReportState> emit,
  ) async {
    try {
      emit(ReportLoading());
      await _reportRepository.resolveAlert(event.alertId, event.status);
      emit(AlertResolved(
        alertId: event.alertId,
        status: event.status,
      ));
    } catch (e) {
      emit(ReportError(e.toString()));
    }
  }
}
