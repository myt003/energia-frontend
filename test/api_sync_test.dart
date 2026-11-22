import 'dart:convert';
import 'dart:io';

import 'package:energia/core/api/energia_api_client.dart';
import 'package:energia/features/daily_tasks/data/daily_task_repository.dart';
import 'package:energia/features/daily_tasks/domain/compliance_task.dart';
import 'package:energia/features/equipment_inventory/data/equipment_repository.dart';
import 'package:energia/features/task_intelligence/data/task_intelligence_repository.dart';
import 'package:energia/features/task_intelligence/domain/task_intelligence.dart';
import 'package:energia/features/work_profile/data/work_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'API repositories authenticate and map synchronized server records',
    () async {
      final requests = <String>[];
      final client = MockClient((request) async {
        requests.add(
          '${request.method} ${request.url.path}?${request.url.query}',
        );
        if (request.url.path.endsWith('/auth/token/')) {
          return _jsonResponse({
            'access': 'access-token',
            'refresh': 'refresh-token',
          });
        }
        expect(request.headers['authorization'], 'Bearer access-token');
        if (request.url.path.endsWith('/me/work-profile/')) {
          return _jsonResponse(_profilePayload);
        }
        if (request.url.path.endsWith('/me/equipment/') &&
            request.method == 'PUT') {
          return _jsonResponse(<Object?>[]);
        }
        if (request.url.path.endsWith('/me/tasks/')) {
          return _jsonResponse([_taskPayload, _habitPayload]);
        }
        if (request.url.path.endsWith('/explanation/')) {
          return _jsonResponse(_explanationPayload);
        }
        if (request.url.path.endsWith('/evidence/evidence-001/')) {
          return _jsonResponse(_evidencePayload);
        }
        if (request.url.path.endsWith('/evidence/') &&
            request.method == 'POST') {
          expect(
            utf8.decode(request.bodyBytes, allowMalformed: true),
            contains('content-type: image/jpeg'),
          );
          return _jsonResponse(_evidencePayload, status: 201);
        }
        if (request.url.path.endsWith('/assets/')) {
          final page = request.url.queryParameters['page'];
          return _jsonResponse({
            'count': 1,
            'next': null,
            'previous': null,
            'results': [_assetPayload],
            'page': page,
          });
        }
        return http.Response('not found', 404);
      });
      final apiClient = EnergiaApiClient(
        baseUrl: 'https://api.example/api/v1',
        username: 'maya',
        password: 'energia-demo',
        httpClient: client,
        tokenStore: InMemoryApiTokenStore(),
      );
      final profileRepository = ApiWorkProfileRepository(apiClient);

      final profile = await profileRepository.load();
      expect(profile.employeeName, 'Maya Chen');
      expect(profile.department, 'Packaging');
      expect(
        profile.equipmentInteractions['heat-sealer-hs03'],
        contains('inspect'),
      );
      expect(profile.pendingApprovalLabels, isEmpty);

      await profileRepository.save(profile);
      expect(
        requests.where((request) => request.startsWith('PUT ')),
        hasLength(2),
      );

      final tasks = await ApiDailyTaskRepository(apiClient)
          .load(profile: profile);
      final complianceTask = tasks.tasks.firstWhere(
        (task) => task.kind == ComplianceTaskKind.compliance,
      );
      final habitTask = tasks.tasks.firstWhere(
        (task) => task.kind == ComplianceTaskKind.energyHabit,
      );
      expect(complianceTask.ruleId, 'RULE-EN-0042');
      expect(complianceTask.citation.sourceVersion, 'v4.2');
      expect(habitTask.ruleId, 'HABIT-IDLE-001');
      expect(habitTask.recommendationOwner, 'Packaging team lead');

      final intelligence = ApiTaskIntelligenceRepository(apiClient);
      final explanation = await intelligence.loadExplanation(habitTask.id);
      expect(explanation.aiSimplified, isTrue);
      expect(explanation.modelName, 'qwen/qwen3.8-27b');
      final evidenceFile = File('/tmp/opencode/energia-api-test.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]);
      final submitted = await intelligence.submitEvidence(
        taskId: habitTask.id,
        filePath: evidenceFile.path,
        mediaType: EvidenceMediaType.photo,
        capturedAt: DateTime(2026, 11, 21, 12),
        idempotencyKey: 'sync-test-evidence',
      );
      expect(submitted.status, EvidenceProcessingStatus.verified);
      expect(submitted.verification?.confidence, 0.94);
      final reloaded = await intelligence.loadEvidence('evidence-001');
      expect(reloaded.verification?.modelName, 'qwen/qwen3.8-27b');

      final assets = await ApiEquipmentRepository(apiClient).loadAssets();
      expect(assets.single.id, 'heat-sealer-hs03');
      expect(assets.single.qrValue, contains('63c6df4c'));
      expect(apiClient.syncStatus.value.state, ApiSyncState.synced);
      expect(
        requests.where(
          (request) => request.startsWith('POST /api/v1/auth/token/'),
        ),
        hasLength(1),
      );
    },
  );
}

http.Response _jsonResponse(Object payload, {int status = 200}) {
  return http.Response(
    jsonEncode(payload),
    status,
    headers: {'content-type': 'application/json'},
  );
}

final _profilePayload = <String, Object?>{
  'employee': {'id': 1, 'name': 'Maya Chen', 'username': 'maya'},
  'organization': {'id': 1, 'name': 'Aster Foods'},
  'site': {'id': 1, 'name': 'North Plant'},
  'department': {
    'id': 1,
    'name': 'Packaging',
    'approved_id': 1,
    'is_pending': false,
  },
  'department_options': [
    {'id': 1, 'name': 'Packaging'},
    {'id': 2, 'name': 'Utilities'},
  ],
  'job_role': 'Production operator',
  'shift': 'day',
  'shift_label': 'Day · 06:00–14:00',
  'activities': [
    {
      'id': 'line_startup',
      'title': 'Line start-up',
      'description': 'Start the line',
      'selected': true,
    },
  ],
  'custom_activities': <Object?>[],
  'notes': '',
  'is_complete': true,
  'pending_approval_labels': <Object?>[],
  'assignments': [
    {
      'asset': _assetPayload,
      'interactions': ['operate', 'inspect'],
      'updated_at': '2026-11-21T09:00:00Z',
    },
  ],
  'updated_at': '2026-11-21T09:00:00Z',
};

final _assetPayload = <String, Object?>{
  'id': 'heat-sealer-hs03',
  'asset_code': 'PKG-HS03',
  'name': 'Heat sealer HS-03',
  'type': 'Packaging machine',
  'department': 'Packaging',
  'location': 'Packaging line 3',
  'serial_number': 'HS03-9084',
  'qr_value': 'energia://asset/63c6df4c-3fc5-4daa-a8d2-1cfbcb99d005',
};

final _taskPayload = <String, Object?>{
  'id': '90b89b68-5632-4a18-a72a-64c9fe0fd100',
  'rule_id': 'RULE-EN-0042',
  'rule_version': 3,
  'title': 'Packaging shift energy walk',
  'instruction': 'Check the route.',
  'department': 'Packaging',
  'asset_id': null,
  'asset_name': null,
  'asset_code': null,
  'due_at': '2026-11-21T23:30:00Z',
  'status': 'due',
  'urgency': 'important',
  'evidence_requirement': 'Checklist · 5 answers',
  'pass_condition': 'All route points checked.',
  'citation': {
    'source_title': 'Aster Foods Energy Control Procedure',
    'source_version': 'v4.2',
    'section': 'Section 3.2',
  },
  'why_assigned': ['Packaging department'],
  'generated_at': '2026-11-21T05:00:00Z',
  'event_triggered': false,
  'completed_at': null,
  'submitted_at': null,
};

final _habitPayload = <String, Object?>{
  ..._taskPayload,
  'id': '90b89b68-5632-4a18-a72a-64c9fe0fd101',
  'rule_id': 'HABIT-IDLE-001',
  'rule_version': 1,
  'task_kind': 'energy_habit',
  'title': 'Avoid unnecessary idle operation on Heat sealer HS-03',
  'recommendation_owner': 'Packaging team lead',
};

final _explanationPayload = <String, Object?>{
  'plain_instruction': 'Observe the approved idle state.',
  'why_summary': 'Selected for the assigned machine.',
  'evidence_guidance': 'Answer yes or no.',
  'safety_summary': 'Approved procedures take priority.',
  'ai_simplified': true,
  'model_name': 'qwen/qwen3.8-27b',
  'model_version': 'qwen/qwen3.8-27b',
  'generated_at': '2026-11-21T12:00:00Z',
};

final _evidencePayload = <String, Object?>{
  'id': 'evidence-001',
  'task_id': '90b89b68-5632-4a18-a72a-64c9fe0fd101',
  'media_type': 'photo',
  'original_filename': 'evidence.jpg',
  'mime_type': 'image/jpeg',
  'size_bytes': 4,
  'checksum_sha256': 'abc',
  'captured_at': '2026-11-21T12:00:00Z',
  'status': 'verified',
  'created_at': '2026-11-21T12:00:00Z',
  'updated_at': '2026-11-21T12:01:00Z',
  'frames': <Object?>[],
  'verification_result': {
    'status': 'verified',
    'factual_summary': 'Visible state matches the task.',
    'evidence_quality': 'adequate',
    'confidence': 0.94,
    'extracted_fields': <String, Object?>{},
    'findings': <Object?>[],
    'cited_frames': <Object?>[],
    'deterministic_checks': {'minimum_resolution': true},
    'model_name': 'qwen/qwen3.8-27b',
    'model_version': 'qwen/qwen3.8-27b',
    'provider_request_id': 'request-1',
    'needs_human_review': false,
    'created_at': '2026-11-21T12:01:00Z',
  },
};
