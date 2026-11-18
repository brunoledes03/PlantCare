// Importamos las herramientas para trabajar con rutas de archivos.
import 'package:path/path.dart' as p;

// Importamos SQLite para guardar informacion localmente.
import 'package:sqflite/sqflite.dart';

// Importamos los modelos de plantas y registros de cuidados.
import '../models/plant.dart';
import '../models/care_entry.dart';

// Esta clase administra la base de datos de PlantCare.
//
// Su responsabilidad es crear, consultar, modificar
// y eliminar los registros almacenados en SQLite.
//
// Separamos estas operaciones de las pantallas
// para mantener una arquitectura organizada por capas.
class PlantDatabase {
  // Constructor privado.
  // Evita crear multiples administradores de base de datos.
  PlantDatabase._();

  // Instancia unica que utilizara toda la aplicacion.
  static final PlantDatabase instance = PlantDatabase._();

  // Guarda la operacion de apertura de SQLite.
  // Esto evita abrir la base de datos repetidamente.
  Future<Database>? _opening;

  // Devuelve la base de datos abierta.
  //
  // Si todavia no existe una conexion, la crea.
  Future<Database> get _database {
    return _opening ??= _openDatabase();
  }

  // Abre o crea la base de datos.
  Future<Database> _openDatabase() async {
    // Obtiene la carpeta destinada a las bases de datos.
    final databaseFolder = await getDatabasesPath();

    // Construye la ruta completa del archivo SQLite.
    final databasePath = p.join(databaseFolder, 'plantcare.db');

    // Abre la base de datos.
    return openDatabase(
      databasePath,

      // Primera version del esquema de almacenamiento.
      version: 1,

      // Activa las relaciones entre las tablas.
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },

      // Se ejecuta cuando la base de datos se crea
      // por primera vez.
      onCreate: (db, version) async {
        // TABLA 1: PLANTS
        //
        // Almacena la informacion principal
        // de cada planta registrada.
        await db.execute('''
          CREATE TABLE plants (

            id INTEGER PRIMARY KEY AUTOINCREMENT,

            name TEXT NOT NULL,

            species TEXT NOT NULL,

            image_path TEXT,

            watering_every_days INTEGER NOT NULL,

            created_at INTEGER NOT NULL,

            last_watered_at INTEGER

          )
        ''');

        // TABLA 2: CARE_ENTRIES
        //
        // Almacena las entradas de la bitacora:
        // observaciones, fotografias y registros de riego.
        //
        // plant_id relaciona cada entrada con una planta.
        //
        // ON DELETE CASCADE elimina los registros
        // relacionados cuando se borra una planta.
        await db.execute('''
          CREATE TABLE care_entries (

            id INTEGER PRIMARY KEY AUTOINCREMENT,

            plant_id INTEGER NOT NULL,

            type TEXT NOT NULL,

            note TEXT NOT NULL,

            image_path TEXT,

            created_at INTEGER NOT NULL,

            FOREIGN KEY (plant_id)
              REFERENCES plants(id)
              ON DELETE CASCADE

          )
        ''');
      },
    );
  }

  // --------------------------------------------------
  // OPERACIONES SOBRE LAS PLANTAS
  // --------------------------------------------------

  // Guarda una planta nueva.
  //
  // Devuelve el identificador generado por SQLite.
  Future<int> insertPlant(Plant plant) async {
    // Obtenemos la conexion con la base.
    final db = await _database;

    // Convertimos la planta en un mapa
    // y lo insertamos en la tabla plants.
    return db.insert('plants', plant.toMap());
  }

  // Obtiene todas las plantas registradas.
  //
  // Se utilizara con FutureBuilder
  // en la pantalla principal.
  Future<List<Plant>> getPlants() async {
    final db = await _database;

    // Consultamos las plantas ordenadas
    // de la mas reciente a la mas antigua.
    final rows = await db.query('plants', orderBy: 'created_at DESC, id DESC');

    // Convertimos cada fila SQLite
    // en un objeto de tipo Plant.
    return rows.map((row) => Plant.fromMap(row)).toList();
  }

  // Busca una planta por su identificador.
  //
  // Devuelve null si no existe.
  Future<Plant?> getPlant(int id) async {
    final db = await _database;

    final rows = await db.query(
      'plants',

      // El signo ? evita colocar directamente
      // valores del usuario dentro del SQL.
      where: 'id = ?',
      whereArgs: [id],

      // Solo necesitamos un registro.
      limit: 1,
    );

    // Si no se encontro la planta,
    // devolvemos null.
    if (rows.isEmpty) {
      return null;
    }

    // Convertimos la fila encontrada.
    return Plant.fromMap(rows.first);
  }

  // --------------------------------------------------
  // OPERACIONES SOBRE LA BITACORA
  // --------------------------------------------------

  // Guarda una nueva entrada de cuidado.
  //
  // Puede ser una observacion escrita,
  // una observacion dictada o un registro de riego.
  Future<int> insertCareEntry(CareEntry entry) async {
    final db = await _database;

    // Guardamos el registro en la tabla care_entries.
    //
    // SQLite verificara que plant_id
    // corresponda a una planta existente.
    return db.insert('care_entries', entry.toMap());
  }

  // Obtiene el historial de cuidados de una planta.
  //
  // Cada registro pertenece a la planta
  // indicada mediante plantId.
  Future<List<CareEntry>> getCareEntries(int plantId) async {
    final db = await _database;

    // Seleccionamos solamente los registros
    // de la planta solicitada.
    final rows = await db.query(
      'care_entries',

      where: 'plant_id = ?',
      whereArgs: [plantId],

      // Mostramos primero los registros mas recientes.
      orderBy: 'created_at DESC, id DESC',
    );

    // Transformamos las filas en objetos CareEntry.
    return rows.map((row) => CareEntry.fromMap(row)).toList();
  }

  // --------------------------------------------------
  // REGISTRO DE RIEGO
  // --------------------------------------------------

  // Registra que una planta fue regada.
  //
  // Realiza dos operaciones:
  //
  // 1. Actualiza su fecha de ultimo riego.
  // 2. Agrega una entrada a la bitacora.
  //
  // Ambas se ejecutan dentro de una transaccion.
  Future<void> markWatered(int plantId, DateTime date) async {
    final db = await _database;

    // La transaccion garantiza que las dos
    // operaciones se completen juntas.
    //
    // Si alguna falla, SQLite revierte los cambios.
    await db.transaction((transaction) async {
      // Actualizamos la fecha del ultimo riego.
      final updated = await transaction.update(
        'plants',

        {'last_watered_at': date.millisecondsSinceEpoch},

        where: 'id = ?',
        whereArgs: [plantId],
      );

      // Si no existe la planta,
      // detenemos la operacion.
      if (updated == 0) {
        throw StateError('La planta no existe.');
      }

      // Creamos automaticamente una entrada de riego.
      final wateringEntry = CareEntry(
        plantId: plantId,
        type: CareType.riego,
        note: 'Se registro un riego.',
        createdAt: date,
      );

      // Guardamos el movimiento en la bitacora.
      await transaction.insert('care_entries', wateringEntry.toMap());
    });
  }

  // --------------------------------------------------
  // ELIMINACION DE PLANTAS
  // --------------------------------------------------

  // Elimina una planta y sus registros asociados.
  //
  // Devuelve las rutas de las fotografias
  // para que PhotoService pueda borrarlas despues.
  //
  // SQLite elimina las entradas relacionadas
  // gracias a ON DELETE CASCADE.
  Future<List<String>> deletePlant(int plantId) async {
    final db = await _database;

    return db.transaction((transaction) async {
      // Buscamos la fotografia principal de la planta.
      final plants = await transaction.query(
        'plants',
        columns: ['image_path'],
        where: 'id = ?',
        whereArgs: [plantId],
      );

      if (plants.isEmpty) {
        throw StateError('La planta no existe.');
      }

      // Buscamos las fotografias de su bitacora.
      final entries = await transaction.query(
        'care_entries',
        columns: ['image_path'],
        where: 'plant_id = ?',
        whereArgs: [plantId],
      );

      // Reunimos todas las rutas que necesitaremos limpiar.
      final imagePaths = <String>{};

      final mainImage = plants.first['image_path'] as String?;

      if (mainImage != null) {
        imagePaths.add(mainImage);
      }

      for (final entry in entries) {
        final path = entry['image_path'] as String?;

        if (path != null) {
          imagePaths.add(path);
        }
      }

      // Eliminamos la planta.
      //
      // SQLite eliminara tambien sus registros
      // de care_entries gracias a la clave foranea.
      await transaction.delete('plants', where: 'id = ?', whereArgs: [plantId]);

      // Devolvemos las rutas de las fotografias.
      //
      // Las pantallas utilizaran PhotoService
      // para borrar estos archivos fisicos.
      return imagePaths.toList();
    });
  }
}
