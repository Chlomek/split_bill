import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/groups/presentation/group_detail_screen.dart';
import '../../features/groups/presentation/groups_screen.dart';
import '../../features/receipt_scan/domain/receipt_scan_result.dart';
import '../../features/receipt_scan/presentation/assign_items_screen.dart';
import '../../features/receipt_scan/presentation/scan_receipt_screen.dart';
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
            // Receipt capture
            GoRoute(
              path: 'scan',
              builder: (context, state) =>
                  ScanReceiptScreen(groupId: state.pathParameters['id'] ?? ''),
            ),
            // 3. Assign receipt items to members
            GoRoute(
              path: 'assign-items',
              builder: (context, state) => AssignItemsScreen(
                groupId: state.pathParameters['id'] ?? '',
                scanResult: state.extra as ReceiptScanResult?,
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
