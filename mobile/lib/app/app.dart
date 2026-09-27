import 'package:flutter/material.dart';

import '../data/api_scenario_repository.dart';
import '../data/scenario_repository.dart';
import '../features/profile/onboarding_screen.dart';
import '../state/app_state.dart';
import '../widgets/railway.dart';
import 'home_shell.dart';
import 'theme.dart';

/// Корень приложения: создаёт [AppState], раздаёт его через [AppScope] и
/// держит экран загрузки, пока читаются сценарии и профиль.
class VsmAcademyApp extends StatefulWidget {
  const VsmAcademyApp({super.key, this.scenarioRepository});

  /// В приложении каталог берётся с сервера. Тест подставляет свой источник.
  final ScenarioRepository? scenarioRepository;

  @override
  State<VsmAcademyApp> createState() => _VsmAcademyAppState();
}

class _VsmAcademyAppState extends State<VsmAcademyApp>
    with WidgetsBindingObserver {
  // API_BASE задаётся при сборке: --dart-define=API_BASE=http://10.0.2.2:8000
  // 10.0.2.2 — это компьютер разработчика с точки зрения Android-эмулятора.
  late final AppState _state = AppState(
    scenarioRepository:
        widget.scenarioRepository ??
        ApiScenarioRepository(
          baseUrl: const String.fromEnvironment(
            'API_BASE',
            defaultValue: 'http://127.0.0.1:8000',
          ),
        ),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _state.bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _state.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Сеть могла появиться, пока приложение было свёрнуто: каталог обновляется
    // и заменяет сохранённую копию. Без сети остаётся то, что уже скачано.
    if (state == AppLifecycleState.resumed) {
      _state.refreshScenarios();
    }
  }

  @override
  Widget build(BuildContext context) {
    // AppScope обязан быть *над* MaterialApp. Иначе любой Navigator.push
    // открывает маршрут рядом с home, а не внутри scope — и плеер падает.
    return AppScope(
      state: _state,
      child: MaterialApp(
        title: 'ВСМ',
        debugShowCheckedModeBanner: false,
        theme: buildVsmTheme(),
        home: const _Bootstrap(),
      ),
    );
  }
}

class _Bootstrap extends StatelessWidget {
  const _Bootstrap();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    if (state.isLoading) return const _SplashScreen();
    if (state.loadError != null) {
      return _LoadErrorScreen(
        error: state.loadError!,
        onRetry: state.bootstrap,
      );
    }
    if (!state.profile.created) return const OnboardingScreen();
    return const HomeShell();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: CabinBackground(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DestinationBoard(
                  subtitle: 'Тренажёр проводника · посадка открыта',
                ),
                SizedBox(height: 28),
                SizedBox(
                  width: 160,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: VsmColors.stroke,
                    color: VsmColors.brand,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadErrorScreen extends StatelessWidget {
  const _LoadErrorScreen({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 44,
                color: VsmColors.danger,
              ),
              const SizedBox(height: 16),
              Text(
                'Не удалось загрузить сценарии',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString().replaceFirst('Exception: ', ''),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: onRetry, child: const Text('Повторить')),
            ],
          ),
        ),
      ),
    );
  }
}
