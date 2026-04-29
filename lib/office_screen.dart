import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:proj4dart/proj4dart.dart' as proj4;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:developer' as developer;
import 'municipios.dart';
import 'engineer_service.dart'; // Importar el servicio de ingenieros

class OfficeScreen extends StatefulWidget {
  const OfficeScreen({super.key});

  @override
  State<OfficeScreen> createState() => _OfficeScreenState();
}

class _OfficeScreenState extends State<OfficeScreen> {
  String? _selectedMunicipio;
  bool _isExportingCsvEngineer = false;
  bool _isExportingImagesEngineer = false;
  bool _isExportingCsvMunicipio = false;
  bool _isExportingImagesMunicipio = false;

  late final proj4.Projection _sourceProj;
  late final proj4.Projection _targetProj;

  @override
  void initState() {
    super.initState();
    _initializeProjections();
  }

  void _initializeProjections() {
    _sourceProj = proj4.Projection.add(
      'EPSG:4326',
      '+proj=longlat +datum=WGS84 +no_defs +type=crs',
    );
    _targetProj = proj4.Projection.add(
      'EPSG:32630', // WGS 84 / UTM zone 30N
      '+proj=utm +zone=30 +datum=WGS84 +units=m +no_defs +type=crs',
    );
  }

  String _getTimestamp() => DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');

  String _formatMeasurements(dynamic measurements) {
    if (measurements is! List || measurements.isEmpty) return 'N/A';
    return measurements.map((m) {
      final type = m['type'] ?? '?';
      final value = m['value']?.toString() ?? '?';
      return '$type($value)';
    }).join(' | ');
  }

  Future<void> _exportAndShare(String? filter, String filterBy, {required bool isCsv}) async {
    final isEngineer = filterBy == 'engineer';
    if (filter == null || filter.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor, seleccione un $filterBy primero.')),
      );
      return;
    }

    setState(() {
      if (isEngineer) {
        if (isCsv) {
          _isExportingCsvEngineer = true;
        } else {
          _isExportingImagesEngineer = true;
        }
      } else {
        if (isCsv) {
          _isExportingCsvMunicipio = true;
        } else {
          _isExportingImagesMunicipio = true;
        }
      }
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('image_records')
          .where(filterBy, isEqualTo: filter)
          .get();

      if (!mounted) return;
      if (querySnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se encontraron registros para $filter.')),
        );
        return;
      }

      if (isCsv) {
        await _createAndShareCsv(querySnapshot.docs, filter);
      } else {
        await _createAndShareImageZip(querySnapshot.docs, filter);
      }

    } catch (e, s) {
      developer.log('Error exportando archivos', error: e, stackTrace: s, name: 'OfficeScreen');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
            if (isEngineer) {
                if (isCsv) {
                  _isExportingCsvEngineer = false;
                } else {
                  _isExportingImagesEngineer = false;
                }
            } else {
                if (isCsv) {
                  _isExportingCsvMunicipio = false;
                } else {
                  _isExportingImagesMunicipio = false;
                }
            }
        });
      }
    }
  }

  Future<void> _createAndShareCsv(List<QueryDocumentSnapshot> docs, String filter) async {
    docs.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      return (aData['createdAt'] as Timestamp? ?? Timestamp(0,0))
          .compareTo(bData['createdAt'] as Timestamp? ?? Timestamp(0,0));
    });

    List<List<dynamic>> rows = [
      ['ID_Punto', 'Ing.', 'Municipio', 'Camino', 'Medidas', 'URL Foto', 'Nombre Foto', 'Latitud', 'Longitud', 'UTM_X', 'UTM_Y', 'UTM_Zona', 'Tomada']
    ];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final GeoPoint? geoPoint = data['coordinates'];
      String utmX = 'N/A', utmY = 'N/A';

      if (geoPoint != null) {
        var point = proj4.Point(x: geoPoint.longitude, y: geoPoint.latitude);
        var result = _sourceProj.transform(_targetProj, point);
        utmX = result.x.toStringAsFixed(2);
        utmY = result.y.toStringAsFixed(2);
      }

      final imageUrl = data['imageUrl'] as String? ?? 'N/A';
      rows.add([
        doc.id,
        data['engineer'] ?? 'N/A',
        data['municipio'] ?? 'N/A',
        data['camino'] ?? 'N/A',
        _formatMeasurements(data['measurements']),
        imageUrl,
        imageUrl != 'N/A' ? Uri.decodeComponent(Uri.parse(imageUrl).path.split('/').last) : 'N/A',
        geoPoint?.latitude ?? 'N/A',
        geoPoint?.longitude ?? 'N/A',
        utmX, utmY, '30N',
        (data['createdAt'] as Timestamp?)?.toDate().toIso8601String() ?? 'N/A',
      ]);
    }

    final csv = const ListToCsvConverter(delimitAllFields: true).convert(rows);
    final directory = await getTemporaryDirectory();
    final fileName = 'Reporte_${filter.replaceAll(' ', '_')}_${_getTimestamp()}.csv';
    final path = '${directory.path}/$fileName';
    await File(path).writeAsString(csv);

    if (!mounted) return;
    await Share.shareXFiles([XFile(path)], text: 'Reporte de datos para $filter');
  }

  Future<void> _createAndShareImageZip(List<QueryDocumentSnapshot> docs, String filter) async {
    final imageUrls = docs.map((doc) => (doc.data() as Map<String, dynamic>)['imageUrl'] as String?)
      .where((url) => url != null && url.isNotEmpty).cast<String>().toList();

    if (imageUrls.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay URLs de imagen válidas.')));
      return;
    }

    final archive = Archive();
    for (final url in imageUrls) {
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final imageName = Uri.decodeComponent(Uri.parse(url).path.split('/').last);
          archive.addFile(ArchiveFile(imageName, response.bodyBytes.length, response.bodyBytes));
        } else {
          developer.log('Fallo al descargar la imagen: $url', name: 'OfficeScreen');
        }
      } catch (e) {
        developer.log('Error descargando la imagen: $url', error: e, name: 'OfficeScreen');
      }
    }

    if (!mounted) return;
    if (archive.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo descargar ninguna imagen.')));
      return;
    }

    final zipData = ZipEncoder().encode(archive);

    final directory = await getTemporaryDirectory();
    final fileName = 'Reporte_Fotos_${filter.replaceAll(' ', '_')}_${_getTimestamp()}.zip';
    final path = '${directory.path}/$fileName';
    await File(path).writeAsBytes(zipData);

    if (!mounted) return;
    await Share.shareXFiles([XFile(path)], text: 'Reporte de fotos para $filter');
  }

  @override
  Widget build(BuildContext context) {
    // Usamos el EngineerService del Provider
    final engineerService = Provider.of<EngineerService>(context, listen: false);

    return Scaffold(
      body: FutureBuilder<Engineer?>(
        // El Future que vamos a resolver
        future: engineerService.getCurrentEngineerData(),
        builder: (context, snapshot) {
          // --- ESTADO DE CARGA ---
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // --- ESTADO DE ERROR ---
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar datos: ${snapshot.error}'));
          }

          // --- ESTADO SIN DATOS (o sin usuario logueado) ---
          if (!snapshot.hasData) {
            return const Center(child: Text('No se pudo encontrar la información del ingeniero.'));
          }

          // --- ESTADO CON DATOS ---
          final currentEngineer = snapshot.data;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Sección del ingeniero actual (sin título)
                _buildSection(
                  displayWidget: ListTile(
                    leading: const Icon(Icons.person, color: Colors.deepPurple),
                    title: Text(
                      currentEngineer?.name ?? 'Ingeniero Desconocido',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Exportar todos mis datos'),
                  ),
                  onExportCsv: () => _exportAndShare(currentEngineer?.name, 'engineer', isCsv: true),
                  onExportImages: () => _exportAndShare(currentEngineer?.name, 'engineer', isCsv: false),
                  isCsvExporting: _isExportingCsvEngineer,
                  isImagesExporting: _isExportingImagesEngineer,
                  selection: currentEngineer?.name,
                ),

                const SizedBox(height: 16),
                const Divider(thickness: 1.5),
                const SizedBox(height: 16),

                // Sección de municipios (sin título)
                _buildSection(
                  displayWidget: _buildMunicipioAutocomplete(),
                  onExportCsv: () => _exportAndShare(_selectedMunicipio, 'municipio', isCsv: true),
                  onExportImages: () => _exportAndShare(_selectedMunicipio, 'municipio', isCsv: false),
                  isCsvExporting: _isExportingCsvMunicipio,
                  isImagesExporting: _isExportingImagesMunicipio,
                  selection: _selectedMunicipio,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection({
    String? title,
    required Widget displayWidget,
    required VoidCallback onExportCsv,
    required VoidCallback onExportImages,
    required bool isCsvExporting,
    required bool isImagesExporting,
    required String? selection,
  }) {
    final isExporting = isCsvExporting || isImagesExporting;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null && title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            displayWidget,
            const SizedBox(height: 24),
            Wrap(
              spacing: 16.0, runSpacing: 8.0, alignment: WrapAlignment.center,
              children: [
                _buildExportButton(
                  label: 'Exportar y Compartir CSV', icon: Icons.share,
                  isExporting: isCsvExporting, isDisabled: isExporting || selection == null,
                  onPressed: onExportCsv,
                ),
                _buildExportButton(
                  label: 'Exportar y Compartir Fotos', icon: Icons.photo_library,
                  isExporting: isImagesExporting, isDisabled: isExporting || selection == null,
                  onPressed: onExportImages,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildExportButton({
    required String label, required IconData icon, required bool isExporting, 
    required bool isDisabled, required VoidCallback onPressed, Color? color
  }) {
    return ElevatedButton.icon(
      icon: isExporting
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(icon),
      label: Text(label),
      onPressed: isDisabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMunicipioAutocomplete() {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        return andalusianMunicipalities.where((String option) {
          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: (String selection) {
        setState(() {
          _selectedMunicipio = selection;
        });
      },
      fieldViewBuilder: (BuildContext context, TextEditingController fieldController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
        return TextFormField(
          controller: fieldController,
          focusNode: focusNode,
          decoration: const InputDecoration(
              labelText: 'Municipio',
              border: OutlineInputBorder()
          ),
          onChanged: (text) {
            if (text != _selectedMunicipio) {
                if (mounted) {
                    setState(() {
                        _selectedMunicipio = null;
                    });
                }
            }
          },
        );
      },
    );
  }
}
