import 'dart:convert';

import 'package:energia/core/api/energia_api_client.dart';
import 'package:energia/core/theme/energia_theme.dart';
import 'package:energia/features/admin_web/data/admin_workspace_repository.dart';
import 'package:energia/features/admin_web/presentation/admin_workspace_pages.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('report download requests and reports the exported file', (tester) async {
    final csv = utf8.encode('section,label,value\nscore,Packaging,83.9\n');
    final client = EnergiaApiClient(
      baseUrl: 'https://api.example/api/v1',
      username: 'energia-admin',
      password: 'Energia-Admin-Demo-2026!',
      tokenStore: InMemoryApiTokenStore(),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/auth/token/')) {
          return http.Response(
            jsonEncode({'access': 'access-token', 'refresh': 'refresh-token'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/admin/reports/generate/')) {
          expect(request.url.queryParameters['export'], 'csv');
          return http.Response.bytes(
            csv,
            200,
            headers: {'content-type': 'text/csv'},
          );
        }
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      }),
    );
    await client.authenticate();

    await tester.pumpWidget(
      MaterialApp(
        theme: EnergiaTheme.light,
        home: Scaffold(body: ReportsPage(repository: AdminWorkspaceRepository(client))),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('report-csv')));
    await tester.pumpAndSettle();

    expect(find.textContaining('energia-report-'), findsOneWidget);
    expect(find.textContaining('.csv ready (${csv.length} bytes)'), findsOneWidget);
  });

  testWidgets('report summary shows styled cards, charts, and granular tables', (tester) async {
    final report = {
      'period': {'start': '2026-10-24', 'end': '2026-11-22'},
      'scores': [
        {
          'department': 'Packaging',
          'site': 'North Plant',
          'score': 83.9,
          'energy': 99.6,
          'checks': 60.3,
          'coverage': 1,
          'provisional': false,
        },
      ],
      'energy': {
        'total': 1200,
        'total_cost': 240,
        'series': [
          {
            'label': '2026-11-22',
            'actual': 600,
            'expected': 500,
            'cost': 120,
            'unit': 'kWh',
            'sample_count': 4,
          },
        ],
      },
      'tasks': {'total': 10, 'completed': 7, 'overdue': 1, 'review': 1},
      'tasks_by_department': [
        {'department': 'Packaging', 'total': 10, 'completed': 7, 'overdue': 1, 'review': 1},
      ],
      'alerts': [
        {'title': 'Compressed-air loss', 'status': 'new', 'severity': 'warning'},
      ],
      'findings': [
        {'requirement': 'Calibration', 'status': 'action', 'severity': 'minor'},
      ],
      'work_orders': <Object>[],
      'alerts_by_severity': [
        {'severity': 'warning', 'total': 1},
      ],
      'findings_by_severity': [
        {'severity': 'minor', 'total': 1},
      ],
      'data_quality': {'reading_samples': 4, 'provisional_scores': 0},
      'emissions': 1,
    };
    final client = EnergiaApiClient(
      baseUrl: 'https://api.example/api/v1',
      username: 'energia-admin',
      password: 'Energia-Admin-Demo-2026!',
      tokenStore: InMemoryApiTokenStore(),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/auth/token/')) {
          return http.Response(
            jsonEncode({'access': 'access-token', 'refresh': 'refresh-token'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/admin/reports/generate/')) {
          return http.Response(
            jsonEncode(report),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      }),
    );
    await client.authenticate();

    await tester.pumpWidget(
      MaterialApp(
        theme: EnergiaTheme.light,
        home: Scaffold(body: ReportsPage(repository: AdminWorkspaceRepository(client))),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-json')));
    await tester.pumpAndSettle();

    expect(find.text('OVERALL SCORE'), findsOneWidget);
    expect(find.text('Department performance'), findsOneWidget);
    expect(find.text('Actual consumption by day'), findsOneWidget);
    expect(find.text('Completion by department'), findsOneWidget);
    expect(find.text('Attention register'), findsOneWidget);
    expect(find.byKey(const Key('energia-line-chart')), findsOneWidget);
    expect(find.textContaining('Packaging'), findsWidgets);
  });
}
