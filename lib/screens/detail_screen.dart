// Permite leer fotografias guardadas en el dispositivo.
import 'dart:io';

// Componentes visuales de Flutter.
import 'package:material_ui/material_ui.dart';

// Acceso a SQLite y a los modelos.
import '../data/plant_database.dart';
import '../models/plant.dart';
import '../models/care_entry.dart';

// Rutas y servicio de fotografias.
import '../routes/app_routes.dart';
import '../services/photo_service.dart';

// Pantalla que muestra los datos y el historial de una planta.
//
// Utiliza StatefulWidget porque el estado de riego
// y los registros de la bitacora pueden cambiar.
class DetailScreen extends StatefulWidget {
  // Planta que recibimos desde la pantalla principal.
  final Plant plant;

  const DetailScreen({super.key, required this.plant});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  // Planta que se muestra actualmente.
  late Plant _plant;

  // Consulta asincrona del historial de cuidados.
  late Future<List<CareEntry>> _entriesFuture;

  // Impide realizar varias operaciones simultaneamente.
  bool _busy = false;

  @override
  void initState() {
    super.initState();

    // Conservamos los datos recibidos por Navigator.
    _plant = widget.plant;

    // Iniciamos la consulta de la bitacora.
    _entriesFuture = PlantDatabase.instance.getCareEntries(_plant.id!);
  }

  // Muestra mensajes temporales en la parte inferior.
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // --------------------------------------------------
  // ACTUALIZAR EL HISTORIAL
  // --------------------------------------------------

  // Vuelve a consultar los registros de la planta.
  //
  // FutureBuilder mostrara los resultados actualizados.
  void _reloadEntries() {
    setState(() {
      _entriesFuture = PlantDatabase.instance.getCareEntries(_plant.id!);
    });
  }

  // --------------------------------------------------
  // CREAR UNA OBSERVACION
  // --------------------------------------------------

  Future<void> _openNewEntry() async {
    if (_busy) return;

    // Abrimos el formulario de la bitacora.
    //
    // Enviamos el identificador de la planta,
    // no un objeto nuevo.
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.newCareEntry,
      arguments: _plant.id,
    );

    // Si el usuario guardo una observacion,
    // actualizamos el historial.
    if (mounted && result == true) {
      _reloadEntries();
    }
  }

  // --------------------------------------------------
  // REGISTRAR RIEGO
  // --------------------------------------------------

  Future<void> _markWatered() async {
    if (_busy) return;

    setState(() {
      _busy = true;
    });

    try {
      // Guardamos la fecha actual del riego.
      //
      // PlantDatabase realiza una transaccion que:
      // 1. Actualiza el ultimo riego de la planta.
      // 2. Crea una entrada en su bitacora.
      await PlantDatabase.instance.markWatered(_plant.id!, DateTime.now());

      // Consultamos nuevamente la planta
      // para obtener su fecha actualizada.
      final updatedPlant = await PlantDatabase.instance.getPlant(_plant.id!);

      if (!mounted) return;

      if (updatedPlant != null) {
        setState(() {
          _plant = updatedPlant;
        });
      }

      // Consultamos nuevamente la bitacora.
      _reloadEntries();

      _showMessage('Se registro el riego correctamente.');
    } catch (error) {
      _showMessage('No se pudo registrar el riego: $error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // --------------------------------------------------
  // ELIMINAR PLANTA
  // --------------------------------------------------

  Future<void> _deletePlant() async {
    if (_busy) return;

    // Antes de eliminar, mostramos una ventana de confirmacion.
    final confirmed = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar planta'),

          content: const Text(
            'Se eliminara la planta y todos sus '
            'registros de cuidado. Esta accion '
            'no se puede deshacer.',
          ),

          actions: [
            // Cierra la ventana sin eliminar nada.
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),

            // Confirma la eliminacion.
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    // Si el usuario cancela, detenemos la operacion.
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      // Eliminamos la planta de SQLite.
      //
      // La base de datos utiliza ON DELETE CASCADE
      // para borrar tambien las entradas de su bitacora.
      //
      // El metodo devuelve las rutas de sus fotografias.
      final imagePaths = await PlantDatabase.instance.deletePlant(_plant.id!);

      // Eliminamos los archivos fisicos asociados.
      //
      // Este paso se realiza despues de confirmar
      // la eliminacion en la base de datos.
      for (final path in imagePaths) {
        try {
          await PhotoService.instance.deleteIfExists(path);
        } catch (_) {
          // Si no se puede borrar una fotografia,
          // no restauramos registros ya eliminados.
        }
      }

      if (mounted) {
        // Regresamos a la lista principal.
        //
        // true indica que los datos cambiaron.
        Navigator.pop(context, true);
      }
    } catch (error) {
      _showMessage('No se pudo eliminar la planta: $error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // --------------------------------------------------
  // TARJETA DE UNA ENTRADA DE BITACORA
  // --------------------------------------------------

  Widget _buildCareEntry(CareEntry entry) {
    // Diferenciamos visualmente los riegos
    // de las observaciones personales.
    final isWatering = entry.type == CareType.riego;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),

      child: Padding(
        padding: const EdgeInsets.all(14),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            // Encabezado con icono y tipo de registro.
            Row(
              children: [
                Icon(
                  isWatering ? Icons.water_drop : Icons.edit_note,
                  color: isWatering ? Colors.blue : Colors.green,
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    entry.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Fecha y hora en que se registro la actividad.
            Text(
              entry.formattedDate,
              style: Theme.of(context).textTheme.bodySmall,
            ),

            const SizedBox(height: 12),

            // Observaciones escritas o dictadas.
            Text(entry.note),

            // Si la observacion tiene fotografia,
            // la mostramos debajo del texto.
            if (entry.imagePath != null) ...[
              const SizedBox(height: 12),

              ClipRRect(
                borderRadius: BorderRadius.circular(10),

                child: Image.file(
                  File(entry.imagePath!),

                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,

                  // Si el archivo falta, mostramos un aviso.
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(
                      height: 100,
                      child: Center(child: Text('Fotografia no disponible')),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // INTERFAZ PRINCIPAL
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de planta'),

        actions: [
          // Boton para eliminar la planta.
          IconButton(
            tooltip: 'Eliminar planta',
            onPressed: _busy ? null : _deletePlant,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),

      // ListView permite desplazar toda la pantalla,
      // incluyendo el historial de cuidados.
      body: ListView(
        padding: const EdgeInsets.all(18),

        children: [
          // -----------------------------------------
          // FOTOGRAFIA PRINCIPAL
          // -----------------------------------------

          // Hero conecta esta fotografia con PlantCard.
          //
          // La etiqueta debe ser identica en ambas pantallas.
          if (_plant.imagePath != null)
            Hero(
              tag: 'plant_${_plant.id}',

              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),

                child: Image.file(
                  File(_plant.imagePath!),

                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,

                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(
                      height: 150,
                      child: Center(child: Icon(Icons.broken_image, size: 55)),
                    );
                  },
                ),
              ),
            )
          else
            const SizedBox(
              height: 130,
              child: Center(
                child: Icon(Icons.local_florist, size: 85, color: Colors.green),
              ),
            ),

          const SizedBox(height: 18),

          // Nombre de la planta.
          Text(_plant.name, style: Theme.of(context).textTheme.headlineMedium),

          const SizedBox(height: 5),

          // Especie registrada.
          Text(
            _plant.species.isEmpty ? 'Especie no indicada' : _plant.species,
            style: Theme.of(context).textTheme.titleMedium,
          ),

          const SizedBox(height: 18),

          // -----------------------------------------
          // INFORMACION DE RIEGO
          // -----------------------------------------
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    'Control de riego',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),

                  const SizedBox(height: 10),

                  // Frecuencia configurada en el formulario.
                  Text(
                    'Frecuencia: cada '
                    '${_plant.wateringEveryDays} dias',
                  ),

                  const SizedBox(height: 8),

                  // Muestra la ultima fecha de riego.
                  Text(
                    _plant.lastWateredAt == null
                        ? 'Ultimo riego: no registrado'
                        : 'Ultimo riego: '
                              '${Plant.formatDate(_plant.lastWateredAt!)}',
                  ),

                  const SizedBox(height: 8),

                  // Estado calculado por el modelo Plant.
                  Text(
                    _plant.wateringStatus,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Registra un riego nuevo en SQLite.
                  FilledButton.icon(
                    onPressed: _busy ? null : _markWatered,

                    icon: const Icon(Icons.water_drop_outlined),

                    label: const Text('Registrar riego de hoy'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 22),

          // -----------------------------------------
          // HISTORIAL DE CUIDADOS
          // -----------------------------------------
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bitacora de cuidados',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),

              // Permite volver a consultar la bitacora.
              IconButton(
                tooltip: 'Actualizar bitacora',
                onPressed: _busy ? null : _reloadEntries,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Boton para crear observaciones escritas
          // o dictadas mediante el microfono.
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _openNewEntry,

            icon: const Icon(Icons.add_comment_outlined),

            label: const Text('Agregar observacion'),
          ),

          const SizedBox(height: 16),

          // FutureBuilder carga los registros de forma asincrona.
          //
          // Tiene tres estados principales:
          // cargando, error y datos obtenidos.
          FutureBuilder<List<CareEntry>>(
            future: _entriesFuture,

            builder: (context, snapshot) {
              // ESTADO 1: Cargando datos de SQLite.
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(20),

                  child: Center(child: CircularProgressIndicator()),
                );
              }

              // ESTADO 2: Error en la consulta.
              if (snapshot.hasError) {
                return Column(
                  children: [
                    const Text('No se pudo cargar la bitacora.'),

                    const SizedBox(height: 8),

                    OutlinedButton(
                      onPressed: _reloadEntries,
                      child: const Text('Reintentar'),
                    ),
                  ],
                );
              }

              // Obtenemos las entradas guardadas.
              final entries = snapshot.data ?? [];

              // ESTADO 3: Todavia no hay registros.
              if (entries.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),

                  child: Center(
                    child: Text(
                      'Esta planta aun no tiene registros. '
                      'Puedes agregar una observacion '
                      'o registrar un riego.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              // ESTADO 4: Se encontraron registros.
              //
              // Construimos una tarjeta por cada entrada.
              return ListView.builder(
                // Permitimos incluir la lista dentro
                // del ListView principal sin conflictos.
                shrinkWrap: true,

                // La pantalla principal controla el desplazamiento.
                physics: const NeverScrollableScrollPhysics(),

                itemCount: entries.length,

                itemBuilder: (context, index) {
                  return _buildCareEntry(entries[index]);
                },
              );
            },
          ),

          const SizedBox(height: 25),
        ],
      ),
    );
  }
}
