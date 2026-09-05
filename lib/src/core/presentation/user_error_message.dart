import '../network/api_exception.dart';

String userErrorMessage(Object? error) {
  if (error is ApiException) return error.message;
  return 'אירעה שגיאה. אפשר לנסות שוב.';
}
