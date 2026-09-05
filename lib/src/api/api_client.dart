import '../config/app_config.dart';
import '../core/network/api_transport.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/business_repository.dart';
import '../data/repositories/calls_repository.dart';
import '../data/repositories/notifications_repository.dart';
import '../data/repositories/voice_repository.dart';
import '../data/repositories/customer_repository.dart';
import '../data/repositories/task_repository.dart';
import '../data/repositories/assistant_repository.dart';
import '../data/repositories/activity_repository.dart';
import '../data/repositories/search_repository.dart';
import '../data/repositories/amount_repository.dart';
import '../data/repositories/action_batches_repository.dart';

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
    customers = CustomerRepository(_transport);
    tasks = TaskRepository(_transport);
    assistant = AssistantRepository(_transport);
    activities = ActivityRepository(_transport);
    search = SearchRepository(_transport);
    amounts = AmountRepository(_transport);
    actionBatches = ActionBatchesRepository(_transport);
  }

  final ApiTransport _transport;
  late final AuthRepository auth;
  late final BusinessRepository business;
  late final CallsRepository calls;
  late final NotificationsRepository notifications;
  late final VoiceRepository voice;
  late final CustomerRepository customers;
  late final TaskRepository tasks;
  late final AssistantRepository assistant;
  late final ActivityRepository activities;
  late final SearchRepository search;
  late final AmountRepository amounts;
  late final ActionBatchesRepository actionBatches;

  bool get isMockAuth => _transport.isMockAuth;

  void close() => _transport.close();
}
