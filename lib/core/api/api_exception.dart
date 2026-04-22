/// Exception thrown by [XenoStreamApiClient] on non-2xx HTTP responses
/// or unreachable backend.
class ApiException implements Exception {
  ApiException({required this.message, this.statusCode, this.body});

  final String message;
  final int? statusCode;
  final String? body;

  @override
  String toString() {
    if (statusCode != null) {
      return 'ApiException($statusCode): $message';
    }
    return 'ApiException: $message';
  }
}
