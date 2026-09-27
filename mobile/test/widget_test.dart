import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vsm_academy/app/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('приложение поднимает каталог сценариев', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const VsmAcademyApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Выйти на линию'), findsOneWidget);
    await tester.ensureVisible(find.text('Выйти на линию'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выйти на линию'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Ситуации на борту'), findsOneWidget);
    expect(find.textContaining('Ленинградский вокзал'), findsWidgets);
  });
}
