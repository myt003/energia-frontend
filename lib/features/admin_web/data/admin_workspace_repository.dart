import 'dart:convert';
import 'dart:typed_data';

import '../../../core/api/energia_api_client.dart';

/// A single page of an administrator resource endpoint.
class AdminResourcePage {
  const AdminResourcePage({
    required this.count,
    required this.page,
    required this.pageSize,
    required this.results,
    this.next,
    this.previous,
  });

  final int count;
  final int page;
  final int pageSize;
  final List<Map<String, Object?>> results;
  final String? next;
  final String? previous;

  bool get isEmpty => results.isEmpty;
}

/// Parsed answer from the retrieval-augmented knowledge endpoint.
class AdminRagAnswer {
  const AdminRagAnswer({
    required this.answer,
    required this.grounded,
    required this.citations,
    this.model,
  });

  final String answer;
  final bool grounded;
  final List<Map<String, Object?>> citations;
  final String? model;
}

/// Dry-run result for a custom rule.
class AdminRulePreview {
  const AdminRulePreview({
    required this.matches,
    required this.staffInScope,
    required this.estimatedTasksPerDay,
    required this.warnings,
    required this.definition,
  });

  final int matches;
  final int staffInScope;
  final int estimatedTasksPerDay;
  final List<String> warnings;
  final Map<String, Object?> definition;
}

/// Consumption series returned by the charts endpoint.
class AdminChartSeries {
  const AdminChartSeries({
    required this.points,
    required this.total,
    required this.totalCost,
    required this.baselineAvailable,
  });

  final List<Map<String, Object?>> points;
  final num total;
  final num totalCost;
  final bool baselineAvailable;
}

/// Site / department / meter flow returned by the energy flow endpoint.
class AdminEnergyFlow {
  const AdminEnergyFlow({
    required this.nodes,
    required this.links,
    required this.unit,
    required this.sampleCount,
  });

  final List<Map<String, Object?>> nodes;
  final List<Map<String, Object?>> links;
  final String unit;
  final int sampleCount;
}

/// Staff task / score / evidence drill-down.
class AdminStaffHistory {
  const AdminStaffHistory({
    required this.userId,
    required this.tasks,
    required this.scores,
    required this.evidence,
  });

  final int userId;
  final List<Map<String, Object?>> tasks;
  final List<Map<String, Object?>> scores;
  final List<Map<String, Object?>> evidence;
}

/// Thin, typed workspace layer over [EnergiaApiClient].
///
/// All paths are relative to the client base URL (which already ends in
/// `/api/v1`) and all collection payloads are normalised to string-keyed maps
/// so presentation code does not have to deal with `int` JSON object keys.
class AdminWorkspaceRepository {
  AdminWorkspaceRepository(this._client);

  final EnergiaApiClient _client;

  List<Map<String, Object?>> _asMapList(Object? value) {
    if (value is! List) return const <Map<String, Object?>>[];
    final result = <Map<String, Object?>>[];
    for (final item in value) {
      if (item is Map) result.add(_asMap(item));
    }
    return result;
  }

  Map<String, Object?> _asMap(Object? value) {
    if (value is! Map) return const <String, Object?>{};
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      result[entry.key.toString()] = entry.value;
    }
    return result;
  }

  int _integer(Object? value, {int fallback = 0}) {
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? num.tryParse(value)?.round() ?? fallback;
    return fallback;
  }

  num _number(Object? value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }

  bool _bool(Object? value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    if (value is num) return value != 0;
    return false;
  }

  String _path(String path, [Map<String, Object?> query = const {}]) {
    if (query.isEmpty) return path;
    return Uri.parse(path)
        .replace(
          queryParameters: query.map(
            (key, value) => MapEntry(key, value?.toString() ?? ''),
          ),
        )
        .toString();
  }

  Future<AdminResourcePage> resourcePage(
    String resource, {
    int page = 1,
    int pageSize = 200,
    Map<String, Object?> filters = const {},
  }) async {
    final payload = await _client.getJson(
      _path('admin/resources/$resource/', {
        'page': page,
        'page_size': pageSize,
        ...filters,
      }),
    );
    return AdminResourcePage(
      count: _integer(payload['count']),
      page: _integer(payload['page'], fallback: page),
      pageSize: _integer(payload['page_size'], fallback: pageSize),
      results: _asMapList(payload['results']),
      next: payload['next']?.toString(),
      previous: payload['previous']?.toString(),
    );
  }

  Future<List<Map<String, Object?>>> resource(
    String resource, {
    Map<String, Object?> filters = const {},
  }) async {
    final page = await resourcePage(
      resource,
      filters: filters,
    );
    return page.results;
  }

  Future<Map<String, Object?>> createResource(
    String resource,
    Map<String, Object?> body,
  ) async {
    return _asMap(await _client.postJson('admin/resources/$resource/', body));
  }

  Future<Map<String, Object?>> updateResource(
    String resource,
    Object id,
    Map<String, Object?> body,
  ) async {
    return _asMap(
      await _client.patchJson('admin/resources/$resource/$id/', body),
    );
  }

  Future<AdminRagAnswer> ragAnswer(String query) async {
    final payload = await _client.postJson('admin/rag/query/', {
      'query': query,
      'use_model': false,
    });
    final citations = _asMapList(payload['citations']).map((citation) {
      return <String, Object?>{
        ...citation,
        if (citation['citation'] is Map)
          'citation': _asMap(citation['citation']),
      };
    }).toList();
    return AdminRagAnswer(
      answer: payload['answer']?.toString() ?? '',
      grounded: _bool(payload['grounded']),
      citations: citations,
      model: payload['model']?.toString(),
    );
  }

  Future<Map<String, Object?>> ingestDocument({
    required List<int> bytes,
    required String filename,
    String? title,
    String? source,
    String? version,
  }) async {
    final fields = <String, String>{
      if (title != null && title.isNotEmpty) 'title': title,
      if (source != null && source.isNotEmpty) 'source': source,
      if (version != null && version.isNotEmpty) 'version': version,
    };
    return _asMap(
      await _client.postMultipartBytes(
        'admin/knowledge/ingest/',
        fields: fields,
        fileField: 'file',
        files: [
          ApiUploadFile(bytes: Uint8List.fromList(bytes), filename: filename),
        ],
      ),
    );
  }

  Future<AdminRulePreview> previewRule(Object ruleId) async {
    final payload = await _client.postJson('admin/rules/preview/', {
      'rule_id': ruleId,
    });
    return AdminRulePreview(
      matches: _integer(payload['matches']),
      staffInScope: _integer(payload['staff_in_scope']),
      estimatedTasksPerDay: _integer(payload['estimated_tasks_per_day']),
      warnings: (payload['warnings'] is List)
          ? (payload['warnings'] as List)
              .map((item) => item?.toString() ?? '')
              .where((item) => item.isNotEmpty)
              .toList()
          : const <String>[],
      definition: _asMap(payload['definition']),
    );
  }

  Future<Map<String, Object?>> publishRule(Object ruleId) async {
    return _asMap(
      await _client.postJson('admin/rules/$ruleId/publish/', const {}),
    );
  }

  Future<AdminChartSeries> chartSeries({
    int days = 365,
    String group = 'month',
  }) async {
    final payload = await _client.getJson(
      _path('admin/charts/series/', {'days': days, 'group': group}),
    );
    return AdminChartSeries(
      points: _asMapList(payload['series']),
      total: _number(payload['total']),
      totalCost: _number(payload['total_cost']),
      baselineAvailable: _bool(payload['baseline_available']),
    );
  }

  Future<AdminEnergyFlow> energyFlow({int days = 365}) async {
    final payload = await _client.getJson(
      _path('admin/energy/flow/', {'days': days}),
    );
    return AdminEnergyFlow(
      nodes: _asMapList(payload['nodes']),
      links: _asMapList(payload['links']),
      unit: payload['unit']?.toString() ?? '',
      sampleCount: _integer(payload['sample_count']),
    );
  }

  Future<List<Map<String, Object?>>> healthScores() async {
    return _asMapList(await _client.getJsonList('admin/health/departments/'));
  }

  Future<List<Map<String, Object?>>> maintenanceDue() async {
    return _asMapList(await _client.getJsonList('admin/maintenance/due/'));
  }

  Future<int> refreshWeather() async {
    final payload = await _client.postJson('admin/weather/refresh/', const {});
    return _integer(payload['forecasts_created']);
  }

  Future<Map<String, Object?>> generateReport(
    String from,
    String to, {
    String export = 'json',
  }) async {
    return _asMap(
      await _client.getJson(
        _path('admin/reports/generate/', {
          'export': export,
          'from': from,
          'to': to,
        }),
      ),
    );
  }

  Future<Uint8List> downloadReport(
    String export,
    String from,
    String to,
  ) async {
    return _client.getBytes(
      _path('admin/reports/generate/', {
        'export': export,
        'from': from,
        'to': to,
      }),
    );
  }

  Future<Map<String, Object?>> peakCheck({
    required Object? siteId,
    required Object? meterId,
    required Object? value,
    required String unit,
    required String periodStart,
    required String periodEnd,
  }) async {
    final rawValue = value?.toString() ?? '';
    final parsedValue = num.tryParse(rawValue) ?? rawValue;
    return _asMap(
      await _client.postJson('admin/readings/peak-check/', {
        'site_id': siteId,
        'meter_id': meterId,
        'value': parsedValue,
        'unit': unit,
        'period_start': periodStart,
        'period_end': periodEnd,
      }),
    );
  }

  Future<Map<String, Object?>> uploadFieldScan({
    required Uint8List bytes,
    required String filename,
    required String kind,
    Object? siteId,
    Object? meterId,
    Map<String, Object?> rawFields = const {},
  }) async {
    final fields = <String, String>{
      'kind': kind,
      if (siteId != null) 'site_id': siteId.toString(),
      if (meterId != null) 'meter_id': meterId.toString(),
      'raw_fields': jsonEncode(rawFields),
    };
    return _asMap(
      await _client.postMultipartBytes(
        'admin/field-scans/upload/',
        fields: fields,
        fileField: 'image',
        files: [ApiUploadFile(bytes: bytes, filename: filename)],
      ),
    );
  }

  Future<Map<String, Object?>> confirmFieldScan(
    String scanId, {
    required Map<String, Object?> values,
  }) async {
    return _asMap(
      await _client.postJson('admin/field-scans/$scanId/confirm/', {
        'values': values,
      }),
    );
  }

  Future<Map<String, Object?>> reviewCandidate(
    String candidateId,
    String action,
  ) async {
    return _asMap(
      await _client.postJson('admin/asset-candidates/$candidateId/review/', {
        'action': action,
      }),
    );
  }

  Future<Map<String, Object?>> completeTask(
    String taskId, {
    Map<String, Object?> answers = const {},
    List<Object?> readings = const [],
    String? idempotencyKey,
  }) async {
    return _asMap(
      await _client.postJson('admin/tasks/$taskId/complete/', {
        'answers': answers,
        'readings': readings,
        'idempotency_key':
            idempotencyKey ?? DateTime.now().microsecondsSinceEpoch.toString(),
      }),
    );
  }

  Future<AdminStaffHistory> staffHistory(Object userId) async {
    final payload = await _client.getJson('admin/staff/$userId/history/');
    return AdminStaffHistory(
      userId: _integer(payload['user_id'], fallback: _integer(userId)),
      tasks: _asMapList(payload['tasks']),
      scores: _asMapList(payload['scores']),
      evidence: _asMapList(payload['evidence']),
    );
  }

  Future<Map<String, Object?>> uploadImport({
    required Uint8List bytes,
    required String filename,
  }) async {
    return _asMap(
      await _client.postMultipartBytes(
        'admin/imports/upload/',
        fields: const {},
        fileField: 'file',
        files: [ApiUploadFile(bytes: bytes, filename: filename)],
      ),
    );
  }
}
