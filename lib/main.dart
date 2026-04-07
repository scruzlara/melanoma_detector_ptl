import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'donnees/depots/depot_analyse_hive.dart';
import 'donnees/modeles/modele_analyse_hive.dart';
import 'presentation/pages/page_accueil.dart';
import 'presentation/providers/provider_melanome.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';

/// Point d'entrée de l'application Détecteur de Mélanome.
///
/// Initialise le [ThemeService] (préférence persistée) et Hive
/// (base de données locale) avant de lancer l'interface.
/// Aucune donnée n'est envoyée hors de l'appareil.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Charger les variables d'environnement
  await dotenv.load(fileName: ".env");

  // Initialiser les formats de date (intl)
  await initializeDateFormatting('fr_FR', null);

  // Initialiser Hive
  await Hive.initFlutter();
  Hive.registerAdapter(ModeleAnalyseHiveAdapter());

  // Initialiser le dépôt
  final depot = DepotAnalyseHive();
  await depot.initialiser();

  // Initialiser le thème
  final themeService = ThemeService();
  await themeService.init();

  runApp(
    ApplicationDetecteurMelanome(themeService: themeService, depot: depot),
  );
}

/// Application principale — Détecteur de Mélanome.
///
/// Utilise un [ListenableBuilder] pour reconstruire le [MaterialApp]
/// à chaque changement de thème, sans dépendance externe.
class ApplicationDetecteurMelanome extends StatefulWidget {
  /// Service de gestion du thème (clair / sombre / système).
  final ThemeService themeService;

  /// Dépôt d'analyses sauvegardées.
  final DepotAnalyseHive depot;

  const ApplicationDetecteurMelanome({
    super.key,
    required this.themeService,
    required this.depot,
  });

  @override
  State<ApplicationDetecteurMelanome> createState() =>
      _ApplicationDetecteurMelanomeState();
}

class _ApplicationDetecteurMelanomeState
    extends State<ApplicationDetecteurMelanome> {
  /// Gestionnaire d'état global de l'application.
  late final ProviderMelanome _provider;

  @override
  void initState() {
    super.initState();
    _provider = ProviderMelanome(depot: widget.depot);
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.themeService,
      builder: (context, _) {
        return MaterialApp(
          title: 'DermAI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: widget.themeService.themeMode,
          home: PageAccueil(
            provider: _provider,
            themeService: widget.themeService,
          ),
        );
      },
    );
  }
}
