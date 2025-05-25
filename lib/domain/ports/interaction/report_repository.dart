import '../../entities/interaction/report.dart';
import '../../entities/interaction/strikes.dart';
import '../../entities/interaction/alerts.dart';

abstract class ReportRepository {
  // Reportes
  Future<void> reportContent(Report report);
  Future<List<Report>> getPendingReports();
  Future<List<Report>> getReportsByTarget(String targetId);
  Future<void> updateReportStatus(
      String reportId, String status, String? adminId);

  // Strikes
  Future<void> addStrike(Strike strike);
  Future<List<Strike>> getStrikesByUser(String userId);

  // Alertas
  Future<void> addAlert(Alert alert);
  Future<List<Alert>> getAlertsByBook(String bookId);
  Future<void> resolveAlert(String alertId, String status);
}
