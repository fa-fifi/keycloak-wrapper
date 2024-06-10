import 'dart:io';

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:keycloak_wrapper/keycloak_wrapper.dart';
import 'package:mockito/annotations.dart';

// Annotate with @GenerateMocks and list the classes you want to mock
@GenerateMocks([
  FlutterAppAuth,
  FlutterSecureStorage,
  HttpClient,
  HttpClientResponse,
  HttpClientRequest,
  HttpHeaders,
  KeycloakConfig,
])
void main() {}
