import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/expenses/presentation/expense_detail_screen.dart';
import '../../features/groups/presentation/group_detail_screen.dart';
import '../../features/groups/presentation/groups_screen.dart';
import '../../features/receipt_scan/presentation/assign_items_screen.dart';
import '../../features/receipt_scan/presentation/scan_receipt_screen.dart';
import '../../features/settlements/presentation/qr_payment_screen.dart';
import 'route_names.dart';

/// Application router configuration handling declarative routing and deep links.
///
/// Routes are nested so that navigating straight to a group (or back to it
/// after saving an expense) always keeps the screens below it on the stack.
final GoRouter appRouter = GoRouter(
  initialLocation: RouteNames.home,
  routes: [
    // 1. My groups (also shows guest onboarding on first launch)
    GoRoute(
      path: RouteNames.home,
      builder: (context, state) => const GroupsScreen(),
      routes: [
        // 2. Group detail & settlement hub
        GoRoute(
          path: 'group/:id',
          builder: (context, state) =>
              GroupDetailScreen(groupId: state.pathParameters['id'] ?? ''),
          routes: [
            // Receipt capture and reading
            GoRoute(
              path: 'scan',
              builder: (context, state) =>
                  ScanReceiptScreen(groupId: state.pathParameters['id'] ?? ''),
            ),
            // 3. Assign receipt items to members (person first)
            GoRoute(
              path: 'assign-items',
              builder: (context, state) => AssignItemsScreen(
                groupId: state.pathParameters['id'] ?? '',
                args: state.extra is AssignItemsArgs
                    ? state.extra! as AssignItemsArgs
                    : const AssignItemsArgs(),
              ),
            ),
            // Expense detail
            GoRoute(
              path: 'expense/:expenseId',
              builder: (context, state) => ExpenseDetailScreen(
                groupId: state.pathParameters['id'] ?? '',
                expenseId: state.pathParameters['expenseId'] ?? '',
              ),
            ),
            // QR payment shown by the person being paid
            GoRoute(
              path: 'qr',
              builder: (context, state) => QrPaymentScreen(
                groupId: state.pathParameters['id'] ?? '',
                fromMemberId: state.uri.queryParameters['from'],
              ),
            ),
          ],
        ),

        // Invitation deep link (/invite/:code or splitbill://invite/:code).
        // Joining needs online sync, which arrives with the Supabase backend.
        GoRoute(
          path: 'invite/:code',
          builder: (context, state) {
            final code = state.pathParameters['code'] ?? '';
            return Scaffold(
              appBar: AppBar(title: const Text('Pozvánka do skupiny')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Pozvánka s kódem $code.\n\nPřipojení ke skupině bude '
                    'dostupné po zapnutí online synchronizace.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    ),
  ],
);
