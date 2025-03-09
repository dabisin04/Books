import '../../entities/interaction/report.dart';

abstract class ReportRepository {
  Future<void> reportContent(Report report);
  Future<List<Report>> getPendingReports();
  Future<void> resolveReport(String reportId, bool approved);
}
