import 'api_bus_repository.dart';
import 'api_client.dart';
import 'bus_repository.dart';
import 'mock_bus_repository.dart';

const _dataSource = String.fromEnvironment(
  'SAFARSETU_DATA_SOURCE',
  defaultValue: 'mock',
);

BusRepository createBusRepository() {
  if (_dataSource.toLowerCase() == 'api') {
    return ApiBusRepository(ApiClient(baseUrl: ApiClient.configuredBaseUrl));
  }
  return const MockBusRepository();
}
