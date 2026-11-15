import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../../../core/storage/local_store.dart';
import '../domain/user_profile.dart';

/// Storage contract for the person using this device.
abstract class ProfileRepository {
  /// Returns null until the user has entered a name (guest onboarding).
  Future<UserProfile?> getProfile();

  /// Creates the guest profile on first call, renames it afterwards.
  Future<UserProfile> saveName(String name);

  Future<String?> getIban();

  /// Stores the IBAN on this device only; null or empty removes it.
  Future<void> setIban(String? iban);
}

class LocalProfileRepository implements ProfileRepository {
  static const String _ibanKey = 'user_iban';

  final LocalStore _store;
  final FlutterSecureStorage _secureStorage;

  LocalProfileRepository(this._store, this._secureStorage);

  @override
  Future<UserProfile?> getProfile() async => _store.profile;

  @override
  Future<UserProfile> saveName(String name) async {
    final existing = _store.profile;
    final profile = UserProfile(
      id: existing?.id ?? const Uuid().v4(),
      email: existing?.email ?? '',
      name: name,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );
    _store.profile = profile;
    await _store.save();
    return profile;
  }

  // The IBAN deliberately lives in the platform keystore/keychain and is
  // never written to the JSON document or sent anywhere.
  @override
  Future<String?> getIban() => _secureStorage.read(key: _ibanKey);

  @override
  Future<void> setIban(String? iban) async {
    if (iban == null || iban.isEmpty) {
      await _secureStorage.delete(key: _ibanKey);
    } else {
      await _secureStorage.write(key: _ibanKey, value: iban);
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => LocalProfileRepository(
    ref.watch(localStoreProvider),
    const FlutterSecureStorage(),
  ),
);
