import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Modalità immersiva - nasconde barre di sistema
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Permetti tutti gli orientamenti
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Inizializza FMTC per cache tiles offline
  await FMTCObjectBoxBackend().initialise();

  // Crea store per i tiles se non esiste
  const storeName = 'desertEyeMapStore';
  final store = FMTCStore(storeName);
  await store.manage.create();

  runApp(const DesertEyeApp());
}

class DesertEyeApp extends StatelessWidget {
  const DesertEyeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DesertEye',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
