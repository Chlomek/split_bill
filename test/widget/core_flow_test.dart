import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:split_bill/app.dart';
import 'package:split_bill/core/services/document_capture_service.dart';
import 'package:split_bill/core/storage/local_store.dart';

/// Drives the real screens through the core loop:
/// onboarding -> new group with a member without the app -> manual
/// expense -> demo receipt split person by person -> money arrived.
/// No camera in tests: capturing a receipt always fails.
class _NoCamera extends DocumentCaptureService {
  @override
  Future<List<File>> scanReceiptWithCamera({int maxPages = 3}) async =>
      throw StateError('No camera in tests');
}

/// Loads the app's bundled fonts so text is measured as on a phone.
Future<void> _loadFonts() async {
  const families = {
    'SchibstedGrotesk': ['Regular', 'Medium', 'SemiBold', 'Bold'],
    'IBMPlexMono': ['Regular', 'Medium', 'SemiBold'],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final weight in entry.value) {
      final bytes = File(
        'assets/fonts/${entry.key}-$weight.ttf',
      ).readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('core loop works end to end and is persisted', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          documentCaptureProvider.overrideWithValue(_NoCamera()),
        ],
        child: const SplitBillApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Guest onboarding: only a name is needed.
    expect(find.text('Jak ti říkají?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Kája');
    await tester.pump();
    await tester.tap(find.text('Začít'));
    await tester.pumpAndSettle();
    expect(find.text('Zatím žádná skupina'), findsOneWidget);

    // New group with Honza, who has no app yet.
    await tester.tap(find.text('Vytvořit první skupinu'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Např. Chata Krkonoše'),
      'Hory',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Jméno, třeba Pepa'),
      'Honza',
    );
    await tester.tap(find.text('Přidat'));
    await tester.pump();
    await tester.tap(find.text('Vytvořit skupinu'));
    await tester.pumpAndSettle();
    expect(find.text('Kód pozvánky'), findsOneWidget);
    await tester.tap(find.text('Otevřít skupinu'));
    await tester.pumpAndSettle();
    expect(find.text('Hory'), findsOneWidget);
    expect(find.text('bez aplikace · vyrovnáno'), findsOneWidget);

    // Manual expense: 300 paid by me, split between both -> Honza owes 150.
    await tester.tap(find.text('Zadat ručně'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '0'), '300');
    await tester.enterText(
      find.widgetWithText(TextField, 'Např. Taxi z letiště'),
      'Taxi',
    );
    await tester.pump();
    await tester.tap(find.text('Uložit výdaj'));
    await tester.pumpAndSettle();
    expect(find.text('150 Kč'), findsWidgets);

    // Receipt: the camera is not available in tests, so reading fails and
    // the development sample receipt is used (430 Kč, 4 lines).
    await tester.tap(find.text('Vyfotit účtenku'));
    await tester.pumpAndSettle();
    expect(find.text('Účtenku se nepodařilo přečíst'), findsOneWidget);
    await tester.tap(find.text('Ukázková účtenka (vývoj)'));
    await tester.pumpAndSettle();
    expect(find.text('0 z 4 rozděleno'), findsOneWidget);

    // Person first: "Ty" is selected; tap the pizza and two beers.
    await tester.tap(find.text('Pizza Margherita'));
    await tester.pump();
    await tester.tap(find.text('Plzeňské pivo 12°'));
    await tester.pump();
    await tester.tap(find.text('Plzeňské pivo 12°'));
    await tester.pump();

    // Honza had the other two beers and the lemonade.
    await tester.tap(find.widgetWithText(InkWell, 'Honza').last);
    await tester.pump();
    await tester.tap(find.text('Plzeňské pivo 12°'));
    await tester.pump();
    await tester.tap(find.text('Plzeňské pivo 12°'));
    await tester.pump();
    await tester.tap(find.text('Domácí limonáda'));
    await tester.pump();

    // The espresso is shared by everyone.
    await tester.tap(find.text('Všichni'));
    await tester.pump();
    await tester.tap(find.text('Espresso'));
    await tester.pump();
    expect(find.text('Vše rozděleno'), findsOneWidget);

    await tester.tap(find.text('Zkontrolovat'));
    await tester.pumpAndSettle();
    expect(find.text('Kdo ti kolik pošle'), findsOneWidget);
    // Honza: 2 beers (60) + lemonade (65) + half espresso (27.50) = 152.50.
    expect(find.text('152,50 Kč'), findsWidgets);
    await tester.tap(find.text('Uložit výdaj'));
    await tester.pumpAndSettle();

    // Back in the group: Honza owes 150 + 152.50 = 302.50.
    expect(find.text('Restaurace U Medvídka'), findsOneWidget);
    expect(find.text('302,50 Kč'), findsWidgets);

    // The money arrived.
    await tester.tap(find.text('Přišly peníze?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ano, přišly'));
    await tester.pumpAndSettle();
    expect(
      find.text('Vše je vyrovnáno, nikdo nikomu nic nedluží.'),
      findsOneWidget,
    );

    // Everything was written to on-device storage, receipt lines included.
    final reloaded = LocalStore(prefs);
    expect(reloaded.profile?.name, 'Kája');
    expect(reloaded.groups.single.name, 'Hory');
    expect(reloaded.members, hasLength(2));
    expect(
      reloaded.expenses.map((e) => e.title),
      containsAll(['Taxi', 'Restaurace U Medvídka']),
    );
    expect(reloaded.expenseItems, hasLength(4));
    expect(reloaded.settlements.single.amount, 302.5);
  });
}
