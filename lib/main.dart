import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:texting/config/theme.dart';
import 'package:texting/config/wallpapers.dart';
import 'package:texting/firebase_options.dart';
import 'package:texting/screens/app_lock_screen.dart';
import 'package:texting/screens/auth_screen.dart';
import 'package:texting/screens/home_screen.dart';
import 'package:texting/services/app_lock_service.dart';
import 'package:texting/services/auth_service.dart';
import 'package:texting/services/chat_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Enable Offline Persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ChatService()),
        ChangeNotifierProvider(create: (_) => AppLockService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App went to background
      Provider.of<AppLockService>(context, listen: false).lockApp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthService, AppLockService>(
      builder: (context, authService, appLockService, _) {
        final user = authService.currentUserModel;
        
        // Determine Theme based on Global Wallpaper
        String? globalWallpaperId = user?.globalWallpaperId; // Can be null
        WallpaperOption wallpaper = Wallpapers.getById(globalWallpaperId ?? 'crimson_eclipse'); // Default to Red
        
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'TeX',
          theme: StellarTheme.createTheme(wallpaper),
          home: Stack(
            children: [
              const AuthWrapper(),
              // Overlay Lock Screen if locked
               if (appLockService.isLocked)
                 const Positioned.fill(
                   child: AppLockScreen(),
                 ),
            ],
          ),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    return StreamBuilder(
      stream: authService.user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          return user == null ? const AuthScreen() : const HomeScreen();
        }
        return Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).primaryColor,
            ),
          ),
        );
      },
    );
  }
}
