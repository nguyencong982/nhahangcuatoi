import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:menufood/firebase_options.dart';
import 'package:menufood/welcome/WelcomeScreen.dart';
import 'package:menufood/shared/cart_provider.dart';
import 'package:menufood/shared/favorite_provider.dart';
import 'package:menufood/home/customer_home_screen.dart';
import 'package:menufood/admin/admin_dashboard_screen.dart';
import 'package:menufood/home/shipper_home_screen.dart';
import 'package:menufood/welcome/choice_screen.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:menufood/welcome/loading_splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaV3Provider(
        '6LcoNyMsAAAAAJcU_712lcegsNjXwvxoNrrj_IaE',
      ),
    );
  } else {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kReleaseMode
          ? AndroidProvider.playIntegrity
          : AndroidProvider.debug,
    );
  }


  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => CartProvider()),
        ChangeNotifierProvider(create: (context) => FavoriteProvider()..loadFavorites()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Menu App',
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
        ),
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<Widget> _getStartingScreen() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final role = userDoc.data()?['role'];

          switch (role) {
            case 'admin':
            case 'manager':
              return const AdminDashboardScreen();
            case 'shipper':
              return const ShipperHomeScreen();
            default:
              return const ChoiceScreen();
          }
        } else {
          await FirebaseAuth.instance.signOut();
          return const WelcomeScreen();
        }
      } else {
        return const WelcomeScreen();
      }
    } catch (e) {
      debugPrint("AuthWrapper error: $e");
      return const WelcomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _getStartingScreen(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return snapshot.data ?? const WelcomeScreen();
        }
        return const LoadingSplashScreen();
      },
    );
  }
}
