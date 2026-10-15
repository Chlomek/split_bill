import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/groups/presentation/groups_screen.dart';
import '../../features/receipt_scan/domain/receipt_scan_result.dart';
import '../../features/receipt_scan/presentation/assign_items_screen.dart';
import '../../features/receipt_scan/presentation/scan_receipt_screen.dart';
import '../../features/settlements/presentation/settlements_screen.dart';
import 'route_names.dart';

/// Application router configuration handling declarative routing and deep links.
final GoRouter appRouter = GoRouter(
  initialLocation: RouteNames.home,
  routes: [
    GoRoute(
      path: RouteNames.home,
      builder: (context, state) => const GroupsScreen(),
    ),
    GoRoute(
      path: RouteNames.scanReceipt,
      builder: (context, state) => const ScanReceiptScreen(),
    ),
    GoRoute(
      path: RouteNames.assignItems,
      builder: (context, state) {
        final scanResult = state.extra as ReceiptScanResult?;
        return AssignItemsScreen(scanResult: scanResult);
      },
    ),
    GoRoute(
      path: RouteNames.settlements,
      builder: (context, state) => const SettlementsScreen(),
    ),
    // Deep Link invitation handler (e.g. /invite/:code or splitbill://invite/:code)
    GoRoute(
      path: RouteNames.invite,
      builder: (context, state) {
        final code = state.pathParameters['code'] ?? '';
        return Scaffold(
          appBar: AppBar(title: const Text('Pozvánka do skupiny')),
          body: Center(
            child: Text('Připojování ke skupině s kódem: $code...'),
          ),
        );
      },
    ),
  ],
);
