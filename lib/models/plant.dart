// Esta clase representa una planta registrada en PlantCare.
//
// Pertenece a la capa de modelos.
// Su responsabilidad es almacenar y organizar
// los datos de cada planta.
//
// No contiene elementos visuales ni operaciones directas de SQLite.

class Plant {
  // Identificador unico generado por SQLite.
  // Es nullable porque una planta nueva aun no tiene ID.
  final int? id;

  // Nombre personalizado de la planta.
  final String name;

  // Nombre de la especie.
  final String species;

  // Ruta donde esta almacenada su fotografia.
  // Puede ser null cuando no se selecciona imagen.
  final String? imagePath;

  // Frecuencia de riego elegida por el usuario.
  final int wateringEveryDays;

  // Fecha en la que se registro la planta.
  final DateTime createdAt;

  // Fecha del ultimo riego registrado.
  // Es null si todavia no se ha registrado ninguno.
  final DateTime? lastWateredAt;

  // Constructor del modelo.
  //
  // required obliga a proporcionar los datos necesarios.
  // id e imagePath son opcionales.
  const Plant({
    this.id,
    required this.name,
    required this.species,
    this.imagePath,
    required this.wateringEveryDays,
    required this.createdAt,
    this.lastWateredAt,
  });

  // Convierte la planta en un mapa compatible con SQLite.
  //
  // Las claves deben coincidir con las columnas
  // que crearemos en la tabla plants.
  Map<String, Object?> toMap() {
    return {
      'name': name,
      'species': species,
      'image_path': imagePath,
      'watering_every_days': wateringEveryDays,

      // Guardamos las fechas como numeros enteros.
      'created_at': createdAt.millisecondsSinceEpoch,

      // El operador ? evita errores si no existe un ultimo riego.
      'last_watered_at': lastWateredAt?.millisecondsSinceEpoch,
    };
  }

  // Constructor que transforma un registro SQLite
  // nuevamente en un objeto Plant.
  factory Plant.fromMap(Map<String, Object?> map) {
    return Plant(
      id: map['id'] as int,
      name: map['name'] as String,
      species: map['species'] as String,
      imagePath: map['image_path'] as String?,
      wateringEveryDays: map['watering_every_days'] as int,

      // Recupera la fecha almacenada en milisegundos.
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),

      // Comprueba si se ha registrado un riego.
      lastWateredAt: map['last_watered_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['last_watered_at'] as int),
    );
  }

  // Calcula cuando corresponderia el proximo riego
  // utilizando la frecuencia elegida por el usuario.
  //
  // No intenta determinar automaticamente
  // las necesidades biologicas de la planta.
  DateTime? get nextWateringAt {
    if (lastWateredAt == null) {
      return null;
    }

    final last = lastWateredAt!.toLocal();

    return DateTime(last.year, last.month, last.day + wateringEveryDays);
  }

  // Calcula los dias que faltan para el siguiente riego.
  //
  // Un numero negativo significa que la fecha ya paso.
  int? get daysUntilWatering {
    final next = nextWateringAt;

    if (next == null) {
      return null;
    }

    final today = DateTime.now();

    // Comparamos solo dia, mes y anio.
    // Asi la hora no altera el resultado.
    final todayDate = DateTime.utc(today.year, today.month, today.day);

    final nextDate = DateTime.utc(next.year, next.month, next.day);

    return nextDate.difference(todayDate).inDays;
  }

  // Devuelve un texto que describe el estado del riego.
  //
  // Este mensaje se utilizara en las tarjetas
  // y en la pantalla de detalle.
  String get wateringStatus {
    final days = daysUntilWatering;

    if (days == null) {
      return 'Sin riegos registrados';
    }

    if (days < 0) {
      return 'Riego atrasado por ${-days} dia(s)';
    }

    if (days == 0) {
      return 'Toca regar hoy';
    }

    if (days == 1) {
      return 'Proximo riego manana';
    }

    return 'Proximo riego en $days dias';
  }

  // Convierte una fecha al formato dia/mes/anio.
  //
  // Por ejemplo: 17/11/2026.
  static String formatDate(DateTime date) {
    final local = date.toLocal();

    String twoDigits(int number) {
      return number.toString().padLeft(2, '0');
    }

    return '${twoDigits(local.day)}/'
        '${twoDigits(local.month)}/'
        '${local.year}';
  }
}
