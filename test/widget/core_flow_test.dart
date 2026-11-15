import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill/app.dart';
import 'package:split_bill/core/storage/local_store.dart';

/// Drives the real screens through the core loop:
/// onboarding -> group -> member without account -> manual expense ->
/// demo receipt with item assignment -> mark as paid.
void main() {
  testWidgets('core loop works end to end and is persisted', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const SplitBillApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Guest onboarding: only a name is needed.
    expect(find.text('Vítejte ve Split Bill'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Kája');
    await tester.pump();
    await tester.tap(find.text('Začít'));
    await tester.pumpAndSettle();
    expect(find.text('Zatím nemáte žádnou skupinu'), findsOneWidget);

    // Create a group; the app opens it straight away.
    await tester.tap(find.text('Nová skupina'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hory');
    await tester.tap(find.text('Vytvořit'));
    await tester.pumpAndSettle();
    expect(find.text('Hory'), findsOneWidget);
    expect(find.text('Vy'), findsOneWidget);

    // Add a friend who has no account.
    await tester.tap(find.text('Přidat člena bez účtu'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Honza');
    await tester.tap(find.text('Přidat'));
    await tester.pumpAndSettle();
    expect(find.text('bez účtu'), findsOneWidget);

    // Manual expense: 300 paid by me, split between both -> Honza owes 150.
    await tester.tap(find.text('Zadat ručně'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Název'), 'Taxi');
    await tester.enterText(find.widgetWithText(TextField, 'Částka (Kč)'), '300');
    await tester.tap(find.text('Uložit výdaj'));
    await tester.pumpAndSettle();
    expect(find.text('Honza ➔ Kája'), findsOneWidget);
    expect(find.textContaining('150,00'), findsWidgets);

    // Demo receipt (430 Kč): everything shared by both -> Honza owes 215 more.
    await tester.tap(find.text('Vyfotit účtenku'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Otestovat s ukázkovou účtenkou (Demo)'));
    await tester.pumpAndSettle();
    expect(find.text('Zbývá přiřadit položek: 4'), findsOneWidget);

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Všichni').first);
      await tester.pump();
    }
    await tester.tap(find.text('Potvrdit a rozpočítat'));
    await tester.pumpAndSettle();

    expect(find.text('Restaurace U Medvídka'), findsOneWidget);
    expect(find.textContaining('365,00'), findsWidgets);

    // Mark the debt as paid -> the group is settled.
    await tester.tap(find.widgetWithText(TextButton, 'Zaplaceno'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Zaplaceno'));
    await tester.pumpAndSettle();
    expect(
      find.text('Vše je vyrovnáno, nikdo nikomu nic nedluží.'),
      findsOneWidget,
    );

    // Everything was written to on-device storage.
    final reloaded = LocalStore(prefs);
    expect(reloaded.profile?.name, 'Kája');
    expect(reloaded.groups.single.name, 'Hory');
    expect(reloaded.members, hasLength(2));
    expect(reloaded.expenses.map((e) => e.title),
        containsAll(['Taxi', 'Restaurace U Medvídka']));
    expect(reloaded.settlements.single.amount, 365.0);
  });
}
