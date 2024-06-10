import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycloak_wrapper/keycloak_wrapper.dart';
import 'package:mockito/mockito.dart';

import '../global_mocks.mocks.dart';

void main() {
  late KeycloakWrapper keycloakWrapper;
  late MockFlutterAppAuth mockAppAuth;
  late MockFlutterSecureStorage mockSecureStorage;
  late MockHttpClient mockHttpClient;
  late MockKeycloakConfig mockKeycloakConfig;

  setUp(() {
    mockAppAuth = MockFlutterAppAuth();
    mockSecureStorage = MockFlutterSecureStorage();
    mockHttpClient = MockHttpClient();
    mockKeycloakConfig = MockKeycloakConfig();

    keycloakWrapper = KeycloakWrapper(
      appAuth: mockAppAuth,
      secureStorage: mockSecureStorage,
      httpClient: mockHttpClient,
      keycloakConfig: mockKeycloakConfig,
    );
  });

  group('KeycloakWrapper', () {
    test(
        'GIVEN -> "securedRefreshToken" is found in secure storage '
        '         AND KeycloackConfig is initialized correctly '
        '         AND device has network '
        'WHEN ->  KeycloackWrapper.initialize() is called '
        'THEN ->  Initialization flow is correct and refresh token is stored '
        '         successfully'
        ' ', () async {
      when(mockSecureStorage.read(key: anyNamed('key')))
          .thenAnswer((_) async => 'some_refresh_token');
      when(mockAppAuth.token(any)).thenAnswer(
        (_) async => TokenResponse(
          'access_token',
          'refresh_token_xyz',
          DateTime.now().add(const Duration(days: 1)),
          'id_token',
          'token_type',
          ['scope_1', 'scope_2'],
          {},
        ),
      );
      when(mockKeycloakConfig.initialize()).thenAnswer((_) => Future.value());

      when(mockKeycloakConfig.clientId).thenReturn('clientId');
      when(mockKeycloakConfig.redirectUri).thenReturn('redirectUri');
      when(mockKeycloakConfig.issuer).thenReturn('issuer');

      await keycloakWrapper.initialize();

      // correct key is used to access secure storage
      verify(mockSecureStorage.read(key: 'keycloak-refresh-token')).called(1);
      // flutterAppAuth .toke call is made
      verify(mockAppAuth.token(any)).called(1);
      // correct refresh token is written into secure storage
      verify(
        mockSecureStorage.write(
          key: 'keycloak-refresh-token',
          value: 'refresh_token_xyz',
        ),
      ).called(1);
    });
  });
}
