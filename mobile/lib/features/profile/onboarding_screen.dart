import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../state/app_state.dart';
import '../../widgets/railway.dart';

/// Создание игрового профиля. Данные синтетические — реальных ПДн нет.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  String _brigade = 'Бригада №4';
  String _depot = 'Депо Москва-Октябрьская';

  static const _brigades = [
    'Бригада №1',
    'Бригада №2',
    'Бригада №3',
    'Бригада №4',
    'Бригада №5',
  ];

  static const _depots = [
    'Депо Москва-Октябрьская',
    'Депо Санкт-Петербург-Главное',
    'Депо Тверь',
  ];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CabinBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(VsmSpacing.screenPadding),
            children: [
              const SizedBox(height: 12),
              const DestinationBoard(
                subtitle: 'Регистрация на смену · данные учебные',
              ),
              const SizedBox(height: 22),
              Text(
                'Ваш профиль',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Имя, бригада и депо нужны для рейтинга. Это игровой аккаунт: '
                'реальных сотрудников и пассажиров здесь нет.',
                style: TextStyle(height: 1.45, color: VsmColors.textSecondary),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Как к вам обращаться',
                  hintText: 'Проводник А. Смирнов',
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _brigade,
                decoration: const InputDecoration(labelText: 'Бригада'),
                items: [
                  for (final brigade in _brigades)
                    DropdownMenuItem(value: brigade, child: Text(brigade)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _brigade = value);
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _depot,
                decoration: const InputDecoration(labelText: 'Депо'),
                items: [
                  for (final depot in _depots)
                    DropdownMenuItem(value: depot, child: Text(depot)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _depot = value);
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submit,
                child: const Text('Выйти на линию'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final name = _name.text.trim().isEmpty
        ? 'Проводник А. Смирнов'
        : _name.text.trim();
    await AppScope.read(
      context,
    ).createProfile(name: name, brigade: _brigade, depot: _depot);
  }
}
