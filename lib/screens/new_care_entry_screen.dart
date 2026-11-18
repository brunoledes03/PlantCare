// Permite manejar operaciones asincronas y archivos.
import 'dart:async';
import 'dart:io';

// Componentes visuales de Flutter 3.50.
import 'package:material_ui/material_ui.dart';

// Permite seleccionar entre camara y galeria.
import 'package:image_picker/image_picker.dart';

// Tipos utilizados por el servicio de reconocimiento de voz.
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

// Base de datos y modelo de la bitacora.
import '../data/plant_database.dart';
import '../models/care_entry.dart';

// Servicios de fotografia y microfono.
import '../services/photo_service.dart';
import '../services/speech_service.dart';

// Pantalla que permite crear una observacion para una planta.
//
// Cada observacion pertenece a una planta mediante plantId.
//
// StatefulWidget permite actualizar la fotografia,
// el texto reconocido y el estado del microfono.
class NewCareEntryScreen extends StatefulWidget {
  // Identificador de la planta a la que pertenece el registro.
  final int plantId;

  const NewCareEntryScreen({super.key, required this.plantId});

  @override
  State<NewCareEntryScreen> createState() => _NewCareEntryScreenState();
}

class _NewCareEntryScreenState extends State<NewCareEntryScreen>
    with WidgetsBindingObserver {
  // Permite validar los campos antes de guardar.
  final _formKey = GlobalKey<FormState>();

  // Contiene el texto escrito o dictado por el usuario.
  final _noteController = TextEditingController();

  // Servicio para utilizar el microfono.
  final SpeechService _speech = SpeechService();

  // Fotografia temporal del registro.
  File? _draftPhoto;

  // Conserva las notas que existian antes de dictar.
  //
  // El reconocimiento puede enviar varias versiones
  // de una misma frase mientras el usuario habla.
  String _textBeforeDictation = '';

  // Variables para controlar las operaciones.
  bool _listening = false;
  bool _pickingPhoto = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    // Observamos cuando la aplicacion pasa a segundo plano.
    // Asi podemos cancelar el uso del microfono.
    WidgetsBinding.instance.addObserver(this);
  }

  // Muestra informacion al usuario mediante SnackBar.
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // --------------------------------------------------
  // CAMARA Y GALERIA
  // --------------------------------------------------

  // Abre la camara o la galeria para seleccionar una imagen.
  Future<void> _selectPhoto(ImageSource source) async {
    if (_saving || _pickingPhoto) return;

    setState(() {
      _pickingPhoto = true;
    });

    try {
      // Cancelamos el reconocimiento antes de abrir otra app.
      await _speech.cancel();

      if (mounted) {
        setState(() {
          _listening = false;
        });
      }

      // Obtenemos una copia temporal de la fotografia.
      final selectedPhoto = await PhotoService.instance.pickDraft(source);

      // Si el usuario cancelo, no modificamos la imagen.
      if (selectedPhoto == null) return;

      if (!mounted) {
        // Evitamos dejar un archivo temporal sin pantalla.
        await PhotoService.instance.deleteIfExists(selectedPhoto.path);
        return;
      }

      // Recordamos la fotografia anterior.
      final previousPhoto = _draftPhoto;

      // Mostramos la imagen seleccionada.
      setState(() {
        _draftPhoto = selectedPhoto;
      });

      // Borramos el borrador anterior si fue reemplazado.
      if (previousPhoto != null) {
        try {
          await PhotoService.instance.deleteIfExists(previousPhoto.path);
        } catch (_) {
          // No bloqueamos la nueva seleccion por una
          // falla al eliminar un archivo temporal.
        }
      }
    } catch (error) {
      _showMessage('No se pudo seleccionar la fotografia: $error');
    } finally {
      if (mounted) {
        setState(() {
          _pickingPhoto = false;
        });
      }
    }
  }

  // Elimina la fotografia temporal cuando el usuario
  // decide que ya no quiere incluirla en el registro.
  Future<void> _removePhoto() async {
    if (_saving || _pickingPhoto) return;

    final photo = _draftPhoto;

    if (photo == null) return;

    setState(() {
      _draftPhoto = null;
      _pickingPhoto = true;
    });

    try {
      await PhotoService.instance.deleteIfExists(photo.path);
    } catch (error) {
      _showMessage('No se pudo eliminar la foto: $error');
    } finally {
      if (mounted) {
        setState(() {
          _pickingPhoto = false;
        });
      }
    }
  }

  // --------------------------------------------------
  // RECONOCIMIENTO DE VOZ
  // --------------------------------------------------

  // Android informa cuando el motor comienza
  // o termina una sesion de reconocimiento.
  void _onSpeechStatus(String status) {
    if (!mounted) return;

    if (status == 'done' || status == 'notListening') {
      setState(() {
        _listening = false;
      });
    }
  }

  // Recibe errores del servicio de reconocimiento.
  //
  // Por ejemplo, cuando el usuario deniega el permiso
  // o no existe un servicio de voz disponible.
  void _onSpeechError(SpeechRecognitionError error) {
    if (!mounted) return;

    setState(() {
      _listening = false;
    });

    _showMessage('Error del reconocimiento: ${error.errorMsg}');
  }

  // Recibe las palabras que reconoce el microfono.
  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;

    // El motor entrega las palabras reconocidas.
    final recognizedText = result.recognizedWords.trim();

    if (recognizedText.isEmpty) return;

    // Conservamos el texto escrito previamente.
    //
    // Reemplazamos el fragmento reconocido en cada resultado,
    // porque los resultados parciales pueden repetir palabras.
    final completeText = [
      _textBeforeDictation,
      recognizedText,
    ].where((part) => part.isNotEmpty).join(' ');

    // Actualizamos el TextField del formulario.
    _noteController.value = TextEditingValue(
      text: completeText,

      // Colocamos el cursor al final del texto.
      selection: TextSelection.collapsed(offset: completeText.length),
    );
  }

  // Alterna entre comenzar y detener el dictado.
  Future<void> _toggleDictation() async {
    if (_saving || _pickingPhoto) return;

    try {
      // Si el microfono esta activo, detenemos la sesion.
      if (_listening || _speech.isListening) {
        await _speech.stop();

        if (mounted) {
          setState(() {
            _listening = false;
          });
        }

        return;
      }

      // Inicializamos el servicio y solicitamos
      // los permisos necesarios del microfono.
      final available = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );

      if (!mounted) return;

      // Si Android no tiene un servicio compatible,
      // las observaciones pueden escribirse manualmente.
      if (!available) {
        _showMessage(
          'No se pudo activar el reconocimiento de voz. '
          'Puedes escribir tus observaciones.',
        );
        return;
      }

      // Conservamos las observaciones previas.
      //
      // Si el usuario dicta varias veces, las frases nuevas
      // se agregan al texto anterior.
      _textBeforeDictation = _noteController.text.trim();

      // Iniciamos el reconocimiento.
      await _speech.start(_onSpeechResult);

      if (mounted) {
        setState(() {
          _listening = _speech.isListening;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _listening = false;
        });
      }

      _showMessage('No se pudo iniciar el dictado: $error');
    }
  }

  // --------------------------------------------------
  // GUARDAR REGISTRO EN SQLITE
  // --------------------------------------------------

  Future<void> _saveEntry() async {
    // Evitamos guardados simultaneos.
    if (_saving || _pickingPhoto || _listening) return;

    // Validamos que exista una observacion.
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _saving = true;
    });

    // Ruta donde se guardara la fotografia permanente.
    String? permanentImagePath;

    // Indica si SQLite confirmo la insercion.
    bool savedInDatabase = false;

    try {
      // Detenemos cualquier sesion residual del microfono.
      await _speech.stop();

      // Si existe una fotografia temporal,
      // copiamos la imagen a Documents.
      if (_draftPhoto != null) {
        permanentImagePath = await PhotoService.instance.savePermanent(
          _draftPhoto!,
        );
      }

      // Creamos una entrada de tipo observacion.
      //
      // El identificador plantId permite relacionarla
      // con la planta seleccionada.
      final entry = CareEntry(
        plantId: widget.plantId,
        type: CareType.observacion,
        note: _noteController.text.trim(),
        imagePath: permanentImagePath,
        createdAt: DateTime.now(),
      );

      // Insertamos la entrada en la tabla care_entries.
      await PlantDatabase.instance.insertCareEntry(entry);

      // El registro quedo almacenado correctamente.
      savedInDatabase = true;

      // Eliminamos el borrador porque la fotografia
      // ya se encuentra en el directorio permanente.
      final draft = _draftPhoto;
      _draftPhoto = null;

      if (draft != null) {
        try {
          await PhotoService.instance.deleteIfExists(draft.path);
        } catch (_) {
          // Una falla de limpieza no elimina la entrada
          // que ya fue guardada en SQLite.
        }
      }

      if (mounted) {
        // Regresamos al detalle con true.
        //
        // La pantalla anterior actualizara la bitacora.
        Navigator.pop(context, true);
      }
    } catch (error) {
      // Si SQLite no confirmo la operacion,
      // eliminamos la fotografia permanente creada.
      if (!savedInDatabase && permanentImagePath != null) {
        try {
          await PhotoService.instance.deleteIfExists(permanentImagePath);
        } catch (_) {}
      }

      _showMessage('No se pudo guardar la observacion: $error');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // --------------------------------------------------
  // CICLO DE VIDA Y LIMPIEZA
  // --------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Si la app deja de estar activa, cancelamos
    // cualquier sesion de reconocimiento.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_speech.cancel());

      if (mounted) {
        setState(() {
          _listening = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Dejamos de observar el ciclo de vida.
    WidgetsBinding.instance.removeObserver(this);

    // Liberamos el controlador del campo de texto.
    _noteController.dispose();

    // Cancelamos el microfono si la pantalla se destruye.
    unawaited(_speech.cancel());

    // Si el registro no se guardo,
    // eliminamos su fotografia temporal.
    final draft = _draftPhoto;

    if (draft != null) {
      unawaited(PhotoService.instance.deleteIfExists(draft.path));
    }

    super.dispose();
  }

  // --------------------------------------------------
  // INTERFAZ DEL FORMULARIO
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Evita salir mientras ocurre una operacion critica.
      canPop: !_saving && !_pickingPhoto,

      child: Scaffold(
        appBar: AppBar(title: const Text('Nueva observacion')),

        body: Form(
          key: _formKey,

          child: ListView(
            padding: const EdgeInsets.all(20),

            children: [
              Text(
                'Bitacora de cuidados',
                style: Theme.of(context).textTheme.headlineSmall,
              ),

              const SizedBox(height: 8),

              const Text(
                'Describe como se encuentra tu planta. '
                'Puedes escribir o utilizar el microfono.',
              ),

              const SizedBox(height: 22),

              // Campo que muestra lo escrito y lo dictado.
              TextFormField(
                controller: _noteController,
                minLines: 5,
                maxLines: 8,
                maxLength: 1500,

                decoration: const InputDecoration(
                  labelText: 'Observaciones',
                  hintText: 'Ejemplo: hoy aparecieron hojas nuevas...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),

                // No se permiten observaciones vacias.
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Escribe o dicta una observacion.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 10),

              // Boton para activar el segundo gadget:
              // el microfono con reconocimiento de voz.
              FilledButton.tonalIcon(
                onPressed: _saving || _pickingPhoto ? null : _toggleDictation,

                icon: Icon(_listening ? Icons.stop : Icons.mic),

                label: Text(
                  _listening ? 'Detener dictado' : 'Dictar observacion',
                ),
              ),

              // Indicador que informa si el microfono esta activo.
              if (_listening) ...[
                const SizedBox(height: 8),

                const Text(
                  'Microfono activo. Habla para convertir '
                  'tu voz en texto.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.deepOrange),
                ),
              ],

              const SizedBox(height: 24),

              Text(
                'Fotografia del registro',
                style: Theme.of(context).textTheme.titleLarge,
              ),

              const SizedBox(height: 12),

              // Vista previa de la fotografia.
              ClipRRect(
                borderRadius: BorderRadius.circular(14),

                child: Container(
                  height: 200,
                  color: Colors.green.shade50,

                  child: _draftPhoto == null
                      ? const Center(
                          child: Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 70,
                            color: Colors.green,
                          ),
                        )
                      : Image.file(
                          _draftPhoto!,
                          width: double.infinity,
                          fit: BoxFit.cover,

                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Text('Fotografia no disponible'),
                            );
                          },
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // Botones para tomar o seleccionar una fotografia.
              Wrap(
                spacing: 10,
                runSpacing: 8,

                children: [
                  OutlinedButton.icon(
                    onPressed: _saving || _pickingPhoto
                        ? null
                        : () => _selectPhoto(ImageSource.camera),

                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Camara'),
                  ),

                  OutlinedButton.icon(
                    onPressed: _saving || _pickingPhoto
                        ? null
                        : () => _selectPhoto(ImageSource.gallery),

                    icon: const Icon(Icons.photo_library_outlined),

                    label: const Text('Galeria'),
                  ),

                  if (_draftPhoto != null)
                    OutlinedButton.icon(
                      onPressed: _saving || _pickingPhoto ? null : _removePhoto,

                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Quitar foto'),
                    ),
                ],
              ),

              const SizedBox(height: 30),

              // Guarda la observacion en SQLite.
              FilledButton.icon(
                onPressed: _saving || _pickingPhoto || _listening
                    ? null
                    : _saveEntry,

                icon: const Icon(Icons.save_outlined),

                label: Text(
                  _saving ? 'Guardando observacion...' : 'Guardar observacion',
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
