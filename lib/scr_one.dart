import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'details_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'dart:developer' as developer;
import 'municipios.dart';
import 'engineer_service.dart';

class ScrOne extends StatefulWidget {
  const ScrOne({super.key});

  @override
  State<ScrOne> createState() => _ScrOneState();
}

class _ScrOneState extends State<ScrOne> {
  final _formKey = GlobalKey<FormState>();
  final _municipioController = TextEditingController();
  final _caminoController = TextEditingController();

  bool _isGpsOn = false;
  double? _accuracy;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _municipioController.dispose();
    _caminoController.dispose();
    super.dispose();
  }

  Future<void> _toggleGps() async {
    if (!_isGpsOn) {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'El permiso de ubicación es necesario para usar el GPS.')),
          );
        }
        return;
      }
      setState(() => _isGpsOn = true);
      const locationSettings =
          LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 1);
      _positionStreamSubscription =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen((Position position) {
        if (mounted) {
          setState(() {
            _accuracy = position.accuracy;
            _currentPosition = position;
          });
        }
      });
    } else {
      _positionStreamSubscription?.cancel();
      setState(() {
        _isGpsOn = false;
        _accuracy = null;
        _currentPosition = null;
      });
    }
  }

  Future<void> _takePhoto() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, complete todos los campos.')),
      );
      return;
    }

    final engineerService = Provider.of<EngineerService>(context, listen: false);
    // --- CORRECCIÓN 1: Usar 'await' para obtener los datos del ingeniero ---
    final engineer = await engineerService.getCurrentEngineerData();
    final engineerName = engineer?.name;

    if (engineerName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No se ha identificado al ingeniero.')),
      );
      return;
    }

    final Position? positionAtClick = _currentPosition;
    final ImagePicker picker = ImagePicker();
    final XFile? originalImageFile =
        await picker.pickImage(source: ImageSource.camera);

    if (!mounted || originalImageFile == null) return;

    final DateTime captureTime = DateTime.now();
    Position finalPosition =
        positionAtClick ?? await Geolocator.getCurrentPosition();

    XFile? processedImage;
    try {
      final imageBytes = await originalImageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) throw Exception("Could not decode image");

      img.Image resizedImage = img.copyResize(
        originalImage,
        width: originalImage.width < originalImage.height ? 768 : -1,
        height: originalImage.height <= originalImage.width ? 768 : -1,
      );
      final compressedBytes = img.encodeJpg(resizedImage, quality: 95);

      final tempDir = await getTemporaryDirectory();
      final tempPath =
          "${tempDir.path}/processed_${captureTime.millisecondsSinceEpoch}.jpg";
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(compressedBytes);
      processedImage = XFile(tempPath);
    } catch (e, s) {
      developer.log('Error en procesamiento de imagen',
          error: e, stackTrace: s, name: 'ScrOneTakePhoto');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error al procesar la imagen. Inténtelo de nuevo.'),
              backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (!mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailsScreen(
          imageFile: processedImage!,
          captureTime: captureTime,
          isGpsEnabled: _isGpsOn,
          currentPosition: finalPosition,
          engineer: engineerName,
          municipio: _municipioController.text,
          camino: _caminoController.text,
        ),
      ),
    );

    if (result == 'upload_success' && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Registro guardado con éxito en la nube!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    // --- CORRECCIÓN 2: Se elimina el Scaffold y la AppBar anidada ---
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          // --- CORRECCIÓN 3: Se añade un header con el saludo ---
          _buildWelcomeHeader(),
          const SizedBox(height: 16),
          _buildMunicipioAutocomplete(),
          const SizedBox(height: 16),
          _buildTextField(_caminoController, 'Camino'),
          const Divider(height: 32, thickness: 1),
          const Text('1) Pulse para iniciar GPS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.08),
                    blurRadius: 10,
                    offset: Offset(0, 4))
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: [
                    Icon(Icons.gps_fixed,
                        color: _isGpsOn ? primaryColor : Colors.grey[400]),
                    const SizedBox(width: 12),
                    const Text('Precisión',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                  ],
                ),
                Row(
                  children: [
                    if (_isGpsOn)
                      Text(
                        _accuracy != null
                            ? '${_accuracy!.toStringAsFixed(1)} m'
                            : '...',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryColor),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _toggleGps,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _isGpsOn ? Colors.red : primaryColor,
                          foregroundColor: Colors.white),
                      child: Text(_isGpsOn ? 'GpsOff' : 'GpsOn'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 32, thickness: 1),
          const Text('2) Pulse para iniciar cámara',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(
              onPressed: _isGpsOn ? _takePhoto : null,
              style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(24),
                  backgroundColor: primaryColor),
              child:
                  const Icon(Icons.camera_alt, size: 48, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para mostrar el saludo de forma asíncrona
  Widget _buildWelcomeHeader() {
    final engineerService = Provider.of<EngineerService>(context, listen: false);
    return FutureBuilder<Engineer?>(
      future: engineerService.getCurrentEngineerData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          return Text(
            'Hola, ${snapshot.data?.name ?? "Ingeniero"}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          );
        }
        // En caso de error o sin datos, no muestra nada o un texto genérico
        return Text(
            'Bienvenido',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          );
      },
    );
  }

  Widget _buildMunicipioAutocomplete() {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text == '') return const Iterable<String>.empty();
        return andalusianMunicipalities.where((String option) {
          return option
              .toLowerCase()
              .contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: (String selection) => _municipioController.text = selection,
      fieldViewBuilder:
          (context, fieldController, focusNode, onFieldSubmitted) {
        // Asignamos el controlador aquí para que el Autocomplete pueda manejarlo
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _municipioController.text = fieldController.text;
        });
        return TextFormField(
          controller: fieldController,
          focusNode: focusNode,
          decoration: const InputDecoration(
              labelText: 'Municipio', border: OutlineInputBorder()),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Campo requerido';
            if (!andalusianMunicipalities.contains(value)) {
              return 'Por favor, seleccione un municipio válido de la lista';
            }
            return null;
          },
        );
      },
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
      validator: (value) =>
          (value == null || value.isEmpty) ? 'Campo requerido' : null,
    );
  }
}
