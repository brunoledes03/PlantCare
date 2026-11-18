// Permite trabajar con archivos del almacenamiento del dispositivo.
import 'dart:io';

// Proporciona acceso a la camara y a la galeria.
import 'package:image_picker/image_picker.dart';

// Permite construir rutas sin depender del sistema operativo.
import 'package:path/path.dart' as p;

// Permite encontrar las carpetas temporales y persistentes.
import 'package:path_provider/path_provider.dart';

// Servicio encargado de administrar las fotografias de PlantCare.
//
// Su responsabilidad es:
// 1. Abrir la camara o la galeria.
// 2. Crear copias temporales de las fotografias.
// 3. Guardar imagenes confirmadas permanentemente.
// 4. Eliminar archivos que ya no se necesitan.
//
// La interfaz no necesita conocer las rutas internas de Android.
class PhotoService {
  // Constructor privado para compartir una sola instancia.
  PhotoService._();

  // Instancia que utilizaran las pantallas de PlantCare.
  static final PhotoService instance = PhotoService._();

  // Objeto que permite comunicarse con camara y galeria.
  final ImagePicker _picker = ImagePicker();

  // Abre la camara o galeria segun el origen seleccionado.
  //
  // ImageSource.camera permite tomar una fotografia.
  // ImageSource.gallery permite seleccionar una existente.
  //
  // Si el usuario cancela, devuelve null.
  Future<File?> pickDraft(ImageSource source) async {
    // Iniciamos el selector de imagenes del dispositivo.
    final selected = await _picker.pickImage(
      source: source,

      // Reduce el tamaño de las fotografias grandes.
      maxWidth: 1600,

      // Calidad de compresion para ahorrar almacenamiento.
      imageQuality: 85,

      // No necesitamos solicitar metadatos adicionales.
      requestFullMetadata: false,
    );

    // Si no se selecciono ninguna fotografia, terminamos.
    if (selected == null) {
      return null;
    }

    // Creamos una copia temporal que pertenece a PlantCare.
    return _createDraft(selected);
  }

  // Recupera una foto cuando Android cerro la actividad
  // mientras estaba abierta la camara o galeria.
  //
  // Esta situacion puede ocurrir por falta de memoria RAM.
  Future<File?> recoverLostPhoto() async {
    // La recuperacion de datos perdidos aplica a Android.
    if (!Platform.isAndroid) {
      return null;
    }

    // Consultamos si quedo una seleccion pendiente.
    final result = await _picker.retrieveLostData();

    // No hay archivos que recuperar.
    if (result.isEmpty) {
      return null;
    }

    // Si el selector fallo, propagamos la excepcion.
    if (result.exception != null) {
      throw result.exception!;
    }

    // Obtenemos los archivos recuperados.
    final files = result.files;

    if (files == null || files.isEmpty) {
      return null;
    }

    // Guardamos una copia temporal del primer archivo recuperado.
    return _createDraft(files.first);
  }

  // Busca o crea una carpeta temporal exclusiva de PlantCare.
  Future<Directory> _draftFolder() async {
    // Obtenemos la carpeta de cache de la aplicacion.
    final cache = await getTemporaryDirectory();

    // Creamos una subcarpeta para los borradores.
    final folder = Directory(p.join(cache.path, 'plantcare_drafts'));

    // recursive: true permite crear la carpeta si no existe.
    await folder.create(recursive: true);

    return folder;
  }

  // Copia la imagen seleccionada a la carpeta temporal.
  //
  // De esta forma, nunca modificamos ni eliminamos
  // la fotografia original que pertenece a la galeria.
  Future<File> _createDraft(XFile selected) async {
    final folder = await _draftFolder();

    // Generamos un nombre unico mediante microsegundos.
    final fileName =
        'draft_${DateTime.now().microsecondsSinceEpoch}'
        '${_extension(selected.path)}';

    final destination = p.join(folder.path, fileName);

    // Creamos y devolvemos la copia temporal.
    return File(selected.path).copy(destination);
  }

  // Guarda una fotografia en almacenamiento persistente.
  //
  // Este metodo se utilizara solamente cuando
  // el usuario confirme un registro.
  Future<String> savePermanent(File draft) async {
    // Documents es una carpeta persistente de la aplicacion.
    final documents = await getApplicationDocumentsDirectory();

    // Guardamos las fotografias en su propia subcarpeta.
    final folder = Directory(p.join(documents.path, 'plantcare_photos'));

    await folder.create(recursive: true);

    // Construimos un nombre unico para evitar sobrescrituras.
    final fileName =
        'plant_${DateTime.now().microsecondsSinceEpoch}'
        '${_extension(draft.path)}';

    final destination = p.join(folder.path, fileName);

    // Copiamos la fotografia definitiva.
    final saved = await draft.copy(destination);

    // Devolvemos la ruta que se guardara en SQLite.
    return saved.path;
  }

  // Comprueba que el archivo tenga una extension admitida.
  String _extension(String filePath) {
    final extension = p.extension(filePath).toLowerCase();

    const permitted = {'.jpg', '.jpeg', '.png', '.webp', '.heic'};

    // Si la extension es desconocida, utilizamos jpg.
    return permitted.contains(extension) ? extension : '.jpg';
  }

  // Elimina un archivo temporal o persistente.
  //
  // Primero comprueba si existe para evitar excepciones
  // cuando el archivo ya fue eliminado anteriormente.
  Future<void> deleteIfExists(String filePath) async {
    final file = File(filePath);

    if (await file.exists()) {
      await file.delete();
    }
  }

  // Elimina los borradores antiguos de PlantCare.
  //
  // Se llamara al iniciar la aplicacion, antes de
  // intentar recuperar una fotografia interrumpida.
  Future<void> cleanOldDrafts() async {
    final folder = await _draftFolder();

    // Recorremos los elementos de la carpeta temporal.
    await for (final item in folder.list()) {
      if (item is File) {
        try {
          await item.delete();
        } catch (_) {
          // Si Android mantiene un archivo bloqueado,
          // la aplicacion puede continuar normalmente.
        }
      }
    }
  }
}
