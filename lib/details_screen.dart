import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'firebase_utils.dart';
import 'image_utils.dart';
import 'dart:developer' as developer;

class Measurement {
  String? type;
  final TextEditingController valueController = TextEditingController();
  void dispose() => valueController.dispose();
}

class DetailsScreen extends StatefulWidget {
  final XFile imageFile;
  final DateTime captureTime;
  final bool isGpsEnabled;
  final Position? currentPosition;
  final String engineer;
  final String municipio;
  final String camino;

  const DetailsScreen({
    super.key,
    required this.imageFile,
    required this.captureTime,
    this.isGpsEnabled = false,
    this.currentPosition,
    required this.engineer,
    required this.municipio,
    required this.camino,
  });

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<Measurement> _measurements = [];
  final List<String> _measurementTypes = [
    'Escollera', 'Escollera hormigonada', 'Losa hormigonada', 'Zahorra préstamo',
    'Caño Ø 1.5 m', 'Marco □ 2 m', 'Rastrillo (babero)', 'Suelo seleccionado',
    'Mamposteria', 'Otros',
  ];
  bool _isProcessingAndUploading = false;

  @override
  void initState() {
    super.initState();
    _measurements.add(Measurement());
  }

  @override
  void dispose() {
    for (var m in _measurements) {
      m.dispose();
    }
    super.dispose();
  }

  Future<void> _submitData() async {
    if (!(_formKey.currentState?.validate() ?? false) ||
        _measurements.any((m) => m.type == null || m.valueController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, complete todos los campos requeridos.')),
      );
      return;
    }

    if (widget.currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener la posición GPS.')),
      );
      return;
    }

    setState(() => _isProcessingAndUploading = true);

    String? finalErrorMessage;
    bool uploadSucceeded = false;

    try {
      // Step 1: Process image to add EXIF data.
      final originalFile = File(widget.imageFile.path);
      final File processedImageFile = await addCoordinatesToImage(
          imageFile: originalFile,
          position: widget.currentPosition!,
          engineer: widget.engineer,
          municipio: widget.municipio,
          camino: widget.camino,
          captureTime: widget.captureTime,
      );

      // Step 2: Prepare measurements data
      final List<Map<String, dynamic>> measurementsData = _measurements
          .map((m) => {
                'type': m.type!,
                'value': double.tryParse(m.valueController.text.replaceAll(',', '.')) ?? 0.0,
              })
          .toList();

      // Step 3: Upload to Firebase (the critical part)
      await uploadImageAndSaveRecord(
        filePath: processedImageFile.path,
        engineer: widget.engineer,
        municipio: widget.municipio,
        camino: widget.camino,
        measurements: measurementsData,
        coordinates: widget.currentPosition,
      );

      uploadSucceeded = true;

    } catch (e, s) {
      developer.log('Error during submit process', error: e, stackTrace: s, name: 'DetailsScreen');
      finalErrorMessage = 'Error al procesar o subir la imagen: ${e.toString()}';
    } finally {
      if (mounted) {
        setState(() => _isProcessingAndUploading = false);
        if (uploadSucceeded) {
          // IMPORTANT: Pop with a success result
          Navigator.of(context).pop('upload_success');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(finalErrorMessage ?? 'Ocurrió un error inesperado.'), backgroundColor: Colors.red),
          );
          // Optionally, pop without a result on failure
           Navigator.of(context).pop();
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalles de la Imagen')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildImagePreview(),
            const SizedBox(height: 16),
            _buildMeasurementsSection(),
            const SizedBox(height: 32),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 20, thickness: 1),
        Text(
          'Medidas',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _measurements.length,
          itemBuilder: (context, index) => _buildMeasurementRow(index),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Añadir Medida'),
            onPressed: () => setState(() => _measurements.add(Measurement())),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.onSecondary,
            ),
          ),
        ),
        const Divider(height: 20, thickness: 1),
      ],
    );
  }

  Widget _buildMeasurementRow(int index) {
    final measurement = _measurements[index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: measurement.type,
              decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder()),
              items: _measurementTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (value) => setState(() => measurement.type = value),
              validator: (v) => v == null ? 'Requerido' : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: measurement.valueController,
              decoration: const InputDecoration(labelText: 'Dimensión', border: OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => (v == null || v.isEmpty) ? 'Valor' : null,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
            onPressed: () => setState(() {
              measurement.dispose();
              _measurements.removeAt(index);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(widget.imageFile.path),
          height: 250, width: 250, fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    Widget buttonContent;
    String buttonText = 'Finalizar y Guardar';

    if (_isProcessingAndUploading) {
      buttonText = 'Guardando...';
      buttonContent = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [const CircularProgressIndicator(color: Colors.white, strokeWidth: 3), const SizedBox(width: 16), Text(buttonText)],
      );
    } else {
      buttonContent = Text(buttonText, style: const TextStyle(fontSize: 16));
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _isProcessingAndUploading ? Colors.grey : Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: _isProcessingAndUploading ? null : _submitData,
      child: buttonContent,
    );
  }
}
