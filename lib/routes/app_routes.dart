// Importamos los componentes de navegacion de Flutter.
import 'package:material_ui/material_ui.dart';

// Importamos el modelo de plantas.
import '../models/plant.dart';

// Importamos las cuatro pantallas de PlantCare.
import '../screens/home_screen.dart';
import '../screens/new_plant_screen.dart';
import '../screens/detail_screen.dart';
import '../screens/new_care_entry_screen.dart';

// Esta clase administra las rutas de PlantCare.
//
// Su responsabilidad es definir que pantalla
// debe abrirse cuando Navigator recibe una ruta.
class AppRoutes {
  // Pantalla principal con la lista de plantas.
  static const String home = '/';

  // Formulario para registrar una planta nueva.
  static const String newPlant = '/new';

  // Pantalla con informacion y bitacora de una planta.
  static const String detail = '/detail';

  // Formulario de nuevas observaciones.
  static const String newCareEntry = '/care/new';

  // Genera una pantalla a partir de su nombre de ruta.
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      // -----------------------------------------
      // PANTALLA PRINCIPAL
      // -----------------------------------------
      case home:
        return MaterialPageRoute(
          settings: settings,

          builder: (context) => const HomeScreen(),
        );

      // -----------------------------------------
      // FORMULARIO DE NUEVA PLANTA
      // -----------------------------------------
      case newPlant:
        return MaterialPageRoute(
          settings: settings,

          builder: (context) => const NewPlantScreen(),
        );

      // -----------------------------------------
      // DETALLE DE PLANTA
      // -----------------------------------------
      case detail:
        // Recuperamos los datos que envio HomeScreen.
        final argument = settings.arguments;

        // Comprobamos que el argumento sea una planta.
        if (argument is Plant) {
          return MaterialPageRoute(
            settings: settings,

            // Entregamos la planta seleccionada al detalle.
            builder: (context) => DetailScreen(plant: argument),
          );
        }

        break;

      // -----------------------------------------
      // NUEVA ENTRADA DE BITACORA
      // -----------------------------------------
      case newCareEntry:
        // Obtenemos el identificador enviado desde DetailScreen.
        final argument = settings.arguments;

        // Cada observacion debe pertenecer a una planta.
        if (argument is int) {
          return MaterialPageRoute(
            settings: settings,

            builder: (context) => NewCareEntryScreen(plantId: argument),
          );
        }

        break;
    }

    // Si la ruta es incorrecta o falta un argumento,
    // mostramos una pantalla de respaldo.
    return MaterialPageRoute(
      settings: settings,

      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Error de navegacion')),

        body: const Center(
          child: Text('No se pudo abrir la pantalla solicitada.'),
        ),
      ),
    );
  }
}
