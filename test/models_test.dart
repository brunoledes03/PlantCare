// Herramientas oficiales de Flutter para ejecutar pruebas.
import 'package:flutter_test/flutter_test.dart';

// Modelos de PlantCare.
//
// IMPORTANTE:
// proyectos_flutter es el nombre real del proyecto
// registrado en pubspec.yaml.
import 'package:proyectos_flutter/models/plant.dart';
import 'package:proyectos_flutter/models/care_entry.dart';

void main() {
  // Agrupamos las pruebas relacionadas con las plantas.
  group('Modelo Plant', () {
    // PRUEBA 1:
    // Comprueba que el objeto Plant se convierte
    // correctamente a un mapa para SQLite.
    test('Convierte una planta a Map', () {
      final fecha = DateTime(2026, 11, 17);

      // Creamos una planta de ejemplo.
      final plant = Plant(
        name: 'Mi cactus',
        species: 'Mammillaria',
        wateringEveryDays: 7,
        createdAt: fecha,
      );

      // Convertimos el objeto al formato de SQLite.
      final map = plant.toMap();

      // Comprobamos que los campos sean correctos.
      expect(map['name'], 'Mi cactus');
      expect(map['species'], 'Mammillaria');
      expect(map['watering_every_days'], 7);

      // SQLite guarda la fecha como numero entero.
      expect(map['created_at'], fecha.millisecondsSinceEpoch);
    });

    // PRUEBA 2:
    // Comprueba que se puede reconstruir una planta
    // utilizando un registro obtenido de SQLite.
    test('Reconstruye una planta desde Map', () {
      final fecha = DateTime(2026, 11, 17);

      // Simulamos una fila de la base de datos.
      final map = <String, Object?>{
        'id': 5,
        'name': 'Aloe',
        'species': 'Aloe vera',
        'image_path': null,
        'watering_every_days': 10,
        'created_at': fecha.millisecondsSinceEpoch,
        'last_watered_at': null,
      };

      // Reconstruimos el objeto.
      final plant = Plant.fromMap(map);

      // Verificamos los datos recuperados.
      expect(plant.id, 5);
      expect(plant.name, 'Aloe');
      expect(plant.species, 'Aloe vera');
      expect(plant.wateringEveryDays, 10);
      expect(plant.lastWateredAt, isNull);
    });
  });

  // Agrupamos las pruebas del historial de cuidados.
  group('Modelo CareEntry', () {
    // PRUEBA 3:
    // Comprueba el almacenamiento de una observacion.
    test('Convierte una observacion a Map', () {
      final fecha = DateTime(2026, 11, 17, 14, 30);

      // Creamos una entrada de bitacora.
      final entry = CareEntry(
        plantId: 5,
        type: CareType.observacion,
        note: 'La planta tiene hojas nuevas.',
        createdAt: fecha,
      );

      // Convertimos los datos para SQLite.
      final map = entry.toMap();

      expect(map['plant_id'], 5);
      expect(map['type'], 'observacion');
      expect(map['note'], 'La planta tiene hojas nuevas.');

      expect(map['created_at'], fecha.millisecondsSinceEpoch);
    });

    // PRUEBA 4:
    // Comprueba que SQLite puede devolver
    // correctamente una entrada de riego.
    test('Reconstruye un registro de riego', () {
      final fecha = DateTime(2026, 11, 17, 16, 0);

      // Simulamos un registro de la tabla care_entries.
      final map = <String, Object?>{
        'id': 9,
        'plant_id': 5,
        'type': 'riego',
        'note': 'Se registro un riego.',
        'image_path': null,
        'created_at': fecha.millisecondsSinceEpoch,
      };

      // Reconstruimos la entrada.
      final entry = CareEntry.fromMap(map);

      expect(entry.id, 9);
      expect(entry.plantId, 5);
      expect(entry.type, CareType.riego);
      expect(entry.note, 'Se registro un riego.');
    });
  });
}
