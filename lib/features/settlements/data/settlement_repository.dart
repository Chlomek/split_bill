import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/local_store.dart';
import '../domain/settlement.dart';

/// Storage contract for recorded payments between group members.
abstract class SettlementRepository {
  Future<List<Settlement>> getSettlements(String groupId);

  Future<void> addSettlement(Settlement settlement);

  Future<void> deleteSettlement(String settlementId);
}

class LocalSettlementRepository implements SettlementRepository {
  final LocalStore _store;

  LocalSettlementRepository(this._store);

  @override
  Future<List<Settlement>> getSettlements(String groupId) async =>
      _store.settlements.where((s) => s.groupId == groupId).toList();

  @override
  Future<void> addSettlement(Settlement settlement) async {
    _store.settlements.add(settlement);
    await _store.save();
  }

  @override
  Future<void> deleteSettlement(String settlementId) async {
    _store.settlements.removeWhere((s) => s.id == settlementId);
    await _store.save();
  }
}

final settlementRepositoryProvider = Provider<SettlementRepository>(
  (ref) => LocalSettlementRepository(ref.watch(localStoreProvider)),
);
