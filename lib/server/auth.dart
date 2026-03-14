import 'dart:convert';
import 'package:shelf/shelf.dart';

const _publicPaths = {'api/v1/health', 'api/v1/handshake'};

/// Creates middleware that validates API key authentication.
///
/// Checks `Authorization: Bearer <key>` header against the configured key.
/// The /api/v1/health and /api/v1/handshake endpoints are exempt from auth.
Middleware apiKeyAuth(String apiKey) {
  return (Handler innerHandler) {
    return (Request request) {
      // Normalize path: strip trailing slashes for consistent matching
      final path = request.url.path.replaceAll(RegExp(r'/+$'), '');
      if (_publicPaths.contains(path)) {
        return innerHandler(request);
      }

      final authHeader = request.headers['authorization'];
      if (authHeader == null ||
          !authHeader.toLowerCase().startsWith('bearer ')) {
        return Response(401,
            body: jsonEncode(
                {'error': 'Missing or invalid Authorization header'}),
            headers: {'content-type': 'application/json'});
      }

      final token = authHeader.substring(7);
      if (!_constantTimeEquals(token, apiKey)) {
        return Response(403,
            body: jsonEncode({'error': 'Invalid API key'}),
            headers: {'content-type': 'application/json'});
      }

      return innerHandler(request);
    };
  };
}

/// Constant-time string comparison to prevent timing attacks.
bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var result = 0;
  for (var i = 0; i < a.length; i++) {
    result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return result == 0;
}
