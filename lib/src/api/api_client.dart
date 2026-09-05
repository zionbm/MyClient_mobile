import '../config/app_config.dart';
import '../core/network/api_transport.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/business_repository.dart';
import '../data/repositories/calls_repository.dart';
import '../data/repositories/notifications_repository.dart';
import '../data/repositories/voice_repository.dart';
import '../data/repositories/v2_customer_repository.dart';
import '../data/repositories/v2_task_repository.dart';
import '../data/repositories/v2_assistant_repository.dart';
import '../data/repositories/v2_activity_repository.dart';
import '../data/repositories/v2_search_repository.dart';
import '../data/repositories/v2_amount_repository.dart';
import '../data/repositories/v2_action_batches_repository.dart';

export '../core/network/api_exception.dart';

/// Application-level composition root for Core API repositories.
class ApiClient {
  ApiClient({required AppConfig config, ApiTransport? transport})
    : _transport = transport ?? ApiTransport(config: config) {
    auth = AuthRepository(_transport);
    business = BusinessRepository(_transport);
    calls = CallsRepository(_transport);
    notifications = NotificationsRepository(_transport);
    voice = VoiceRepository(_transport);
    v2Customers = V2CustomerRepository(_transport);
    v2Tasks = V2TaskRepository(_transport);
    v2Assistant = V2AssistantRepository(_transport);
    v2Activities = V2ActivityRepository(_transport);
    v2Search = V2SearchRepository(_transport);
    v2Amounts = V2AmountRepository(_transport);
    v2ActionBatches = V2ActionBatchesRepository(_transport);
  }

  final ApiTransport _transport;
  late final AuthRepository auth;
  late final BusinessRepository business;
  late final CallsRepository calls;
  late final NotificationsRepository notifications;
  late final VoiceRepository voice;
  late final V2CustomerRepository v2Customers;
  late final V2TaskRepository v2Tasks;
  late final V2AssistantRepository v2Assistant;
  late final V2ActivityRepository v2Activities;
  late final V2SearchRepository v2Search;
  late final V2AmountRepository v2Amounts;
  late final V2ActionBatchesRepository v2ActionBatches;

  bool get isMockAuth => _transport.isMockAuth;

  void close() => _transport.close();
}
