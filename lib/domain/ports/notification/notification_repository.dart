import '../../entities/notification/notification.dart';

abstract class NotificationRepository {
  Future<void> sendNotification(NotificationModel notification);
  Future<List<NotificationModel>> getUserNotifications(String userId);
  Future<void> markNotificationAsRead(String notificationId);
}
