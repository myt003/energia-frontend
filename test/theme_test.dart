import 'package:energia/core/theme/energia_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('Energia exposes the approved enterprise industrial palette exactly', () {
    expect(EnergiaColors.deepNavy.toARGB32(), 0xFF102A43);
    expect(EnergiaColors.teal.toARGB32(), 0xFF0F766E);
    expect(EnergiaColors.electricLime.toARGB32(), 0xFFA3E635);
    expect(EnergiaColors.background.toARGB32(), 0xFFF5F7FA);
    expect(EnergiaColors.white.toARGB32(), 0xFFFFFFFF);
    expect(EnergiaColors.slateNavy.toARGB32(), 0xFF172B4D);

    final theme = EnergiaTheme.light;
    expect(theme.scaffoldBackgroundColor, EnergiaColors.background);
    expect(theme.colorScheme.primary, EnergiaColors.teal);
    expect(theme.colorScheme.secondary, EnergiaColors.electricLime);
    expect(theme.colorScheme.onSurface, EnergiaColors.slateNavy);
    expect(theme.appBarTheme.backgroundColor, EnergiaColors.deepNavy);
    expect(theme.cardTheme.color, EnergiaColors.white);
    expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
  });
}
