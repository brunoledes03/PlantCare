// Permite acceder a las fotografias guardadas en el dispositivo.
import 'dart:io';

// Importamos los componentes visuales de Material Design.
import 'package:material_ui/material_ui.dart';

// Importamos el modelo que contiene los datos de cada planta.
import '../models/plant.dart';

// Este widget representa una tarjeta dentro de la lista de plantas.
//
// Su responsabilidad es mostrar:
// - Fotografia de la planta.
// - Nombre.
// - Especie.
// - Estado del proximo riego.
//
// Es reutilizable porque recibe los datos desde otra pantalla.
class PlantCard extends StatelessWidget {
  // Planta que se mostrara en la tarjeta.
  final Plant plant;

  // Funcion que se ejecuta cuando el usuario toca la tarjeta.
  final VoidCallback onTap;

  const PlantCard({super.key, required this.plant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Calculamos si el riego esta pendiente o atrasado.
    final days = plant.daysUntilWatering;

    final needsWater = days != null && days <= 0;

    return Card(
      // Espacio entre las tarjetas.
      margin: const EdgeInsets.only(bottom: 12),

      // Evita que la imagen sobresalga de las esquinas.
      clipBehavior: Clip.antiAlias,

      // InkWell permite detectar el toque del usuario.
      child: InkWell(
        onTap: onTap,

        child: Row(
          children: [
            // Si existe una fotografia, la mostramos.
            if (plant.imagePath != null)
              // Hero permite animar la imagen al cambiar
              // de la lista a la pantalla de detalle.
              Hero(
                // Esta etiqueta debe ser igual
                // en la pantalla de detalle.
                tag: 'plant_${plant.id}',

                child: Image.file(
                  File(plant.imagePath!),

                  width: 115,
                  height: 130,

                  // Ajusta la fotografia al espacio disponible.
                  fit: BoxFit.cover,

                  // Si el archivo no puede abrirse,
                  // mostramos un icono de respaldo.
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(
                      width: 115,
                      height: 130,
                      child: Center(
                        child: Icon(Icons.broken_image_outlined, size: 45),
                      ),
                    );
                  },
                ),
              )
            // Si la planta no tiene fotografia,
            // mostramos un icono decorativo.
            else
              const SizedBox(
                width: 115,
                height: 130,
                child: Center(
                  child: Icon(
                    Icons.local_florist,
                    size: 55,
                    color: Colors.green,
                  ),
                ),
              ),

            // Expanded utiliza el espacio restante de la tarjeta.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    // Nombre de la planta.
                    Text(
                      plant.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),

                    const SizedBox(height: 5),

                    // Especie registrada.
                    Text(
                      plant.species.isEmpty
                          ? 'Especie no indicada'
                          : plant.species,
                    ),

                    const SizedBox(height: 12),

                    // Estado de riego calculado por el modelo.
                    Text(
                      plant.wateringStatus,

                      style: TextStyle(
                        fontWeight: FontWeight.bold,

                        // Naranja si requiere riego.
                        // Verde si todavia faltan dias.
                        color: needsWater
                            ? Colors.deepOrange
                            : Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Indica que la tarjeta puede abrir otra pantalla.
            const Icon(Icons.chevron_right),

            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}
