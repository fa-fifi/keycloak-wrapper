import 'package:flutter/material.dart';
import 'package:keycloak_wrapper/keycloak_wrapper.dart';

final keycloakWrapper = KeycloakWrapper();
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize the plugin at the start of your app.
  await keycloakWrapper.initialize();
  // Listen to the errors caught by the plugin.
  keycloakWrapper.onError = (e, s) {
    // Display the error message inside a snackbar.
    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$e'),
        ),
      );
  };
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        scaffoldMessengerKey: scaffoldMessengerKey,
        // Listen to the user authentication stream.
        home: StreamBuilder<bool>(
          initialData: false,
          stream: keycloakWrapper.authenticationStream,
          builder: (context, snapshot) =>
              snapshot.data! ? const HomeScreen() : const LoginScreen(),
        ),
      );
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  // Logs user in using given configuration.
  Future<bool> login() async {
    final config = KeycloakConfig(
        bundleIdentifier: '<bundle_identifier>',
        clientId: '<client_id>',
        frontendUrl: '<frontend_url>',
        realm: '<realm>');

    // Check if user has successfully logged in.
    final isLoggedIn = await keycloakWrapper.login(config);

    return isLoggedIn;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: login,
            child: const Text('Login'),
          ),
        ),
      );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Logs user out from the current realm.
  Future<bool> logout() async {
    // Check if user has successfully logged out.
    final isLoggedOut = await keycloakWrapper.logout();

    return isLoggedOut;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: logout,
            child: const Text('Logout'),
          ),
        ),
      );
}
