
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hawim/main.dart';
import 'package:hawim/firebase_options.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';

// 1. Create a fake that extends FirebasePlatform
class FakeFirebasePlatform extends FirebasePlatform {
  FakeFirebasePlatform() : super(); // Call super's const constructor

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return FakeFirebaseAppPlatform(
        name: name ?? '[DEFAULT]',
        options: options ?? DefaultFirebaseOptions.currentPlatform);
  }

  @override
  FirebaseAppPlatform app([String name = '[DEFAULT]']) {
    return FakeFirebaseAppPlatform(
        name: name, options: DefaultFirebaseOptions.currentPlatform);
  }

  @override
  List<FirebaseAppPlatform> get apps => [
        FakeFirebaseAppPlatform(
            name: '[DEFAULT]',
            options: DefaultFirebaseOptions.currentPlatform)
      ];
}

// 2. Create a fake that extends FirebaseAppPlatform
class FakeFirebaseAppPlatform extends FirebaseAppPlatform {
  FakeFirebaseAppPlatform({required String name, required FirebaseOptions options})
      : super(name, options); // Corrected: Use positional arguments

  @override
  Future<void> delete() async {
    // no-op
  }

  @override
  bool get isAutomaticDataCollectionEnabled => false;

  @override
  Future<void> setAutomaticDataCollectionEnabled(bool enabled) async {
    // no-op
  }

  @override
  Future<void> setAutomaticResourceManagementEnabled(bool enabled) async {
    // no-op
  }
}

void main() {
  // 3. Set up the test environment to use the fake implementation
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Firebase.delegatePackingProperty = FakeFirebasePlatform();
  });

  testWidgets('Login screen smoke test', (WidgetTester tester) => tester.runAsync(() async {
    // Build our app. Firebase.initializeApp() will use our FakeFirebasePlatform.
    await tester.pumpWidget(const MyApp());

    // Wait for all animations and async tasks to complete.
    await tester.pumpAndSettle();

    // Verify that the login screen title is displayed.
    expect(find.text('Inicio de Sesión'), findsOneWidget);
  }));
}
