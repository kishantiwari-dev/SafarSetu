import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:safarsetu/data/local_demo_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'favourites persist by stable stop IDs and duplicate routes are prevented',
      () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final store = LocalDemoStore();
    const route = SavedRoute(
      fromStopId: 'KP_II',
      fromName: 'Knowledge Park II',
      toStopId: 'PARI_CHOWK',
      toName: 'Pari Chowk',
      routeId: 'SIM-GN-001',
    );
    await store.setFavourite(route, true);
    await store.setFavourite(route, true);
    final reopenedStore = LocalDemoStore();
    expect((await reopenedStore.loadFavourites()).map((item) => item.key),
        [route.key]);
    await reopenedStore.setFavourite(route, false);
    expect(await store.loadFavourites(), isEmpty);
  });

  test('profile preferences stay local and use a demo display name', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final store = LocalDemoStore();
    expect(await store.loadName(), 'Passenger');
    await store.saveProfile(name: 'Asha', email: 'asha@example.test');
    expect(await LocalDemoStore().loadName(), 'Asha');
    expect(await store.loadEmail(), 'asha@example.test');
    expect(await store.loadTransitModeEnabled(), isTrue);
    await store.saveTransitModeEnabled(false);
    expect(await store.loadTransitModeEnabled(), isFalse);
  });

  test(
      'recent journey survives store recreation and replay identity is stops, not trip',
      () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final store = LocalDemoStore();
    final journey = RecentJourney(
        fromStopId: 'ALPHA_1',
        fromName: 'Alpha 1',
        toStopId: 'BOTANICAL_GARDEN',
        toName: 'Botanical Garden',
        routeId: 'SIM-GN-009',
        tripId: 'TRIP-DEMO-A-01',
        searchedAt: DateTime.utc(2026));
    await store.recordJourney(journey);
    await store.recordJourney(journey);
    final saved = await LocalDemoStore().loadRecentJourneys();
    expect(saved, hasLength(1));
    expect(saved.single.fromStopId, 'ALPHA_1');
    expect(saved.single.tripId, 'TRIP-DEMO-A-01');
  });
}
