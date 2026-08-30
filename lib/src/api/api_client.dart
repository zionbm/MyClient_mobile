import '../config/app_config.dart';
import '../core/network/api_transport.dart';
import '../data/repositories/ai_actions_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/business_repository.dart';
import '../data/repositories/calls_repository.dart';
import '../data/repositories/customer_repository.dart';
import '../data/repositories/home_repository.dart';
import '../data/repositories/notes_repository.dart';
import '../data/repositories/notifications_repository.dart';
import '../data/repositories/search_repository.dart';
import '../data/repositories/voice_repository.dart';
import '../data/repositories/work_item_repository.dart';

export '../core/network/api_exception.dart';

/// Application-level composition root for Core API repositories.
class ApiClient {
  ApiClient({required AppConfig config})
    : _transport = ApiTransport(config: config) {
    auth = AuthRepository(_transport);
    business = BusinessRepository(_transport);
    customers = CustomerRepository(_transport);
    notes = NotesRepository(_transport);
    home = HomeRepository(_transport);
    search = SearchRepository(_transport);
    calls = CallsRepository(_transport);
    notifications = NotificationsRepository(_transport);
    aiActions = AiActionsRepository(_transport);
    voice = VoiceRepository(_transport);
    workItems = WorkItemRepository(_transport);
  }

  final ApiTransport _transport;
  late final AuthRepository auth;
  late final BusinessRepository business;
  late final CustomerRepository customers;
  late final NotesRepository notes;
  late final HomeRepository home;
  late final SearchRepository search;
  late final CallsRepository calls;
  late final NotificationsRepository notifications;
  late final AiActionsRepository aiActions;
  late final VoiceRepository voice;
  late final WorkItemRepository workItems;

  bool get isMockAuth => _transport.isMockAuth;

  void close() => _transport.close();
}
