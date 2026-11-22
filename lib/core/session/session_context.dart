import '../api/energia_api_client.dart';

class SessionContext {
  const SessionContext({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.organizationId,
    required this.organizationName,
    required this.siteId,
    required this.siteName,
    required this.role,
    required this.isAdministrator,
  });

  final int userId;
  final String username;
  final String displayName;
  final int organizationId;
  final String organizationName;
  final int siteId;
  final String siteName;
  final String role;
  final bool isAdministrator;
}

abstract interface class SessionContextRepository {
  Future<SessionContext> load();
}

class ApiSessionContextRepository implements SessionContextRepository {
  ApiSessionContextRepository(this._client);

  final EnergiaApiClient _client;

  @override
  Future<SessionContext> load() async {
    final payload = await _client.getJson('me/');
    final user = (payload['user'] as Map).cast<String, Object?>();
    final organization = (payload['organization'] as Map)
        .cast<String, Object?>();
    final site = (payload['site'] as Map).cast<String, Object?>();
    return SessionContext(
      userId: user['id'] as int,
      username: user['username'] as String,
      displayName: user['name'] as String,
      organizationId: organization['id'] as int,
      organizationName: organization['name'] as String,
      siteId: site['id'] as int,
      siteName: site['name'] as String,
      role: payload['role'] as String,
      isAdministrator: payload['is_administrator'] as bool? ?? false,
    );
  }
}

class StaticSessionContextRepository implements SessionContextRepository {
  const StaticSessionContextRepository(this.context);

  final SessionContext context;

  @override
  Future<SessionContext> load() async => context;
}
