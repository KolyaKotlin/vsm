import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsm_academy/app/app.dart';
import 'package:vsm_academy/data/scenario_repository.dart';
import 'package:vsm_academy/domain/scenario.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('без скачанного каталога приложение говорит, что нужна сеть', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      VsmAcademyApp(scenarioRepository: _EmptyRepository()),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Не удалось загрузить сценарии'), findsOneWidget);
    expect(find.textContaining('Каталог ещё не скачан'), findsOneWidget);
  });
}

class _EmptyRepository implements ScenarioRepository {
  @override
  Future<List<Scenario>> loadScenarios() {
    throw Exception(
      'Каталог ещё не скачан. Подключитесь к сети и откройте приложение ещё раз — потом он останется на телефоне.',
    );
  }
}
