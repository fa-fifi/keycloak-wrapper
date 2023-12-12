part of '../keycloak_wrapper.dart';

/// Manages user authentication and token exchange using Keycloak.
///
/// It uses [KeycloakConfig] for configuration settings and relies on flutter_appauth package for OAuth2 authorization.
class KeycloakWrapper {
  KeycloakWrapper._();

  static KeycloakWrapper? _instance = KeycloakWrapper._();

  factory KeycloakWrapper() => _instance ??= KeycloakWrapper._();

  late final _streamController = StreamController<bool>();

  /// The stream of the user authentication state.
  ///
  /// Returns true if the user is currently logged in.
  Stream<bool> get authenticationStream => _streamController.stream;

  /// The details from making a successful token exchange.
  TokenResponse? tokenResponse;

  /// Called whenever an error gets caught.
  ///
  /// By default, all errors will be printed into the console.
  void Function(Object e, StackTrace s) onError = (e, s) => debugPrint('$e');

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

  /// Initializes the user authentication state and refresh token.
  Future<void> initialize() async {
    try {
      final securedRefreshToken =
          await _secureStorage.read(key: _refreshTokenKey);

      if (securedRefreshToken == null) {
        debugPrint('No refresh token found.');
        _streamController.add(false);
      } else {
        await KeycloakConfig.instance.initialize();

        final isConnected = await hasNetwork();

        if (isConnected) {
          tokenResponse = await _appAuth.token(TokenRequest(
              KeycloakConfig.instance.clientId,
              KeycloakConfig.instance.redirectUri,
              issuer: KeycloakConfig.instance.issuer,
              refreshToken: securedRefreshToken,
              allowInsecureConnections: true));

          await _secureStorage.write(
              key: _refreshTokenKey, value: refreshToken);

          debugPrint(
              '${tokenResponse.isValid ? 'Valid' : 'Invalid'} refresh token.');

          _streamController.add(tokenResponse.isValid);
        } else {
          _streamController.add(true);
        }
      }
    } catch (e, s) {
      debugPrint('An error occured during initialization.');
      onError(e, s);
    }
  }

  /// Logs the user in.
  ///
  /// Returns true if login is successful.
  Future<bool> login(KeycloakConfig config) async {
    try {
      tokenResponse = await _appAuth.authorizeAndExchangeCode(
          AuthorizationTokenRequest(config.clientId, config.redirectUri,
              issuer: config.issuer,
              scopes: ['openid', 'profile', 'email', 'offline_access'],
              promptValues: ['login'],
              allowInsecureConnections: true));

      if (tokenResponse.isValid) {
        if (refreshToken != null) {
          await _secureStorage.write(
              key: _refreshTokenKey, value: tokenResponse!.refreshToken);
        }
      } else {
        debugPrint('Invalid token response.');
      }

      _streamController.add(tokenResponse.isValid);
      return tokenResponse.isValid;
    } catch (e, s) {
      debugPrint('An error occured during logging user in.');
      onError(e, s);
      return false;
    }
  }

  /// Logs the user out.
  ///
  /// Returns true if logout is successful.
  Future<bool> logout() async {
    try {
      final request = EndSessionRequest(
          idTokenHint: idToken,
          issuer: KeycloakConfig.instance.issuer,
          postLogoutRedirectUrl: KeycloakConfig.instance.redirectUri,
          allowInsecureConnections: true);

      await _appAuth.endSession(request);
      await _secureStorage.deleteAll();

      _streamController.add(false);
      return true;
    } catch (e, s) {
      debugPrint('An error occured during logging user out.');
      onError(e, s);
      return false;
    }
  }

  /// Retrieves the current user information.
  Future<Map<String, dynamic>?> getUserInfo() async {
    try {
      final url = Uri.parse(
          '${KeycloakConfig.instance.issuer}/protocol/openid-connect/userinfo');
      final response = await getWithBearerAuthentication(url, accessToken);

      return response;
    } catch (e, s) {
      debugPrint('An error occured during fetching user info.');
      onError(e, s);
      return null;
    }
  }
}
