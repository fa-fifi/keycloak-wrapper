part of '../keycloak_wrapper.dart';

/// Manages user authentication and token exchange using Keycloak.
///
/// It uses [KeycloakConfig] for configuration settings and relies on flutter_appauth package for OAuth2 authorization.
class KeycloakWrapper {
  final FlutterAppAuth _appAuth;
  final FlutterSecureStorage _secureStorage;
  final HttpClient _httpClient;
  final KeycloakConfig _keycloakConfig;

  static KeycloakWrapper? _instance;

  factory KeycloakWrapper({
    FlutterAppAuth? appAuth,
    FlutterSecureStorage? secureStorage,
    HttpClient? httpClient,
    required KeycloakConfig keycloakConfig,
  }) {
    _instance ??= KeycloakWrapper._(
      appAuth ?? const FlutterAppAuth(),
      secureStorage ?? const FlutterSecureStorage(),
      httpClient ?? HttpClient(),
      keycloakConfig,
    );
    return _instance!;
  }

  KeycloakWrapper._(
    this._appAuth,
    this._secureStorage,
    this._httpClient,
    this._keycloakConfig,
  );

  late final _streamController = StreamController<bool>();

  bool _isInitialized = false;

  /// Called whenever an error gets caught.
  ///
  /// By default, all errors will be printed into the console.
  void Function(Object e, StackTrace s) onError = (e, s) => developer.log(
        "Oops, something went wrong! ಠ_ಠ\n"
        "If you need help, feel free to open a discussion on our Github repository at\n"
        "https://github.com/fa-fifi/keycloak_wrapper/discussions.",
        name: 'keycloak_wrapper',
        error: e,
        stackTrace: s,
      );

  /// The details from making a successful token exchange.
  TokenResponse? tokenResponse;

  /// The stream of the user authentication state.
  ///
  /// Returns true if the user is currently logged in.
  Stream<bool> get authenticationStream => _streamController.stream;

  /// Whether this package has been initialized.
  bool get isInitialized => _isInitialized;

  /// Returns the id token string.
  ///
  /// To get the payload, do `jwtDecode(KeycloakWrapper().idToken)`.
  String? get idToken => tokenResponse?.idToken;

  /// Returns the access token string.
  ///
  /// To get the payload, do `jwtDecode(KeycloakWrapper().accessToken)`.
  String? get accessToken => tokenResponse?.accessToken;

  /// Returns the refresh token string.
  ///
  /// To get the payload, do `jwtDecode(KeycloakWrapper().refreshToken)`.
  String? get refreshToken => tokenResponse?.refreshToken;

  void _assert() {
    const message =
        'Make sure the package has been initialized prior to calling this method.';

    assert(_isInitialized, message);
  }

  /// Initializes the user authentication state and refresh token.
  Future<void> initialize() async {
    try {
      final securedRefreshToken =
          await _secureStorage.read(key: _refreshTokenKey);

      if (securedRefreshToken == null) {
        debugPrint('No refresh token found.');
        _streamController.add(false);
      } else {
        await _keycloakConfig.initialize();

        final isConnected = await hasNetwork();

        if (isConnected) {
          tokenResponse = await _appAuth.token(
            TokenRequest(
              _keycloakConfig.clientId,
              _keycloakConfig.redirectUri,
              issuer: _keycloakConfig.issuer,
              refreshToken: securedRefreshToken,
              allowInsecureConnections: true,
            ),
          );

          await _secureStorage.write(
            key: _refreshTokenKey,
            value: refreshToken,
          );

          debugPrint(
            '${tokenResponse.isValid ? 'Valid' : 'Invalid'} refresh token.',
          );

          _streamController.add(tokenResponse.isValid);
        } else {
          _streamController.add(true);
        }
      }

      _isInitialized = true;
    } catch (e, s) {
      onError(e, s);
    }
  }

  /// Logs the user in.
  ///
  /// Returns true if login is successful.
  Future<bool> login(KeycloakConfig config) async {
    _assert();
    try {
      tokenResponse = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          config.clientId,
          config.redirectUri,
          issuer: config.issuer,
          scopes: ['openid', 'profile', 'email', 'offline_access'],
          promptValues: ['login'],
          allowInsecureConnections: true,
        ),
      );

      if (tokenResponse.isValid) {
        if (refreshToken != null) {
          await _secureStorage.write(
            key: _refreshTokenKey,
            value: tokenResponse!.refreshToken,
          );
        }
      } else {
        debugPrint('Invalid token response.');
      }

      _streamController.add(tokenResponse.isValid);
      return tokenResponse.isValid;
    } catch (e, s) {
      onError(e, s);
      return false;
    }
  }

  /// Logs the user out.
  ///
  /// Returns true if logout is successful.
  Future<bool> logout() async {
    _assert();
    try {
      final request = EndSessionRequest(
        idTokenHint: idToken,
        issuer: _keycloakConfig.issuer,
        postLogoutRedirectUrl: _keycloakConfig.redirectUri,
        allowInsecureConnections: true,
      );

      await _appAuth.endSession(request);
      await _secureStorage.deleteAll();
      _streamController.add(false);
      return true;
    } catch (e, s) {
      onError(e, s);
      return false;
    }
  }

  /// Retrieves the current user information.
  Future<Map<String, dynamic>?> getUserInfo() async {
    _assert();
    try {
      final url = Uri.parse(
        '${_keycloakConfig.issuer}/protocol/openid-connect/userinfo',
      );
      final request = await _httpClient.getUrl(url)
        ..headers.add(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      _httpClient.close();
      return jsonDecode(responseBody) as Map<String, dynamic>?;
    } catch (e, s) {
      onError(e, s);
      return null;
    }
  }
}
