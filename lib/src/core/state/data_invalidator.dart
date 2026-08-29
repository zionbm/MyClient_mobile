import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DataScope { crm, calls, ai, settings }

class DataInvalidator extends ChangeNotifier {
  final Map<DataScope, int> _revisions = {
    for (final scope in DataScope.values) scope: 0,
  };

  int revision(DataScope scope) => _revisions[scope]!;

  void invalidate(Set<DataScope> scopes) {
    for (final scope in scopes) {
      _revisions[scope] = _revisions[scope]! + 1;
    }
    notifyListeners();
  }
}

final dataInvalidatorProvider = ChangeNotifierProvider<DataInvalidator>(
  (ref) => DataInvalidator(),
);
