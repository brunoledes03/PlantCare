// Importamos el motor de reconocimiento de voz.
import 'package:speech_to_text/speech_to_text.dart';

// Permite recibir las palabras reconocidas por Android.
import 'package:speech_to_text/speech_recognition_result.dart';

// Permite identificar errores durante el reconocimiento.
import 'package:speech_to_text/speech_recognition_error.dart';

// Servicio encargado del uso del microfono.
//
// Sus responsabilidades son:
// 1. Inicializar el reconocimiento de voz.
// 2. Solicitar los permisos necesarios.
// 3. Comenzar el dictado.
// 4. Entregar las palabras reconocidas.
// 5. Detener o cancelar el reconocimiento.
//
// La pantalla solo se comunica con este servicio,
// sin administrar directamente el hardware.
class SpeechService {
  // Motor que se comunica con el reconocimiento nativo.
  final SpeechToText _engine = SpeechToText();

  // Indica si el reconocimiento se inicializo correctamente.
  bool _initialized = false;

  // Permite consultar si el microfono esta escuchando.
  bool get isListening => _engine.isListening;

  // Inicializa el reconocimiento de voz.
  //
  // onStatus recibe los cambios de estado.
  // onError recibe los errores del reconocimiento.
  //
  // Devuelve true si el servicio esta disponible.
  Future<bool> initialize({
    required void Function(String) onStatus,
    required void Function(SpeechRecognitionError) onError,
  }) async {
    // Evita inicializar varias veces el mismo motor.
    if (_initialized) {
      return true;
    }

    // Solicita permisos e inicializa el servicio de voz.
    _initialized = await _engine.initialize(
      onStatus: onStatus,
      onError: onError,

      // No necesitamos utilizar microfonos Bluetooth.
      options: [SpeechToText.androidNoBluetooth],
    );

    return _initialized;
  }

  // Inicia una sesion de dictado.
  //
  // La funcion onResult recibira las palabras reconocidas
  // para mostrarlas en el campo de observaciones.
  Future<void> start(void Function(SpeechRecognitionResult) onResult) async {
    // Comprobamos que el motor este preparado.
    if (!_initialized) {
      throw StateError('El reconocimiento de voz no esta disponible.');
    }

    // Evitamos iniciar dos sesiones simultaneas.
    if (_engine.isListening) {
      return;
    }

    // Comenzamos a escuchar al usuario.
    await _engine.listen(
      onResult: onResult,

      // Configuramos el comportamiento del reconocimiento.
      listenOptions: SpeechListenOptions(
        // Modo adecuado para dictar observaciones.
        listenMode: ListenMode.dictation,

        // Permite mostrar resultados antes de finalizar.
        partialResults: true,

        // Interrumpe la sesion si ocurre un error.
        cancelOnError: true,

        // Duracion maxima solicitada de cada sesion.
        // Android puede detenerla antes.
        listenFor: const Duration(seconds: 45),

        // Tiempo de silencio solicitado antes de finalizar.
        pauseFor: const Duration(seconds: 5),
      ),
    );
  }

  // Detiene el reconocimiento.
  //
  // Se utiliza cuando el usuario pulsa "Detener"
  // o cuando termina de dictar una observacion.
  Future<void> stop() async {
    await _engine.stop();
  }

  // Cancela el reconocimiento.
  //
  // Se utiliza al abandonar el formulario
  // o cuando la aplicacion pasa a segundo plano.
  Future<void> cancel() async {
    await _engine.cancel();
  }
}
