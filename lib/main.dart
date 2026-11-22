import 'package:material_ui/material_ui.dart';

import 'bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const apiBaseUrl = String.fromEnvironment(
    'ENERGIA_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );
  runApp(const EnergiaBootstrap(apiBaseUrl: apiBaseUrl));
}
