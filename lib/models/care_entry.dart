// Define los tipos de registros que admite la bitacora.
//
// observacion: informacion sobre el estado de la planta.
// riego: registro de un riego realizado.
enum CareType { observacion, riego }

// Representa una entrada individual de la bitacora.
//
// Cada entrada pertenece a una planta mediante plantId.
//
// Una misma planta puede tener muchas entradas,
// permitiendo consultar su historial de cuidados.
class CareEntry {
  // Identificador generado automaticamente por SQLite.
  final int? id;

  // Identificador de la planta a la que pertenece.
  final int plantId;

  // Tipo de actividad registrada.
  final CareType type;

  // Observacion escrita o dictada con el microfono.
  final String note;

  // Ruta opcional de una fotografia del registro.
  final String? imagePath;

  // Fecha y hora de creacion del registro.
  final DateTime createdAt;

  // Constructor de la entrada.
  const CareEntry({
    this.id,
    required this.plantId,
    required this.type,
    required this.note,
    this.imagePath,
    required this.createdAt,
  });

  // Convierte el objeto en un mapa para SQLite.
  //
  // La columna plant_id relacionara esta entrada
  // con el identificador de una planta.
  Map<String, Object?> toMap() {
    return {
      'plant_id': plantId,

      // Guardamos el nombre del valor del enum.
      'type': type.name,

      'note': note,
      'image_path': imagePath,

      // Almacenamos la fecha como un numero entero.
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  // Reconstruye una entrada recuperada desde SQLite.
  factory CareEntry.fromMap(Map<String, Object?> map) {
    // Recuperamos el tipo de registro almacenado.
    final savedType = map['type'] as String;

    // Buscamos el valor correspondiente del enum.
    final entryType = CareType.values.firstWhere(
      (type) => type.name == savedType,

      // Si encontramos un valor desconocido,
      // utilizamos observacion como alternativa.
      orElse: () => CareType.observacion,
    );

    return CareEntry(
      id: map['id'] as int,
      plantId: map['plant_id'] as int,
      type: entryType,
      note: map['note'] as String,
      imagePath: map['image_path'] as String?,

      // Convertimos el numero almacenado en una fecha.
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  // Devuelve el titulo que mostrara la interfaz.
  String get title {
    switch (type) {
      case CareType.observacion:
        return 'Observacion';
      case CareType.riego:
        return 'Riego registrado';
    }
  }

  // Formatea la fecha y hora del registro para mostrarla.
  String get formattedDate {
    final local = createdAt.toLocal();

    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${twoDigits(local.day)}/'
        '${twoDigits(local.month)}/'
        '${local.year} '
        '${twoDigits(local.hour)}:'
        '${twoDigits(local.minute)}';
  }
}
