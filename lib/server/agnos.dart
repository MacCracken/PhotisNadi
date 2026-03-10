import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// AGNOS daimon integration for the Photis Nadi API server.
///
/// Handles:
/// - Agent registration & heartbeats with daimon agent runtime
/// - MCP tool registration with daimon's MCP server
/// - Audit event forwarding to AGNOS audit chain
class AgnosIntegration {
  final http.Client _httpClient;
  final String? _agentRegistryUrl;
  final String? _auditUrl;
  final String _apiUrl;
  final String _apiKey;
  Timer? _heartbeatTimer;
  String? _agentId;

  AgnosIntegration({
    required String apiUrl,
    required String apiKey,
    String? agentRegistryUrl,
    String? auditUrl,
    http.Client? httpClient,
  })  : _apiUrl = apiUrl,
        _apiKey = apiKey,
        _agentRegistryUrl = agentRegistryUrl,
        _auditUrl = auditUrl,
        _httpClient = httpClient ?? http.Client();

  bool get isAgentRegistryEnabled => _agentRegistryUrl != null;
  bool get isAuditEnabled => _auditUrl != null;
  bool get isRegistered => _agentId != null;

  // ── Agent Registration ──

  /// Register this server as an agent with daimon's agent runtime.
  /// Starts heartbeat timer on success.
  Future<bool> registerAgent() async {
    if (_agentRegistryUrl == null) return false;

    try {
      final response = await _httpClient
          .post(
            Uri.parse('$_agentRegistryUrl/v1/agents/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': 'photisnadi',
              'display_name': 'Photis Nadi',
              'description':
                  'Task management and ritual tracking productivity app',
              'version': '2026.2.16',
              'endpoint': _apiUrl,
              'health_endpoint': '$_apiUrl/api/v1/health',
              'capabilities': [
                'tasks',
                'projects',
                'rituals',
                'analytics',
              ],
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 300) {
        final data = jsonDecode(response.body);
        _agentId = data['agent_id'] as String? ?? data['id'] as String?;
        stdout.writeln('Registered with AGNOS daimon as agent $_agentId');
        _startHeartbeat();
        return true;
      } else {
        stderr.writeln(
            'AGNOS agent registration failed: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      stderr.writeln('AGNOS agent registration error: $e');
      return false;
    }
  }

  /// Deregister this agent from daimon on shutdown.
  Future<void> deregisterAgent() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    if (_agentRegistryUrl == null || _agentId == null) return;

    try {
      await _httpClient
          .delete(
            Uri.parse('$_agentRegistryUrl/v1/agents/$_agentId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));
      stdout.writeln('Deregistered from AGNOS daimon');
    } catch (e) {
      stderr.writeln('AGNOS agent deregistration error: $e');
    }
    _agentId = null;
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _sendHeartbeat(),
    );
  }

  Future<void> _sendHeartbeat() async {
    if (_agentRegistryUrl == null || _agentId == null) return;

    try {
      final response = await _httpClient
          .post(
            Uri.parse('$_agentRegistryUrl/v1/agents/$_agentId/heartbeat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'status': 'healthy',
              'timestamp': DateTime.now().toUtc().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode >= 400) {
        stderr.writeln('AGNOS heartbeat failed: ${response.statusCode}');
        // Re-register if agent was dropped
        if (response.statusCode == 404) {
          _agentId = null;
          await registerAgent();
        }
      }
    } catch (e) {
      stderr.writeln('AGNOS heartbeat error: $e');
    }
  }

  // ── MCP Tool Registration ──

  /// Register the 6 Photis Nadi MCP tools with daimon's MCP server.
  Future<bool> registerMcpTools() async {
    if (_agentRegistryUrl == null) return false;

    try {
      final tools = [
        {
          'name': 'photis_list_tasks',
          'description':
              'List tasks from Photis Nadi with optional filters for project, status, and priority.',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'project_id': {
                'type': 'string',
                'description': 'Filter by project ID'
              },
              'status': {
                'type': 'string',
                'enum': ['todo', 'inProgress', 'inReview', 'blocked', 'done'],
                'description': 'Filter by task status'
              },
              'priority': {
                'type': 'string',
                'enum': ['low', 'medium', 'high'],
                'description': 'Filter by priority'
              },
              'limit': {
                'type': 'number',
                'description': 'Max results (default 50)'
              },
            },
          },
        },
        {
          'name': 'photis_create_task',
          'description': 'Create a new task in Photis Nadi.',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'title': {'type': 'string', 'description': 'Task title'},
              'description': {
                'type': 'string',
                'description': 'Task description'
              },
              'project_id': {'type': 'string', 'description': 'Project ID'},
              'priority': {
                'type': 'string',
                'enum': ['low', 'medium', 'high']
              },
              'status': {
                'type': 'string',
                'enum': ['todo', 'inProgress', 'inReview', 'blocked', 'done']
              },
              'due_date': {'type': 'string', 'format': 'date-time'},
              'tags': {
                'type': 'array',
                'items': {'type': 'string'}
              },
            },
            'required': ['title'],
          },
        },
        {
          'name': 'photis_update_task',
          'description': 'Update an existing task in Photis Nadi.',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'task_id': {
                'type': 'string',
                'description': 'Task ID to update'
              },
              'title': {'type': 'string'},
              'description': {'type': 'string'},
              'status': {
                'type': 'string',
                'enum': ['todo', 'inProgress', 'inReview', 'blocked', 'done']
              },
              'priority': {
                'type': 'string',
                'enum': ['low', 'medium', 'high']
              },
              'due_date': {'type': 'string', 'format': 'date-time'},
              'tags': {
                'type': 'array',
                'items': {'type': 'string'}
              },
            },
            'required': ['task_id'],
          },
        },
        {
          'name': 'photis_list_projects',
          'description': 'List projects from Photis Nadi.',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'include_archived': {
                'type': 'boolean',
                'description': 'Include archived projects'
              },
            },
          },
        },
        {
          'name': 'photis_list_rituals',
          'description':
              'List rituals with completion status and streak data from Photis Nadi.',
          'inputSchema': {
            'type': 'object',
            'properties': {
              'frequency': {
                'type': 'string',
                'enum': ['daily', 'weekly', 'monthly'],
                'description': 'Filter by frequency'
              },
            },
          },
        },
        {
          'name': 'photis_task_analytics',
          'description':
              'Get task analytics and productivity insights from Photis Nadi.',
          'inputSchema': {
            'type': 'object',
            'properties': {},
          },
        },
      ];

      final response = await _httpClient
          .post(
            Uri.parse('$_agentRegistryUrl/v1/mcp/tools'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'agent_id': _agentId,
              'server_name': 'Photis Nadi',
              'transport': 'streamable-http',
              'endpoint': _apiUrl,
              'auth': {
                'type': 'bearer',
                'token': _apiKey,
              },
              'tools': tools,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 300) {
        stdout.writeln(
            'Registered ${tools.length} MCP tools with AGNOS daimon');
        return true;
      } else {
        stderr.writeln(
            'AGNOS MCP tool registration failed: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      stderr.writeln('AGNOS MCP tool registration error: $e');
      return false;
    }
  }

  // ── Audit Event Forwarding ──

  /// Forward a task CRUD event to the AGNOS audit chain.
  /// Fire-and-forget — errors are logged but don't block the caller.
  Future<void> forwardAuditEvent({
    required String action,
    required String entityType,
    required String entityId,
    Map<String, dynamic>? payload,
  }) async {
    if (_auditUrl == null) return;

    try {
      await _httpClient
          .post(
            Uri.parse('$_auditUrl/v1/audit/forward'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'source': 'photisnadi',
              'action': action,
              'entity_type': entityType,
              'entity_id': entityId,
              'timestamp': DateTime.now().toUtc().toIso8601String(),
              if (payload != null) 'payload': payload,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      stderr.writeln('AGNOS audit forward error ($action $entityType): $e');
    }
  }

  /// Clean shutdown: deregister agent and cancel timers.
  Future<void> shutdown() async {
    await deregisterAgent();
    _httpClient.close();
  }
}
