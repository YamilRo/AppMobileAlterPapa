import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';import 'package:pruebaa/features/classification/presentation/screens/detection_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool isFlashOn = false;

  // Clave global para obtener el tamaño y la posición del widget de la cámara.
  final GlobalKey _cameraPreviewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showErrorSnackBar("No se encontraron cámaras disponibles.");
        return;
      }

      _controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } on CameraException catch (e) {
      _handleCameraError(e);
    } catch (e) {
      _showErrorSnackBar("Ocurrió un error inesperado al iniciar la cámara.");
      print("Error inesperado: $e");
    }
  }

  void _handleCameraError(CameraException e) {
    print("Error al inicializar la cámara: ${e.code}\nMensaje: ${e.description}");
    _showErrorSnackBar('Error de cámara: ${e.description}');
    if (mounted) Navigator.pop(context);
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    isFlashOn = !isFlashOn;
    await _controller!.setFlashMode(isFlashOn ? FlashMode.torch : FlashMode.off);
    setState(() {});
  }

  // --- LÓGICA DE CAPTURA Y RECORTE ---

  Future<void> takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _controller!.value.isTakingPicture) return;

    try {
      // 1. Tomar la foto de alta resolución.
      final XFile imageFile = await _controller!.takePicture();

      // 2. Recortar la imagen y obtener la ruta del nuevo archivo.
      final String? croppedImagePath = await _cropPicture(imageFile);

      if (croppedImagePath == null) {
        _showErrorSnackBar("No se pudo procesar la imagen.");
        return;
      }

      if (mounted) {
        // 3. Navegar a la pantalla de detección con la imagen YA RECORTADA.
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetectionScreen(imagePath: croppedImagePath),
          ),
        );
      }
    } on CameraException catch (e) {
      _showErrorSnackBar("No se pudo capturar la imagen: ${e.description}");
      print("Error al tomar la foto: $e");
    }
  }

  /// Recorta la imagen capturada al área del cuadrado guía.
  Future<String?> _cropPicture(XFile imageFile) async {
    // Decodificar la imagen de alta resolución.
    final bytes = await imageFile.readAsBytes();
    final img.Image? originalImage = img.decodeImage(bytes);
    if (originalImage == null) return null;

    // Obtener las dimensiones del widget de la vista previa.
    final RenderBox previewRenderBox = _cameraPreviewKey.currentContext!.findRenderObject() as RenderBox;
    final previewSize = previewRenderBox.size;

    // Calcular el factor de escala.
    // La imagen capturada está rotada 90 grados en la mayoría de los dispositivos Android.
    // final double scaleX = originalImage.height / previewSize.width;
    // final double scaleY = originalImage.width / previewSize.height;
    final double scaleX = originalImage.height / previewSize.height;
    final double scaleY = originalImage.width / previewSize.width;

    // Tamaño del cuadrado guía en la pantalla (dp).
    const double guideSquareSize = 320.0;

    // Calcular la posición del cuadrado guía en la pantalla.
    final double squareX_dp = (previewSize.width - guideSquareSize) / 2;
    final double squareY_dp = (previewSize.height - guideSquareSize) / 2;

    // Mapear y escalar las coordenadas del cuadrado guía a la imagen de alta resolución.
    final int cropY = (squareY_dp * scaleY).round();
    final int cropX = (squareX_dp * scaleX).round();
    final int cropWidth = (guideSquareSize * scaleY).round();
    final int cropHeight = (guideSquareSize * scaleX).round();

    // Recortar la imagen usando las coordenadas calculadas.
    final img.Image croppedImage = img.copyCrop(
      originalImage,
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
    );

    // Guardar la imagen recortada en un archivo temporal.
    final Directory tempDir = await getTemporaryDirectory();
    final String tempPath = tempDir.path;
    final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final File croppedFile = File('$tempPath/$fileName');
    await croppedFile.writeAsBytes(img.encodeJpg(croppedImage));

    print("Imagen recortada guardada en: ${croppedFile.path}");
    return croppedFile.path;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // --- Construcción de la Interfaz ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Envolvemos CameraPreview en un Center y le asignamos la clave.
          if (_isCameraInitialized)
            Center(
              child: CameraPreview(
                _controller!,
                key: _cameraPreviewKey, // <--- CLAVE ASIGNADA
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),

          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              color: Colors.black.withOpacity(0.5),
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 20),
              child: const Text(
                "Enfoque solo una hoja",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),

          // Este es el cuadrado guía visual que el usuario ve.
          Center(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.8), width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: Colors.black.withOpacity(0.5),
              padding: const EdgeInsets.only(bottom: 30, top: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(onPressed: toggleFlash, icon: Icon(isFlashOn ? Icons.flash_on : Icons.flash_off), color: Colors.white, iconSize: 32),
                  GestureDetector(
                    onTap: takePicture,
                    child: Container(
                      width: 70, height: 70,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: Colors.black, width: 2)),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
