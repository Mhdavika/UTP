import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:utp_flutter/firebase_options.dart';
import 'pages/login_page.dart';
import 'pages/otp_page.dart';
import 'pages/home_page.dart';
import 'pages/favorite_page.dart';
import 'pages/pesan_page.dart';
import 'pages/profile_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // WAJIB

  // INIT SUPABASE
  await Supabase.initialize(
    url: 'https://avztxkkbefvxfftvodui.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF2enR4a2tiZWZ2eGZmdHZvZHVpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQzOTMzMjUsImV4cCI6MjA3OTk2OTMyNX0.liN7spnWnbKUXsKPS6IgbN5z09AR0gD61bwpLoi5aTE',
  );

  // INIT FIREBASE
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // THEME GLOBAL
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey,
        ),
        canvasColor: Colors.white,
        useMaterial3: false,
      ),

      home: LoginPage(),

      routes: {
        '/otp': (context) => const OtpPage(phoneNumber: ''),
        '/main': (context) => const MainPage(),
      },
    );
  }
}

///  MAIN PAGE (Bottom Navigation)
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  final List<Widget> pages = [
    HomePage(),
    FavoritePage(),
    const PesanPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Home"),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            label: "Favorit",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: "Pesan",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Profil",
          ),
        ],
      ),
    );
  }
}
