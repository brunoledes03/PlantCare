// Componentes visuales de Flutter.
import 'package:material_ui/material_ui.dart';

// Base de datos SQLite.
import '../data/plant_database.dart';

// Modelo de las plantas.
import '../models/plant.dart';

// Rutas de navegacion.
import '../routes/app_routes.dart';

// Widget reutilizable para mostrar cada planta.
import '../widgets/plant_card.dart';

// Pantalla principal de PlantCare.
//
// StatefulWidget permite actualizar la lista cuando
// se agrega, modifica o elimina una planta.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Future que contiene la consulta a SQLite.
  //
  // FutureBuilder observara esta operacion
  // para mostrar los registros cuando terminen de cargarse.
  late Future<List<Plant>> _plantsFuture;

  @override
  void initState() {
    super.initState();

    // Cargamos las plantas al entrar a la pantalla.
    _plantsFuture = PlantDatabase.instance.getPlants();
  }

  // Consulta nuevamente la base de datos.
  //
  // Se utiliza al regresar de otra pantalla
  // o al presionar el boton de actualizar.
  void _reloadPlants() {
    setState(() {
      _plantsFuture = PlantDatabase.instance.getPlants();
    });
  }

  // Actualizacion al deslizar hacia abajo.
  Future<void> _refreshPlants() async {
    // Creamos una nueva consulta.
    final newFuture = PlantDatabase.instance.getPlants();

    // FutureBuilder recibira el nuevo Future.
    setState(() {
      _plantsFuture = newFuture;
    });

    try {
      await newFuture;
    } catch (_) {
      // FutureBuilder mostrara el error de la consulta.
    }
  }

  // Abre el formulario de registro.
  Future<void> _openNewPlant() async {
    // Navigator abre la ruta registrada en AppRoutes.
    final result = await Navigator.pushNamed(context, AppRoutes.newPlant);

    // Si el formulario informa que se guardo una planta,
    // actualizamos la lista de SQLite.
    if (mounted && result == true) {
      _reloadPlants();
    }
  }

  // Abre la pantalla de detalle de una planta.
  Future<void> _openPlantDetail(Plant plant) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.detail,

      // Enviamos la planta seleccionada a la otra pantalla.
      arguments: plant,
    );

    // Al regresar consultamos SQLite nuevamente.
    // Asi se reflejan los riegos y cambios realizados.
    if (mounted) {
      _reloadPlants();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Barra de navegacion superior.
      appBar: AppBar(
        title: const Text('PlantCare'),

        actions: [
          // Permite actualizar la lista manualmente.
          IconButton(
            tooltip: 'Actualizar plantas',
            onPressed: _reloadPlants,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      // Menu lateral requerido por la rubrica.
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              // Encabezado del menu.
              const UserAccountsDrawerHeader(
                accountName: Text('PlantCare'),
                accountEmail: Text('Bitacora de cuidado de plantas'),
                currentAccountPicture: CircleAvatar(
                  child: Icon(Icons.local_florist),
                ),
              ),

              // Opcion para regresar a la lista principal.
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('Mis plantas'),

                onTap: () {
                  // Cierra el Drawer.
                  Navigator.pop(context);
                },
              ),

              // Opcion para registrar una nueva planta.
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Registrar planta'),

                onTap: () {
                  // Primero cerramos el menu lateral.
                  Navigator.pop(context);

                  // Despues abrimos el formulario.
                  _openNewPlant();
                },
              ),

              const Divider(),

              // Informacion general de la aplicacion.
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Acerca de'),

                onTap: () {
                  Navigator.pop(context);

                  // Ventana que explica el proposito de PlantCare.
                  showAboutDialog(
                    context: context,
                    applicationName: 'PlantCare',
                    applicationVersion: '1.0.0',

                    children: [
                      const Text(
                        'Aplicacion para registrar plantas, '
                        'fotografias, observaciones dictadas '
                        'y su historial de cuidados.',
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),

      // FutureBuilder recibe la consulta de la base de datos.
      //
      // Permite mostrar diferentes interfaces dependiendo
      // del resultado de la operacion asincrona.
      body: FutureBuilder<List<Plant>>(
        future: _plantsFuture,

        builder: (context, snapshot) {
          // ESTADO 1: La consulta todavia esta en proceso.
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          // ESTADO 2: Ocurrio un error al consultar SQLite.
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 50,
                      color: Colors.red,
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'No se pudieron cargar las plantas.',
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 15),

                    FilledButton(
                      onPressed: _reloadPlants,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Obtenemos los registros devueltos por SQLite.
          final plants = snapshot.data ?? [];

          // ESTADO 3: La base de datos esta vacia.
          if (plants.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    const Icon(
                      Icons.local_florist_outlined,
                      color: Colors.green,
                      size: 80,
                    ),

                    const SizedBox(height: 15),

                    const Text(
                      'Todavia no tienes plantas registradas.',
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      'Presiona "Nueva planta" para comenzar '
                      'tu bitacora de cuidados.',
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 20),

                    FilledButton.icon(
                      onPressed: _openNewPlant,
                      icon: const Icon(Icons.add),
                      label: const Text('Registrar planta'),
                    ),
                  ],
                ),
              ),
            );
          }

          // ESTADO 4: La base de datos contiene plantas.
          //
          // ListView.builder crea las tarjetas visibles
          // sin construir toda la lista al mismo tiempo.
          return RefreshIndicator(
            onRefresh: _refreshPlants,

            child: ListView.builder(
              padding: const EdgeInsets.all(16),

              itemCount: plants.length,

              // Construimos una tarjeta para cada planta.
              itemBuilder: (context, index) {
                final plant = plants[index];

                return PlantCard(
                  plant: plant,

                  // Al tocarla se abre la pantalla de detalle.
                  onTap: () => _openPlantDetail(plant),
                );
              },
            ),
          );
        },
      ),

      // Boton flotante para abrir el formulario.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewPlant,
        icon: const Icon(Icons.add),
        label: const Text('Nueva planta'),
      ),
    );
  }
}
