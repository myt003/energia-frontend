import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/platform/file_downloader.dart';
import '../../../core/theme/energia_theme.dart';
import '../data/admin_workspace_repository.dart';
import 'energia_charts.dart';

String _text(
  Map<String, Object?> item,
  List<String> keys, {
  String fallback = '—',
}) {
  for (final key in keys) {
    final value = item[key];
    if (value != null && value.toString().isNotEmpty) return value.toString();
  }
  return fallback;
}

Object? _first(Map<String, Object?> item, List<String> keys) {
  for (final key in keys) {
    final value = item[key];
    if (value != null) return value;
  }
  return null;
}

String _idOf(Map<String, Object?> item) => _text(
  item,
  const ['id', 'uuid', 'rule_id', 'task_id', 'scan_id', 'candidate_id'],
  fallback: '',
);

int? _intOf(Object? value) {
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? num.tryParse(value)?.round();
  return null;
}

int _countOf(Object? value) {
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  if (value is List) return value.length;
  if (value is Map) return value.length;
  return 0;
}

String _dateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year.toString().padLeft(4, '0')}-$month-$day';
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 5),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: EnergiaColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EnergiaColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const _Card(
      title: 'Loading',
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Could not load workspace data',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('workspace-retry'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Nothing to show yet',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class StaffChecksPage extends StatefulWidget {
  const StaffChecksPage({required this.repository, super.key});

  final AdminWorkspaceRepository repository;

  @override
  State<StaffChecksPage> createState() => _StaffChecksPageState();
}

class _StaffChecksPageState extends State<StaffChecksPage> {
  late Future<List<Map<String, Object?>>> _future =
      widget.repository.resource('tasks');

  void _reload() {
    setState(() {
      _future = widget.repository.resource('tasks');
    });
  }

  Future<void> _complete(Map<String, Object?> task) async {
    final id = _idOf(task);
    try {
      await widget.repository.completeTask(
        id,
        answers: const <String, Object?>{},
        readings: const <Object?>[],
        idempotencyKey: DateTime.now().microsecondsSinceEpoch.toString(),
      );
      if (!mounted) return;
      _toast(context, 'Task $id completed');
      _reload();
    } catch (error) {
      if (!mounted) return;
      _toast(context, 'Could not complete task: $error');
    }
  }

  Future<void> _history(Map<String, Object?> task) async {
    final assigneeId = _intOf(
      _first(task, const [
        'assignee_id',
        'user_id',
        'assignee',
        'assigned_to',
        'assigned_to_id',
      ]),
    );
    if (assigneeId == null) {
      if (mounted) _toast(context, 'This task has no assignee id');
      return;
    }
    try {
      final history = await widget.repository.staffHistory(assigneeId);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Staff history · ${history.userId}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _InfoRow(label: 'Tasks', value: '${history.tasks.length}'),
                _InfoRow(label: 'Scores', value: '${history.scores.length}'),
                _InfoRow(label: 'Evidence', value: '${history.evidence.length}'),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _toast(context, 'Could not load staff history: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const _PageHeader(
          title: 'Staff checks',
          subtitle: 'Live compliance task queue with staff drill-down.',
        ),
        const SizedBox(height: 18),
        FutureBuilder<List<Map<String, Object?>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingCard();
            }
            if (snapshot.hasError) {
              return _ErrorCard(
                message: '${snapshot.error}',
                onRetry: _reload,
              );
            }
            final tasks = snapshot.data ?? const <Map<String, Object?>>[];
            if (tasks.isEmpty) {
              return const _EmptyCard(message: 'No staff tasks are currently queued.');
            }
            final counts = <String, int>{};
            for (final task in tasks) {
              final status = _text(task, const ['status'], fallback: 'unknown');
              counts[status] = (counts[status] ?? 0) + 1;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Card(
                  title: 'Status overview',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final entry in counts.entries)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: EnergiaColors.blueSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${entry.key}: ${entry.value}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _Card(
                  title: 'Tasks (${tasks.length})',
                  child: Column(
                    children: [
                      for (final task in tasks)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: EnergiaColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: EnergiaColors.line),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _text(task, const ['title', 'name', 'rule_title']),
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 5),
                                _InfoRow(
                                  label: 'Status',
                                  value: _text(task, const ['status']),
                                ),
                                _InfoRow(
                                  label: 'Due',
                                  value: _text(task, const ['due_at', 'dueAt', 'due_date']),
                                ),
                                _InfoRow(
                                  label: 'Assignee',
                                  value: _text(task, const [
                                    'assignee_name',
                                    'assignee',
                                    'assigned_to_name',
                                    'user_name',
                                  ]),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    OutlinedButton.icon(
                                      key: Key('task-complete-${_idOf(task)}'),
                                      onPressed: () => _complete(task),
                                      icon: const Icon(Icons.check_circle_outline, size: 17),
                                      label: const Text('Complete'),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      key: Key('task-history-${_idOf(task)}'),
                                      onPressed: () => _history(task),
                                      icon: const Icon(Icons.history, size: 17),
                                      label: const Text('Staff history'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class KnowledgePage extends StatefulWidget {
  const KnowledgePage({required this.repository, super.key});

  final AdminWorkspaceRepository repository;

  @override
  State<KnowledgePage> createState() => _KnowledgePageState();
}

class _KnowledgePageState extends State<KnowledgePage> {
  late Future<List<Map<String, Object?>>> _future =
      widget.repository.resource('knowledge-documents');
  final TextEditingController _question = TextEditingController();
  AdminRagAnswer? _answer;
  bool _busy = false;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = widget.repository.resource('knowledge-documents');
    });
  }

  Future<void> _upload() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'doc', 'txt', 'md'],
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        if (mounted) _toast(context, 'Could not read ${file.name}: file bytes are unavailable');
        return;
      }
      if (!mounted) return;
      setState(() => _busy = true);
      final document = await widget.repository.ingestDocument(
        bytes: bytes,
        filename: file.name,
        title: file.name,
      );
      if (!mounted) return;
      _toast(
        context,
        'Ingested ${document['title'] ?? file.name}: '
        '${document['chunk_count'] ?? 0} chunk(s)',
      );
      setState(() {
        _busy = false;
        _future = widget.repository.resource('knowledge-documents');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(context, 'Document upload failed: $error');
    }
  }

  Future<void> _ask() async {
    final query = _question.text.trim();
    if (query.isEmpty) {
      _toast(context, 'Enter a question first');
      return;
    }
    setState(() => _busy = true);
    try {
      final answer = await widget.repository.ragAnswer(query);
      if (!mounted) return;
      setState(() {
        _answer = answer;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(context, 'Knowledge query failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const _PageHeader(
          title: 'Knowledge base',
          subtitle: 'Ingest compliance documents and ask grounded questions.',
        ),
        const SizedBox(height: 18),
        _Card(
          title: 'Document ingestion',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Accepted formats: PDF, DOCX, DOC, TXT, MD. '
                'Private documents are chunked and indexed for retrieval.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('knowledge-upload'),
                onPressed: _busy ? null : _upload,
                icon: const Icon(Icons.upload_file),
                label: Text(_busy ? 'Working…' : 'Pick and upload document'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Card(
          title: 'Ask the knowledge base',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('rag-question'),
                controller: _question,
                decoration: const InputDecoration(
                  labelText: 'Question',
                  hintText: 'What does the policy require for meter checks?',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                key: const Key('rag-submit'),
                onPressed: _busy ? null : _ask,
                icon: const Icon(Icons.question_answer_outlined),
                label: const Text('Ask'),
              ),
              if (_answer != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: EnergiaColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: EnergiaColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _answer!.answer.isEmpty ? 'No answer returned.' : _answer!.answer,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Grounded: ${_answer!.grounded} · Model: ${_answer!.model ?? 'local'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      for (final citation in _answer!.citations)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '“${_text(citation, const ['text'])}” — '
                            '${_text(_asNestedMap(citation['citation']), const ['title', 'source', 'section', 'page'])}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        FutureBuilder<List<Map<String, Object?>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingCard();
            }
            if (snapshot.hasError) {
              return _ErrorCard(message: '${snapshot.error}', onRetry: _reload);
            }
            final documents = snapshot.data ?? const <Map<String, Object?>>[];
            if (documents.isEmpty) {
              return const _EmptyCard(message: 'No documents have been ingested yet.');
            }
            return _Card(
              title: 'Documents (${documents.length})',
              child: Column(
                children: [
                  for (final document in documents)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: EnergiaColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: EnergiaColors.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _text(document, const ['title', 'name']),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            _InfoRow(
                              label: 'Status',
                              value: _text(document, const ['status']),
                            ),
                            _InfoRow(
                              label: 'Chunks',
                              value: '${_countOf(document['chunk_count'])}',
                            ),
                            if (_text(
                              document,
                              const ['ingestion_error'],
                              fallback: '',
                            ).isNotEmpty)
                              _InfoRow(
                                label: 'Error',
                                value: _text(document, const ['ingestion_error']),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

Map<String, Object?> _asNestedMap(Object? value) {
  if (value is! Map) return const <String, Object?>{};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

class RulesPage extends StatefulWidget {
  const RulesPage({required this.repository, super.key});

  final AdminWorkspaceRepository repository;

  @override
  State<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends State<RulesPage> {
  late Future<List<Map<String, Object?>>> _future =
      widget.repository.resource('custom-rules');
  final TextEditingController _title = TextEditingController();
  final TextEditingController _instruction = TextEditingController();
  final TextEditingController _department = TextEditingController();
  final Map<String, AdminRulePreview> _previews = <String, AdminRulePreview>{};
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _instruction.dispose();
    _department.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = widget.repository.resource('custom-rules');
    });
  }

  Future<void> _create() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      _toast(context, 'A rule title is required');
      return;
    }
    final departmentId = int.tryParse(_department.text.trim());
    setState(() => _busy = true);
    try {
      await widget.repository.createResource('custom-rules', {
        'title': title,
        'instruction': _instruction.text.trim(),
        'department_id': ?departmentId,
      });
      if (!mounted) return;
      _title.clear();
      _instruction.clear();
      _department.clear();
      _toast(context, 'Rule draft created');
      setState(() {
        _busy = false;
        _future = widget.repository.resource('custom-rules');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(context, 'Could not create rule: $error');
    }
  }

  Future<void> _preview(String id) async {
    setState(() => _busy = true);
    try {
      final preview = await widget.repository.previewRule(id);
      if (!mounted) return;
      setState(() {
        _previews[id] = preview;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(context, 'Preview failed: $error');
    }
  }

  Future<void> _publish(String id) async {
    setState(() => _busy = true);
    try {
      await widget.repository.publishRule(id);
      if (!mounted) return;
      _toast(context, 'Rule $id published');
      setState(() {
        _busy = false;
        _future = widget.repository.resource('custom-rules');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(context, 'Publish failed: $error');
    }
  }

  Widget? _previewCard(String id) {
    final preview = _previews[id];
    if (preview == null) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: EnergiaColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: EnergiaColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(label: 'Matches', value: '${preview.matches}'),
            _InfoRow(label: 'Staff in scope', value: '${preview.staffInScope}'),
            _InfoRow(
              label: 'Tasks / day',
              value: '${preview.estimatedTasksPerDay}',
            ),
            for (final warning in preview.warnings) Text('⚠ $warning'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const _PageHeader(
          title: 'Rules and publication',
          subtitle: 'Draft, dry-run, and publish no-code compliance rules.',
        ),
        const SizedBox(height: 18),
        _Card(
          title: 'Create a rule draft',
          child: Column(
            children: [
              TextField(
                key: const Key('rule-title'),
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('rule-instruction'),
                controller: _instruction,
                decoration: const InputDecoration(labelText: 'Instruction'),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('rule-department'),
                controller: _department,
                decoration: const InputDecoration(
                  labelText: 'Department id',
                  hintText: 'e.g. 3',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('rule-create'),
                onPressed: _busy ? null : _create,
                icon: const Icon(Icons.add),
                label: const Text('Create draft'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FutureBuilder<List<Map<String, Object?>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingCard();
            }
            if (snapshot.hasError) {
              return _ErrorCard(message: '${snapshot.error}', onRetry: _reload);
            }
            final rules = snapshot.data ?? const <Map<String, Object?>>[];
            if (rules.isEmpty) {
              return const _EmptyCard(message: 'No custom rules have been created.');
            }
            return _Card(
              title: 'Custom rules (${rules.length})',
              child: Column(
                children: [
                  for (final rule in rules)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: EnergiaColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: EnergiaColors.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _text(rule, const ['title', 'name']),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            _InfoRow(
                              label: 'Code',
                              value: _text(rule, const ['code', 'rule_code']),
                            ),
                            _InfoRow(
                              label: 'Version',
                              value: _text(rule, const ['version']),
                            ),
                            _InfoRow(
                              label: 'Status',
                              value: _text(rule, const ['status']),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  key: Key('rule-preview-${_idOf(rule)}'),
                                  onPressed: _busy
                                      ? null
                                      : () => _preview(_idOf(rule)),
                                  icon: const Icon(Icons.visibility_outlined, size: 17),
                                  label: const Text('Preview'),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.icon(
                                  key: Key('rule-publish-${_idOf(rule)}'),
                                  onPressed:
                                      _busy ||
                                          _text(rule, const ['status']) == 'published'
                                      ? null
                                      : () => _publish(_idOf(rule)),
                                  icon: const Icon(Icons.publish, size: 17),
                                  label: const Text('Publish'),
                                ),
                              ],
                            ),
                            ?_previewCard(_idOf(rule)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _EnergyBundle {
  const _EnergyBundle({
    required this.series,
    required this.flow,
    required this.readings,
    required this.scores,
  });

  final AdminChartSeries series;
  final AdminEnergyFlow flow;
  final List<Map<String, Object?>> readings;
  final List<Map<String, Object?>> scores;
}

class EnergyDataPage extends StatefulWidget {
  const EnergyDataPage({required this.repository, super.key});

  final AdminWorkspaceRepository repository;

  @override
  State<EnergyDataPage> createState() => _EnergyDataPageState();
}

class _EnergyDataPageState extends State<EnergyDataPage> {
  late Future<_EnergyBundle> _future = _load();
  final TextEditingController _site = TextEditingController();
  final TextEditingController _meter = TextEditingController();
  final TextEditingController _value = TextEditingController();
  final TextEditingController _unit = TextEditingController(text: 'kWh');
  final TextEditingController _periodStart = TextEditingController();
  final TextEditingController _periodEnd = TextEditingController();
  Map<String, Object?>? _peak;
  String _status = '';

  @override
  void dispose() {
    _site.dispose();
    _meter.dispose();
    _value.dispose();
    _unit.dispose();
    _periodStart.dispose();
    _periodEnd.dispose();
    super.dispose();
  }

  Future<_EnergyBundle> _load() async {
    final values = await Future.wait<Object>([
      widget.repository.chartSeries(),
      widget.repository.energyFlow(),
      widget.repository.resource('readings'),
      widget.repository.healthScores(),
    ]);
    return _EnergyBundle(
      series: values[0] as AdminChartSeries,
      flow: values[1] as AdminEnergyFlow,
      readings: values[2] as List<Map<String, Object?>>,
      scores: values[3] as List<Map<String, Object?>>,
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _peakCheck() async {
    try {
      final result = await widget.repository.peakCheck(
        siteId: _intOf(_site.text.trim()) ?? _site.text.trim(),
        meterId: _intOf(_meter.text.trim()) ?? _meter.text.trim(),
        value: _value.text.trim(),
        unit: _unit.text.trim().isEmpty ? 'kWh' : _unit.text.trim(),
        periodStart: _periodStart.text.trim(),
        periodEnd: _periodEnd.text.trim(),
      );
      if (!mounted) return;
      setState(() => _peak = result);
    } catch (error) {
      if (!mounted) return;
      _toast(context, 'Peak check failed: $error');
    }
  }

  Future<void> _refreshWeather() async {
    try {
      final created = await widget.repository.refreshWeather();
      if (!mounted) return;
      setState(() => _status = 'Weather refresh created $created forecast(s).');
    } catch (error) {
      if (!mounted) return;
      _toast(context, 'Weather refresh failed: $error');
    }
  }

  Future<void> _uploadImport() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        if (mounted) _toast(context, 'Could not read ${file.name}: file bytes are unavailable');
        return;
      }
      await widget.repository.uploadImport(bytes: bytes, filename: file.name);
      if (!mounted) return;
      setState(() {
        _status = 'Import ${file.name} staged for validation.';
        _future = _load();
      });
    } catch (error) {
      if (!mounted) return;
      _toast(context, 'Import upload failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const _PageHeader(
          title: 'Energy data',
          subtitle: 'Consumption series, flow, readings, and weather refresh.',
        ),
        const SizedBox(height: 18),
        FutureBuilder<_EnergyBundle>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingCard();
            }
            if (snapshot.hasError) {
              return _ErrorCard(message: '${snapshot.error}', onRetry: _reload);
            }
            final data = snapshot.requireData;
            final readings = data.readings.take(12).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Card(
                  title: 'Consumption · ${data.series.points.length} points',
                  child: data.series.points.isEmpty
                      ? const Text('No consumption series available.')
                      : EnergiaLineChart(points: data.series.points),
                ),
                const SizedBox(height: 14),
                _Card(
                  title: 'Energy flow · ${data.flow.unit}',
                  child: EnergiaFlowDiagram(
                    nodes: data.flow.nodes,
                    links: data.flow.links,
                  ),
                ),
                const SizedBox(height: 14),
                _Card(
                  title: 'Recent readings (${readings.length})',
                  child: readings.isEmpty
                      ? const Text('No readings recorded.')
                      : Table(
                          columnWidths: const {
                            0: FlexColumnWidth(3),
                            1: FlexColumnWidth(2),
                            2: FlexColumnWidth(1),
                          },
                          children: [
                            const TableRow(
                              children: [
                                Text('Label', style: TextStyle(fontWeight: FontWeight.w800)),
                                Text('Value', style: TextStyle(fontWeight: FontWeight.w800)),
                                Text('Unit', style: TextStyle(fontWeight: FontWeight.w800)),
                              ],
                            ),
                            for (final reading in readings)
                              TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Text(
                                      _text(reading, const ['label', 'period', 'date']),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Text(
                                      _text(reading, const ['value', 'actual']),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Text(
                                      _text(reading, const ['unit']),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                _Card(
                  title: 'Department health scores (${data.scores.length})',
                  child: data.scores.isEmpty
                      ? const Text('No health scores available.')
                      : Column(
                          children: [
                            for (final score in data.scores)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: EnergiaColors.background,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: EnergiaColors.line),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${_text(score, const ['site_name'])} · '
                                        '${_text(score, const ['department_name'])}',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      _InfoRow(
                                        label: 'Overall',
                                        value: _text(score, const ['overall_score']),
                                      ),
                                      _InfoRow(
                                        label: 'Coverage',
                                        value: _text(score, const ['data_coverage']),
                                      ),
                                      _InfoRow(
                                        label: 'Provisional',
                                        value: _text(score, const ['provisional']),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        _Card(
          title: 'Manual reading and peak check',
          child: Column(
            children: [
              TextField(
                key: const Key('peak-site'),
                controller: _site,
                decoration: const InputDecoration(labelText: 'Site id'),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('peak-meter'),
                controller: _meter,
                decoration: const InputDecoration(labelText: 'Meter id'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('peak-value'),
                      controller: _value,
                      decoration: const InputDecoration(labelText: 'Value'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      key: const Key('peak-unit'),
                      controller: _unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('peak-start'),
                      controller: _periodStart,
                      decoration: const InputDecoration(
                        labelText: 'Period start',
                        hintText: '2026-01-01',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      key: const Key('peak-end'),
                      controller: _periodEnd,
                      decoration: const InputDecoration(
                        labelText: 'Period end',
                        hintText: '2026-01-31',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('peak-check'),
                onPressed: _peakCheck,
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Check reading'),
              ),
              if (_peak != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: EnergiaColors.blueSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(
                        label: 'Change',
                        value: _text(_peak!, const ['change_percent']),
                      ),
                      _InfoRow(
                        label: 'Peak',
                        value: _text(_peak!, const ['peak']),
                      ),
                      _InfoRow(
                        label: 'Quality flags',
                        value: _text(_peak!, const ['quality_flags']),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _text(_peak!, const ['recommendation']),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Card(
          title: 'Data operations',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    key: const Key('weather-refresh'),
                    onPressed: _refreshWeather,
                    icon: const Icon(Icons.cloud_sync_outlined),
                    label: const Text('Refresh weather'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('import-upload'),
                    onPressed: _uploadImport,
                    icon: const Icon(Icons.upload_outlined),
                    label: const Text('Upload Excel import'),
                  ),
                ],
              ),
              if (_status.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(_status, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MaintenanceBundle {
  const _MaintenanceBundle({
    required this.due,
    required this.plans,
    required this.orders,
  });

  final List<Map<String, Object?>> due;
  final List<Map<String, Object?>> plans;
  final List<Map<String, Object?>> orders;
}

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({required this.repository, super.key});

  final AdminWorkspaceRepository repository;

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  late Future<_MaintenanceBundle> _future = _load();

  Future<_MaintenanceBundle> _load() async {
    final values = await Future.wait<Object>([
      widget.repository.maintenanceDue(),
      widget.repository.resource('maintenance-plans'),
      widget.repository.resource('work-orders'),
    ]);
    return _MaintenanceBundle(
      due: values[0] as List<Map<String, Object?>>,
      plans: values[1] as List<Map<String, Object?>>,
      orders: values[2] as List<Map<String, Object?>>,
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const _PageHeader(
          title: 'Maintenance',
          subtitle: 'Due plans, anomaly signals, and improvement work orders.',
        ),
        const SizedBox(height: 18),
        FutureBuilder<_MaintenanceBundle>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingCard();
            }
            if (snapshot.hasError) {
              return _ErrorCard(message: '${snapshot.error}', onRetry: _reload);
            }
            final data = snapshot.requireData;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Card(
                  title: 'Due maintenance (${data.due.length})',
                  child: data.due.isEmpty
                      ? const Text('Nothing is due right now.')
                      : Column(
                          children: [
                            for (final item in data.due)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: EnergiaColors.background,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: EnergiaColors.line),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _text(item, const ['asset', 'asset_name']),
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      _InfoRow(
                                        label: 'Due date',
                                        value: _text(item, const ['due_date']),
                                      ),
                                      _InfoRow(
                                        label: 'State',
                                        value: _countOf(item['overdue']) > 0
                                            ? 'Overdue'
                                            : _countOf(item['due_soon']) > 0
                                                ? 'Due soon'
                                                : 'Scheduled',
                                      ),
                                      _InfoRow(
                                        label: 'Anomaly alerts',
                                        value: '${_countOf(item['anomaly_alerts'])}',
                                      ),
                                      _InfoRow(
                                        label: 'Reason',
                                        value: _text(item, const ['reason']),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                _Card(
                  title: 'Maintenance plans (${data.plans.length})',
                  child: data.plans.isEmpty
                      ? const Text('No maintenance plans configured.')
                      : Column(
                          children: [
                            for (final plan in data.plans)
                              _InfoRow(
                                label: _text(plan, const ['name', 'title']),
                                value: _text(plan, const ['status', 'frequency']),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                _Card(
                  title: 'Work orders (${data.orders.length})',
                  child: data.orders.isEmpty
                      ? const Text('No work orders recorded.')
                      : Column(
                          children: [
                            for (final order in data.orders)
                              _InfoRow(
                                label: _text(order, const ['title', 'name']),
                                value: _text(order, const ['status', 'deadline']),
                              ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({required this.repository, super.key});

  final AdminWorkspaceRepository repository;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final now = DateTime.now();
  late final TextEditingController _from = TextEditingController(
    text: _dateOnly(now.subtract(const Duration(days: 30))),
  );
  late final TextEditingController _to = TextEditingController(
    text: _dateOnly(now),
  );
  Future<Map<String, Object?>?> _future = Future<Map<String, Object?>?>.value();
  String _downloadStatus = '';

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _future = widget.repository.generateReport(_from.text.trim(), _to.text.trim());
    });
  }

  Future<void> _download(String export) async {
    try {
      final bytes = await widget.repository.downloadReport(
        export,
        _from.text.trim(),
        _to.text.trim(),
      );
      final extension = export == 'pdf' ? 'pdf' : 'csv';
      final mimeType = export == 'pdf' ? 'application/pdf' : 'text/csv';
      final filename =
          'energia-report-${_from.text.trim()}-${_to.text.trim()}.$extension';
      final saved = await saveFile(bytes, filename, mimeType);
      if (!mounted) return;
      setState(() {
        _downloadStatus = saved
            ? '$filename saved (${bytes.length} bytes).'
            : '$filename ready (${bytes.length} bytes) — open Reports in a web browser to save it.';
      });
    } catch (error) {
      if (!mounted) return;
      _toast(context, '$export export failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const _PageHeader(
          title: 'Reports',
          subtitle: 'Visual summaries, granular breakdowns, and auditable CSV or PDF exports.',
        ),
        const SizedBox(height: 18),
        _Card(
          title: 'Reporting period',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('report-from'),
                      controller: _from,
                      decoration: const InputDecoration(
                        labelText: 'From',
                        hintText: '2026-01-01',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      key: const Key('report-to'),
                      controller: _to,
                      decoration: const InputDecoration(
                        labelText: 'To',
                        hintText: '2026-01-31',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    key: const Key('report-json'),
                    onPressed: _retry,
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Generate JSON'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('report-csv'),
                    onPressed: () => _download('csv'),
                    icon: const Icon(Icons.table_chart_outlined),
                    label: const Text('Download CSV'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('report-pdf'),
                    onPressed: () => _download('pdf'),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Download PDF'),
                  ),
                ],
              ),
              if (_downloadStatus.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(_downloadStatus, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        FutureBuilder<Map<String, Object?>?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingCard();
            }
            if (snapshot.hasError) {
              return _ErrorCard(message: '${snapshot.error}', onRetry: _retry);
            }
            final report = snapshot.data;
            if (report == null || report.isEmpty) {
              return const _EmptyCard(
                message: 'Choose a period and generate a report to see metrics.',
              );
            }
            return _ReportSummary(report: report);
          },
        ),
      ],
    );
  }
}

Map<String, Object?> _reportMap(Object? value) {
  if (value is! Map) return const <String, Object?>{};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Map<String, Object?>> _reportList(Object? value) {
  if (value is! List) return const <Map<String, Object?>>[];
  return value.whereType<Map>().map(_reportMap).toList();
}

double? _reportNumber(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int _reportInt(Object? value) => _reportNumber(value)?.round() ?? 0;

String _reportText(Object? value, [String fallback = '—']) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String _reportFixed(Object? value, [int digits = 1]) {
  final number = _reportNumber(value);
  if (number == null) return _reportText(value);
  return number.toStringAsFixed(number.abs() >= 100 ? 0 : digits);
}

Color _reportScoreColor(double score) {
  if (score >= 80) return EnergiaColors.teal;
  if (score >= 60) return EnergiaColors.warning;
  return EnergiaColors.critical;
}

Widget _reportSectionTitle(String title) {
  return Row(
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      const SizedBox(width: 10),
      const Expanded(child: Divider(color: EnergiaColors.line, height: 1)),
    ],
  );
}

/// Visual report summary generated from the same JSON payload as the exports.
class _ReportSummary extends StatelessWidget {
  const _ReportSummary({required this.report});

  final Map<String, Object?> report;

  @override
  Widget build(BuildContext context) {
    final scores = _reportList(report['scores']);
    final tasks = _reportMap(report['tasks']);
    final energy = _reportMap(report['energy']);
    final quality = _reportMap(report['data_quality']);
    final energySeries = _reportList(energy['series']);
    final taskDepartments = _reportList(report['tasks_by_department']);
    final alerts = _reportList(report['alerts']);
    final findings = _reportList(report['findings']);
    final workOrders = _reportList(report['work_orders']);

    final scoreValues = scores
        .map((item) => _reportNumber(item['score']))
        .whereType<double>()
        .toList();
    final overall = scoreValues.isEmpty
        ? null
        : scoreValues.reduce((a, b) => a + b) / scoreValues.length;
    final totalChecks = _reportInt(tasks['total']);
    final completedChecks = _reportInt(tasks['completed']);
    final completion = totalChecks > 0 ? completedChecks / totalChecks : 0.0;
    final unit = _reportText(
      energySeries.isEmpty ? null : energySeries.first['unit'],
      'kWh',
    );

    final attentionRows = <List<String>>[
      for (final item in alerts.take(4))
        [
          'Alert',
          _reportText(item['title']),
          '${_reportText(item['status'], 'new')} / ${_reportText(item['severity'])}',
        ],
      for (final item in findings.take(4))
        [
          'Finding',
          _reportText(item['requirement']),
          '${_reportText(item['status'], 'open')} / ${_reportText(item['severity'])}',
        ],
      for (final item in workOrders.take(3))
        [
          'Work order',
          _reportText(item['title']),
          '${_reportText(item['status'], 'open')} · ${_reportText(item['due_date'])}',
        ],
    ];
    if (attentionRows.isEmpty) {
      attentionRows.add(['None', 'No alerts, findings, or work orders', '—']);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ReportMetricCard(
              label: 'Overall score',
              value: overall == null ? '—' : overall.toStringAsFixed(1),
              caption: '${scores.length} departments',
              color: EnergiaColors.teal,
            ),
            _ReportMetricCard(
              label: 'Energy',
              value: '${_reportFixed(energy['total'], 0)} $unit',
              caption: '${_reportInt(quality['reading_samples'])} samples',
              color: EnergiaColors.deepNavy,
            ),
            _ReportMetricCard(
              label: 'Checks verified',
              value: '$completedChecks/$totalChecks',
              caption: '${_reportInt(tasks['overdue'])} overdue',
              color: EnergiaColors.critical,
            ),
            _ReportMetricCard(
              label: 'Alerts & findings',
              value: '${alerts.length + findings.length}',
              caption: '${_reportInt(report['emissions'])} emission records',
              color: EnergiaColors.warning,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _reportSectionTitle('Department performance'),
        const SizedBox(height: 10),
        _Card(
          title: 'Server-calculated scores',
          child: scores.isEmpty
              ? const Text('No department scores in this period.')
              : Column(
                  children: [
                    for (final item in scores)
                      _ReportScoreBar(
                        label: _reportText(
                          item['department'],
                          _reportText(item['site'], 'Department'),
                        ),
                        score: _reportNumber(item['score']) ?? 0,
                        provisional: item['provisional'] == true,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        _reportSectionTitle('Energy consumption'),
        const SizedBox(height: 10),
        _Card(
          title: 'Actual consumption by day',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (energySeries.isNotEmpty)
                SizedBox(
                  height: 230,
                  child: EnergiaLineChart(points: energySeries, height: 230),
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: Text('No readings in this period.')),
                ),
              const SizedBox(height: 14),
              _ReportMiniTable(
                headers: const ['Date', 'Actual', 'Baseline', 'Cost'],
                flexes: const [2, 1, 1, 1],
                rows: [
                  for (final item in energySeries.take(6))
                    [
                      _reportText(item['label']),
                      _reportFixed(item['actual']),
                      _reportFixed(item['expected']),
                      _reportFixed(item['cost'], 2),
                    ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _reportSectionTitle('Checks and compliance'),
        const SizedBox(height: 10),
        _Card(
          title: 'Completion by department',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(completion * 100).toStringAsFixed(0)}% verified',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: EnergiaColors.teal,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    '$completedChecks of $totalChecks checks',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: completion,
                  minHeight: 12,
                  color: EnergiaColors.teal,
                  backgroundColor: EnergiaColors.line,
                ),
              ),
              const SizedBox(height: 16),
              _ReportMiniTable(
                headers: const ['Department', 'Total', 'Done', 'Overdue', 'Review'],
                flexes: const [3, 1, 1, 1, 1],
                rows: [
                  for (final item in taskDepartments)
                    [
                      _reportText(item['department']),
                      _reportText(item['total'], '0'),
                      _reportText(item['completed'], '0'),
                      _reportText(item['overdue'], '0'),
                      _reportText(item['review'], '0'),
                    ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _reportSectionTitle('Attention register'),
        const SizedBox(height: 10),
        _Card(
          title: 'Alerts, findings, and work orders',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ReportMiniTable(
                headers: const ['Type', 'Item', 'Status / severity'],
                flexes: const [1, 3, 2],
                rows: attentionRows,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in _reportList(report['alerts_by_severity']))
                    Chip(
                      avatar: const Icon(Icons.warning_amber_rounded, size: 16),
                      label: Text(
                        'Alerts · ${_reportText(item['severity'])}: ${_reportText(item['total'], '0')}',
                      ),
                    ),
                  for (final item in _reportList(report['findings_by_severity']))
                    Chip(
                      avatar: const Icon(Icons.fact_check_outlined, size: 16),
                      label: Text(
                        'Findings · ${_reportText(item['severity'])}: ${_reportText(item['total'], '0')}',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportMetricCard extends StatelessWidget {
  const _ReportMetricCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
  });

  final String label;
  final String value;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EnergiaColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: EnergiaColors.deepNavy,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(caption, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ReportScoreBar extends StatelessWidget {
  const _ReportScoreBar({
    required this.label,
    required this.score,
    required this.provisional,
  });

  final String label;
  final double score;
  final bool provisional;

  @override
  Widget build(BuildContext context) {
    final color = _reportScoreColor(score);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 12,
                color: EnergiaColors.line,
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: (score / 100).clamp(0.0, 1.0),
                  child: Container(color: color),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 48,
            child: Text(
              score.toStringAsFixed(1),
              textAlign: TextAlign.right,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(
            width: 74,
            child: Text(
              provisional ? 'provisional' : 'current',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportMiniTable extends StatelessWidget {
  const _ReportMiniTable({
    required this.headers,
    required this.rows,
    this.flexes,
  });

  final List<String> headers;
  final List<List<String>> rows;
  final List<int>? flexes;

  int _flex(int index) =>
      flexes != null && index < flexes!.length ? flexes![index] : 1;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: EnergiaColors.deepNavy,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Row(
            children: [
              for (var index = 0; index < headers.length; index++)
                Expanded(
                  flex: _flex(index),
                  child: Text(
                    headers[index],
                    style: const TextStyle(
                      color: EnergiaColors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: EnergiaColors.line),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows.isEmpty
                ? const [
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('No rows in this section.'),
                    ),
                  ]
                : [
                    for (final row in rows)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: EnergiaColors.line),
                          ),
                        ),
                        child: Row(
                          children: [
                            for (var index = 0; index < headers.length; index++)
                              Expanded(
                                flex: _flex(index),
                                child: Text(
                                  index < row.length ? row[index] : '—',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
          ),
        ),
      ],
    );
  }
}

class _AlertsBundle {
  const _AlertsBundle({required this.alerts, required this.recommendations});

  final List<Map<String, Object?>> alerts;
  final List<Map<String, Object?>> recommendations;
}

class AlertsPage extends StatefulWidget {
  const AlertsPage({required this.repository, super.key});

  final AdminWorkspaceRepository repository;

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  late Future<_AlertsBundle> _future = _load();

  Future<_AlertsBundle> _load() async {
    final values = await Future.wait<Object>([
      widget.repository.resource('alerts'),
      widget.repository.resource('recommendations'),
    ]);
    return _AlertsBundle(
      alerts: values[0] as List<Map<String, Object?>>,
      recommendations: values[1] as List<Map<String, Object?>>,
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _setStatus(Map<String, Object?> alert, String status) async {
    final id = _idOf(alert);
    try {
      await widget.repository.updateResource('alerts', id, {'status': status});
      if (!mounted) return;
      _toast(context, 'Alert $id marked $status');
      _reload();
    } catch (error) {
      if (!mounted) return;
      _toast(context, 'Could not update alert: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const _PageHeader(
          title: 'Alerts and recommendations',
          subtitle: 'Triage anomaly alerts and review approved recommendations.',
        ),
        const SizedBox(height: 18),
        FutureBuilder<_AlertsBundle>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingCard();
            }
            if (snapshot.hasError) {
              return _ErrorCard(message: '${snapshot.error}', onRetry: _reload);
            }
            final data = snapshot.requireData;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Card(
                  title: 'Alerts (${data.alerts.length})',
                  child: data.alerts.isEmpty
                      ? const Text('No alerts require attention.')
                      : Column(
                          children: [
                            for (final alert in data.alerts)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: EnergiaColors.background,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: EnergiaColors.line),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _text(alert, const ['title', 'message']),
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      _InfoRow(
                                        label: 'Severity',
                                        value: _text(alert, const ['severity']),
                                      ),
                                      _InfoRow(
                                        label: 'Status',
                                        value: _text(alert, const ['status']),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          OutlinedButton.icon(
                                            key: Key('alert-ack-${_idOf(alert)}'),
                                            onPressed: () =>
                                                _setStatus(alert, 'acknowledged'),
                                            icon: const Icon(Icons.visibility_outlined, size: 17),
                                            label: const Text('Acknowledge'),
                                          ),
                                          const SizedBox(width: 8),
                                          FilledButton.icon(
                                            key: Key('alert-resolve-${_idOf(alert)}'),
                                            onPressed: () =>
                                                _setStatus(alert, 'resolved'),
                                            icon: const Icon(Icons.check, size: 17),
                                            label: const Text('Resolve'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                _Card(
                  title: 'Recommendations (${data.recommendations.length})',
                  child: data.recommendations.isEmpty
                      ? const Text('No recommendations recorded.')
                      : Column(
                          children: [
                            for (final recommendation in data.recommendations)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _InfoRow(
                                  label: _text(
                                    recommendation,
                                    const ['title', 'name'],
                                  ),
                                  value: _text(
                                    recommendation,
                                    const ['status', 'impact', 'saving'],
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _InventoryBundle {
  const _InventoryBundle({required this.assets, required this.candidates});

  final List<Map<String, Object?>> assets;
  final List<Map<String, Object?>> candidates;
}

class InventoryReviewPage extends StatefulWidget {
  const InventoryReviewPage({required this.repository, super.key});

  final AdminWorkspaceRepository repository;

  @override
  State<InventoryReviewPage> createState() => _InventoryReviewPageState();
}

class _InventoryReviewPageState extends State<InventoryReviewPage> {
  late Future<_InventoryBundle> _future = _load();

  Future<_InventoryBundle> _load() async {
    final values = await Future.wait<Object>([
      widget.repository.resource('assets'),
      widget.repository.resource('asset-candidates'),
    ]);
    return _InventoryBundle(
      assets: values[0] as List<Map<String, Object?>>,
      candidates: values[1] as List<Map<String, Object?>>,
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _review(Map<String, Object?> candidate, String action) async {
    final id = _idOf(candidate);
    try {
      await widget.repository.reviewCandidate(id, action);
      if (!mounted) return;
      _toast(context, 'Candidate $id $action');
      _reload();
    } catch (error) {
      if (!mounted) return;
      _toast(context, 'Could not review candidate: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const _PageHeader(
          title: 'Inventory review',
          subtitle: 'Verified assets and pending equipment candidates.',
        ),
        const SizedBox(height: 18),
        FutureBuilder<_InventoryBundle>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingCard();
            }
            if (snapshot.hasError) {
              return _ErrorCard(message: '${snapshot.error}', onRetry: _reload);
            }
            final data = snapshot.requireData;
            final pending = data.candidates.where((candidate) {
              final status = _text(candidate, const ['status']).toLowerCase();
              return status != 'approved' && status != 'rejected';
            }).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Card(
                  title: 'Verified assets',
                  child: Text(
                    '${data.assets.length} verified assets in the active inventory.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 14),
                _Card(
                  title: 'Pending candidates (${pending.length})',
                  child: pending.isEmpty
                      ? const Text('No candidates are awaiting review.')
                      : Column(
                          children: [
                            for (final candidate in pending)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: EnergiaColors.background,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: EnergiaColors.line),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _text(candidate, const ['name', 'title']),
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      _InfoRow(
                                        label: 'Status',
                                        value: _text(candidate, const ['status']),
                                      ),
                                      _InfoRow(
                                        label: 'Review reason',
                                        value: _text(
                                          candidate,
                                          const ['review_reason', 'reason'],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          FilledButton.icon(
                                            key: Key(
                                              'candidate-approve-${_idOf(candidate)}',
                                            ),
                                            onPressed: () =>
                                                _review(candidate, 'approve'),
                                            icon: const Icon(Icons.check, size: 17),
                                            label: const Text('Approve'),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            key: Key(
                                              'candidate-reject-${_idOf(candidate)}',
                                            ),
                                            onPressed: () =>
                                                _review(candidate, 'reject'),
                                            icon: const Icon(Icons.close, size: 17),
                                            label: const Text('Reject'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
