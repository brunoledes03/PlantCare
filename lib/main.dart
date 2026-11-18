// Importamos los componentes visuales de Material Design.
// Flutter 3.50 utiliza el paquete material_ui.
import 'package:material_ui/material_ui.dart';

// Importamos el administrador de navegacion de PlantCare.
import 'routes/app_routes.dart';

// Funcion principal de la aplicacion.
void main() {
  // Inicializa Flutter y la comunicacion con Android.
  WidgetsFlutterBinding.ensureInitialized();

  // Ejecuta nuestra aplicacion.
  runApp(const PlantCareApp());
}

// Widget principal de PlantCare.
class PlantCareApp extends StatelessWidget {
  const PlantCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Nombre de la aplicacion.
      title: 'PlantCare',

      // Oculta el indicador DEBUG.
      debugShowCheckedModeBanner: false,

      // Establece la apariencia general.
      theme: ThemeData(
        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),

        scaffoldBackgroundColor: const Color(0xFFF5F9F4),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ),

      // Ruta de inicio.
      initialRoute: AppRoutes.home,

      // Administrador de navegacion.
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
