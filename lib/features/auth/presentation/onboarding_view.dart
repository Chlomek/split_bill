import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/theme.dart';
import '../../../core/ui/receipt_widgets.dart';
import '../../groups/application/group_providers.dart';

/// First-launch screen: guest mode only needs a display name.
class OnboardingView extends ConsumerStatefulWidget {
  const OnboardingView({super.key});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final name = _controller.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    await ref.read(groupActionsProvider).saveProfile(name: name);
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _controller.text.trim().isNotEmpty && !_saving;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 56, 28, 16),
                children: [
                  Slip(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
                    child: Column(
                      children: [
                        Text(
                          'SPLIT BILL',
                          style: AppFonts.money(
                            size: 13,
                            color: AppColors.muted,
                          ).copyWith(letterSpacing: 2),
                        ),
                        const SizedBox(height: 10),
                        const DashedRule(),
                        const SizedBox(height: 12),
                        const Text(
                          'Vyfoť účtenku, rozdělte položky a hned víte, kdo '
                          'komu kolik pošle.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  const Text(
                    'Jak ti říkají?',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Stačí jméno, registrace není potřeba.',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.mutedStrong,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _continue(),
                    decoration: const InputDecoration(hintText: 'Např. Kája'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Začít',
                  onPressed: canContinue ? _continue : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
