// Permite trabajar con los archivos de imagen del dispositivo.
import 'dart:async';
import 'dart:io';

// Importamos los componentes visuales de Flutter.
import 'package:material_ui/material_ui.dart';

// Permite indicar si queremos abrir la camara o la galeria.
import 'package:image_picker/image_picker.dart';

// Importamos la base de datos SQLite.
import '../data/plant_database.dart';

// Importamos el modelo de una planta.
import '../models/plant.dart';

// Importamos el servicio de fotografias que ya creamos.
import '../services/photo_service.dart';

// Pantalla para registrar una nueva planta.
//
// StatefulWidget permite modificar la fotografia,
// el formulario y la frecuencia de riego.
class NewPlantScreen extends StatefulWidget {
  const NewPlantScreen({super.key});

  @override
  State<NewPlantScreen> createState() => _NewPlantScreenState();
}

class _NewPlantScreenState extends State<NewPlantScreen> {
  // Identificador del formulario.
  // Permite ejecutar las validaciones de sus campos.
  final _formKey = GlobalKey<FormState>();

  // Controlador del campo nombre.
  final _nameController = TextEditingController();

  // Controlador del campo especie.
  final _speciesController = TextEditingController();

  // Fotografia temporal seleccionada por el usuario.
  //
  // Mientras no se guarde la planta,
  // esta imagen no sera permanente.
  File? _draftPhoto;

  // Frecuencia inicial de riego: 7 dias.
  //
  // El usuario podra modificarla mediante un Slider.
  int _wateringDays = 7;

  // Evita seleccionar varias fotografias al mismo tiempo.
  bool _pickingPhoto = false;

  // Evita guardar dos veces una misma planta.
  bool _saving = false;

  // Muestra mensajes de informacion o error.
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // --------------------------------------------------
  // SELECCIONAR FOTOGRAFIA
  // --------------------------------------------------

  // Abre la camara o la galeria.
  //
  // El parametro source indica el origen:
  // ImageSource.camera o ImageSource.gallery.
  Future<void> _selectPhoto(ImageSource source) async {
    // No permitimos ejecutar esta accion
    // mientras se guarda o selecciona otra fotografia.
    if (_saving || _pickingPhoto) {
      return;
    }

    setState(() {
      _pickingPhoto = true;
    });

    try {
      // Utilizamos nuestro servicio de fotografias.
      //
      // Este metodo devuelve una copia temporal
      // o null si el usuario cancelo.
      final newPhoto = await PhotoService.instance.pickDraft(source);

      // Si el usuario cancela, conservamos la foto anterior.
      if (newPhoto == null) {
        return;
      }

      // Si la pantalla ya fue destruida,
      // eliminamos el borrador recien creado.
      if (!mounted) {
        await PhotoService.instance.deleteIfExists(newPhoto.path);

        return;
      }

      // Guardamos la referencia de la fotografia anterior.
      final previousPhoto = _draftPhoto;

      // Actualizamos la imagen que aparece en la pantalla.
      setState(() {
        _draftPhoto = newPhoto;
      });

      // Si reemplazamos una fotografia,
      // eliminamos el borrador anterior.
      if (previousPhoto != null) {
        try {
          await PhotoService.instance.deleteIfExists(previousPhoto.path);
        } catch (_) {
          // Un fallo de limpieza no debe impedir
          // utilizar la nueva fotografia.
        }
      }
    } catch (error) {
      // Capturamos los errores de camara,
      // almacenamiento o permisos.
      _showMessage('No se pudo seleccionar la fotografia: $error');
    } finally {
      // Activamos nuevamente los botones.
      if (mounted) {
        setState(() {
          _pickingPhoto = false;
        });
      }
    }
  }

  // --------------------------------------------------
  // ELIMINAR FOTOGRAFIA SELECCIONADA
  // --------------------------------------------------

  Future<void> _removePhoto() async {
    if (_saving || _pickingPhoto) {
      return;
    }

    // Obtenemos el archivo temporal actual.
    final photo = _draftPhoto;

    if (photo == null) {
      return;
    }

    setState(() {
      _draftPhoto = null;
      _pickingPhoto = true;
    });

    try {
      // Eliminamos el borrador del almacenamiento temporal.
      await PhotoService.instance.deleteIfExists(photo.path);
    } catch (error) {
      _showMessage('No se pudo eliminar la foto temporal: $error');
    } finally {
      if (mounted) {
        setState(() {
          _pickingPhoto = false;
        });
      }
    }
  }

  // --------------------------------------------------
  // GUARDAR PLANTA
  // --------------------------------------------------

  Future<void> _savePlant() async {
    // Evitamos acciones duplicadas.
    if (_saving || _pickingPhoto) {
      return;
    }

    // Comprobamos que el formulario sea valido.
    //
    // Si el nombre esta vacio,
    // se mostrara el mensaje del validator.
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    // Bloqueamos los botones durante el guardado.
    setState(() {
      _saving = true;
    });

    // Guardara la ruta de la fotografia permanente.
    String? permanentImagePath;

    // Permite conocer si SQLite confirmo el registro.
    bool savedInDatabase = false;

    try {
      // PASO 1:
      // Si existe una foto temporal,
      // hacemos una copia en Documents.
      //
      // Documents conserva las fotografias
      // mientras la aplicacion mantenga sus datos.
      if (_draftPhoto != null) {
        permanentImagePath = await PhotoService.instance.savePermanent(
          _draftPhoto!,
        );
      }

      // PASO 2:
      // Creamos el objeto Plant.
      //
      // Su id sera generado automaticamente por SQLite.
      final plant = Plant(
        name: _nameController.text.trim(),
        species: _speciesController.text.trim(),
        imagePath: permanentImagePath,
        wateringEveryDays: _wateringDays,
        createdAt: DateTime.now(),

        // La fecha del primer riego se registrara
        // desde la pantalla de detalle.
        lastWateredAt: null,
      );

      // PASO 3:
      // Insertamos la planta en SQLite.
      await PlantDatabase.instance.insertPlant(plant);

      // La base de datos ya confirmo el registro.
      savedInDatabase = true;

      // PASO 4:
      // Eliminamos la fotografia temporal
      // porque ya existe una copia permanente.
      final draft = _draftPhoto;

      // Evita que dispose intente eliminarla nuevamente.
      _draftPhoto = null;

      if (draft != null) {
        try {
          await PhotoService.instance.deleteIfExists(draft.path);
        } catch (_) {
          // Si falla la limpieza, la planta
          // permanece guardada correctamente.
        }
      }

      // PASO 5:
      // Regresamos a la pantalla principal.
      //
      // El valor true indica que se agrego una planta
      // y que la lista principal debe actualizarse.
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      // Si ocurre un error antes de confirmar
      // el registro en SQLite, eliminamos la copia permanente
      // para evitar archivos sin una planta asociada.
      if (!savedInDatabase && permanentImagePath != null) {
        try {
          await PhotoService.instance.deleteIfExists(permanentImagePath);
        } catch (_) {
          // No ocultamos el error original de guardado.
        }
      }

      // Informamos el problema sin cerrar el formulario.
      _showMessage('No se pudo guardar la planta: $error');
    } finally {
      // Volvemos a habilitar la interfaz
      // cuando termina la operacion.
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // --------------------------------------------------
  // LIBERAR RECURSOS
  // --------------------------------------------------

  @override
  void dispose() {
    // Liberamos la memoria de los campos de texto.
    _nameController.dispose();
    _speciesController.dispose();

    // Si el usuario abandona la pantalla
    // sin guardar, borramos su foto temporal.
    final draft = _draftPhoto;

    if (draft != null) {
      unawaited(PhotoService.instance.deleteIfExists(draft.path));
    }

    super.dispose();
  }

  // --------------------------------------------------
  // INTERFAZ
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Evitamos salir mientras se guarda una planta
      // o se esta seleccionando una fotografia.
      canPop: !_saving && !_pickingPhoto,

      child: Scaffold(
        // Barra superior con boton para regresar.
        appBar: AppBar(title: const Text('Registrar nueva planta')),

        // Form permite validar los campos del usuario.
        body: Form(
          key: _formKey,

          // ListView permite desplazar la pantalla
          // cuando aparece el teclado.
          child: ListView(
            padding: const EdgeInsets.all(20),

            children: [
              // TITULO DEL FORMULARIO
              Text(
                'Datos de la planta',
                style: Theme.of(context).textTheme.headlineSmall,
              ),

              const SizedBox(height: 16),

              // CAMPO: NOMBRE
              TextFormField(
                controller: _nameController,

                // Limita la cantidad de caracteres.
                maxLength: 60,

                textCapitalization: TextCapitalization.sentences,

                decoration: const InputDecoration(
                  labelText: 'Nombre de la planta',
                  hintText: 'Ejemplo: Mi cactus',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.spa),
                ),

                // El nombre es obligatorio.
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Escribe el nombre de la planta.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 12),

              // CAMPO: ESPECIE
              TextFormField(
                controller: _speciesController,
                maxLength: 80,

                decoration: const InputDecoration(
                  labelText: 'Especie',
                  hintText: 'Ejemplo: Aloe vera',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.eco_outlined),
                ),

                // La especie es opcional.
              ),

              const SizedBox(height: 20),

              // SECCION: FOTOGRAFIA
              Text(
                'Fotografia de la planta',
                style: Theme.of(context).textTheme.titleLarge,
              ),

              const SizedBox(height: 12),

              // Contenedor de vista previa de la imagen.
              ClipRRect(
                borderRadius: BorderRadius.circular(14),

                child: Container(
                  height: 220,
                  width: double.infinity,
                  color: Colors.green.shade50,

                  // Si no hay foto mostramos un icono.
                  child: _draftPhoto == null
                      ? const Center(
                          child: Icon(
                            Icons.add_a_photo_outlined,
                            size: 75,
                            color: Colors.green,
                          ),
                        )
                      // Si hay foto mostramos el archivo seleccionado.
                      : Image.file(
                          _draftPhoto!,
                          width: double.infinity,
                          fit: BoxFit.cover,

                          // Evita que falle la pantalla si
                          // el archivo no se puede leer.
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Text('No se pudo mostrar la imagen.'),
                            );
                          },
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // BOTONES: CAMARA Y GALERIA
              Wrap(
                spacing: 10,
                runSpacing: 10,

                children: [
                  // Abre la camara del dispositivo.
                  OutlinedButton.icon(
                    onPressed: _saving || _pickingPhoto
                        ? null
                        : () => _selectPhoto(ImageSource.camera),

                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Tomar foto'),
                  ),

                  // Abre la galeria del dispositivo.
                  OutlinedButton.icon(
                    onPressed: _saving || _pickingPhoto
                        ? null
                        : () => _selectPhoto(ImageSource.gallery),

                    icon: const Icon(Icons.photo_library_outlined),

                    label: const Text('Galeria'),
                  ),

                  // Permite quitar la foto antes de guardar.
                  if (_draftPhoto != null)
                    OutlinedButton.icon(
                      onPressed: _saving || _pickingPhoto ? null : _removePhoto,

                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Quitar foto'),
                    ),
                ],
              ),

              const SizedBox(height: 25),

              // SECCION: FRECUENCIA DE RIEGO
              Text(
                'Frecuencia de riego',
                style: Theme.of(context).textTheme.titleLarge,
              ),

              const SizedBox(height: 8),

              // Muestra la frecuencia elegida.
              Text(
                'Regar cada $_wateringDays dias',
                style: Theme.of(context).textTheme.titleMedium,
              ),

              // Slider permite seleccionar un valor
              // entre 1 y 30 dias.
              Slider(
                value: _wateringDays.toDouble(),

                min: 1,
                max: 30,
                divisions: 29,

                label: '$_wateringDays dias',

                // Actualizamos la frecuencia seleccionada.
                onChanged: _saving
                    ? null
                    : (value) {
                        setState(() {
                          _wateringDays = value.round();
                        });
                      },
              ),

              // Aclaracion: no es una recomendacion
              // automatica sobre la especie.
              const Text(
                'Selecciona la frecuencia de acuerdo '
                'con las necesidades de tu planta.',
              ),

              const SizedBox(height: 28),

              // BOTON: GUARDAR PLANTA
              FilledButton.icon(
                // Bloqueamos el boton mientras se guarda.
                onPressed: _saving || _pickingPhoto ? null : _savePlant,

                icon: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,

                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),

                label: Text(_saving ? 'Guardando planta...' : 'Guardar planta'),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
