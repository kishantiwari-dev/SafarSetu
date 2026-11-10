# Flutter and backend integration

Journey search and bus details can use the Spring Boot API. The app defaults to deterministic mock data; API mode is opt-in at launch. Login remains local validation only. Display name, profile notice preference, and saved routes are local demo data and are not synchronized.

## Run in mock mode

```powershell
flutter pub get
flutter run -d edge --dart-define=SAFARSETU_DATA_SOURCE=mock
```

## Run against the API

Start PostgreSQL and the backend using [backend/README.md](../backend/README.md), then start Flutter with:

```powershell
flutter run -d edge --dart-define=SAFARSETU_DATA_SOURCE=api --dart-define=SAFARSETU_API_BASE_URL=http://localhost:8080/api
```

The repository includes a Flutter Web runner in `web/`. The API base URL defaults to `http://localhost:8080/api`; that URL is appropriate for a web app served on the same computer. For an Android emulator, use `http://10.0.2.2:8080/api`. On a physical device, use the development computer's reachable LAN address and ensure the network/firewall permits the connection. Android/iOS runner directories are not currently present. Use HTTPS for deployed environments.

The existing backend CORS configuration permits Flutter Web origins matching `http://localhost:*` and `http://127.0.0.1:*` only. Other web origins, including LAN-hosted web apps, require an explicitly reviewed backend CORS configuration; production origins are not enabled by this integration.

API mode loads the backend stop suggestions and submits the chosen stop IDs, not typed stop names. Both stops must match a suggestion, and they must differ. Bus metadata, route stops, occupancy, and location are read from backend endpoints. Missing occupancy is shown as unknown. Seat availability is labeled provisional and follows the backend's one passenger per seat assumption. Location records are labeled simulated with their freshness; the app does not claim live GPS. Backend errors show a retry action. No automatic fallback to mock data occurs in API mode.

Search comparison requests occupancy separately for each matching bus at the selected boarding stop. The API response keeps `onboardPassengers` for compatibility and adds `ticketDerivedOnboardPassengers`, `confirmedReservedPassengers`, and `remainingPassengerCapacity` for the selected bus/trip/segment. The UI labels ticket-derived occupancy and reservations separately; reservations are not reported as passengers physically onboard. Remaining passenger capacity is the total passenger capacity minus the unique ticket and still-confirmed reservation load for that segment. Ambiguous trips show unknown trip-scoped values. Per-bus occupancy failures leave the bus visible with unknown comparison data. Crowding category and provisional seat availability remain ticket-derived; the separate capacity remaining value includes reservations. Crowding alternatives are only presented for a selected bus with fresh, real-source high/nearly-full occupancy; candidates must serve the same searched journey and have fresh, known, lower crowding. Simulated or missing data never qualifies as a less-crowded alternative.

## Map, profile, favourites, and occupancy

Bus details render an interactive `flutter_map` map with OpenStreetMap tiles (attribution shown on the map), pan/zoom, route stop markers, and a simulated location marker when the backend or mock fixture has one. The existing pilot coordinates are marked `APPROXIMATE`; any line drawn through them is called a schematic route and is not road routing. No map API key is required. Internet access is needed for tiles. OpenStreetMap's standard tile endpoint is used for this prototype; follow its [tile usage policy](https://operations.osmfoundation.org/policies/tiles/) including attribution and caching expectations, and choose a contracted tile provider before production traffic. Android/iOS runner folders are absent in this repository; the map and storage packages support Flutter Web and common mobile platforms, but only the existing Web runner is currently configured here. The Google Maps button opens external directions based on the journey stop names; it does not assert that Google Maps follows the simulated route.

Favourites use `shared_preferences` local browser/device storage, keyed by origin and destination stop IDs with display names retained for presentation. Duplicate stop pairs are prevented. Removed or malformed local entries are ignored safely. The profile stores a local display name and a Google Maps travel-mode preference; the email shown is the address entered for the current local demo login. No identity provider, password storage, backend profile, or cross-device synchronization exists. Returning to the login screen is local navigation only. Simulation and data-quality notices remain visible regardless of settings.

The client mock fixture mirrors the backend's 22 approximate stops and 8 simulated corridors and exposes 9 bus scenario records, including low/moderate/high/nearly-full passenger loads, missing ticket data, missing location, stale location, and one invalid passenger count which is withheld as unknown. Mock occupancy counts are scenario values, not ETM transactions. The backend's existing dev seed separately contains 18 simulated ticket events, 19 simulated location records, and 8 snapshots; this Flutter change does not alter database seed rows. Mock and API modes remain explicit and do not fall back into one another.

Occupancy values are withheld if the passenger count is negative or exceeds the stated total passenger capacity. Provisional available seats are shown only when they are within seating capacity and consistent with the displayed passenger estimate. Values are estimates, never observed seat inventory. Missing ticket data remains unknown; a missing/stale location is reported as such.

The HTTP client uses Dart's `http` package (`^1.2.2`) and an injectable client for tests. The package supports Flutter platforms and its version constraints remain compatible with this project's Dart SDK lower bound; package resolution selects the newest compatible release. See [pub.dev](https://pub.dev/packages/http).
