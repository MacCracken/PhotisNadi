import 'dart:convert';
import 'package:shelf/shelf.dart';

/// Creates middleware that validates API key authentication.
///
/// Checks `Authorization: Bearer <key>` header against the configured key.
/// The /api/v1/health endpoint is exempt from auth.
Middleware apiKeyAuth(String apiKey) {
  return (Handler innerHandler) {
    return (Request request) {
      // Health check and handshake are public
      if (request.url.path == 'api/v1/health' ||
          request.url.path == 'api/v1/handshake') {
        return innerHandler(request);
      }

      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response(401,
            body: jsonEncode(
                {'error': 'Missing or invalid Authorization header'}),
            headers: {'content-type': 'application/json'});
      }

      final token = authHeader.substring(7);
      if (token != apiKey) {
        return Response(403,
            body: jsonEncode({'error': 'Invalid API key'}),
            headers: {'content-type': 'application/json'});
      }

      return innerHandler(request);
    };
  };
}
