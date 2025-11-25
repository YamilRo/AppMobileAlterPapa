import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:pruebaa/core/services/tflite_service.dart';

class ClassificationScreen extends StatefulWidget {
  final String imagePath;
  const ClassificationScreen({Key? key, required this.imagePath}) : super(key: key);

  @override
  _ClassificationScreenState createState() => _ClassificationScreenState();
}

class _ClassificationScreenState extends State<ClassificationScreen> {
  final TFLiteService _tfliteService = TFLiteService();
  bool _isLoading = true;
  String? _errorMessage;

  // Resultados de los modelos
  ClassificationResult? _classificationResult;
  SegmentationResult? _segmentationResult;

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    try {
      // --- PASO 1: CLASIFICACIÓN ---
      final classificationInput = await _tfliteService
          .preprocessImageClassification(widget.imagePath);
      final classResult = _tfliteService.makeInferenceClassification(
          classificationInput);

      // --- PASO 2: SEGMENTACIÓN ---
      // Solo ejecutamos la segmentación si la hoja no está sana
      SegmentationResult? segResult;
      final cleanLabel = classResult.predictedLabel.replaceAll('\r', '').trim();

      if (cleanLabel != 'Hoja sana') {
        final segmentationInput = await _tfliteService
            .preprocessImageSegmentation(widget.imagePath);
        segResult = _tfliteService.makeInferenceSegmentation(
            segmentationInput, widget.imagePath);
      } else {
        // Si la hoja está sana, creamos un resultado de segmentación por defecto
        final originalImageBytes = await File(widget.imagePath).readAsBytes();
        segResult = SegmentationResult(
          overlayedImage: img.decodeImage(originalImageBytes)!,
          affectedAreaRatio: 0.0,
          leafCount: 0,
          spotCount: 0,
          maxSpotSizeCm: 0.0,
        );
      }

      if (mounted) {
        setState(() {
          _classificationResult = classResult;
          _segmentationResult = segResult;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Ocurrió un error durante el análisis:\n$e";
          _isLoading = false;
        });
        print("Error en _runAnalysis: $e");
      }
    }
  }

  /// Determina el texto cualitativo del área afectada
  String _getAffectedAreaText(double ratio, String label) {
    final cleanLabel = label.replaceAll('\r', '').trim();
    if (cleanLabel == 'Sano') {
      return "Hoja Sana";
    }

    final percentage = ratio * 100;
    if (percentage < 1) {
      return "Inicio de manchas";
    } else if (percentage <= 5) {
      return "Inicio de afeccion";
    } else if (percentage <= 20) {
      return "Medianamente Afectada";
    } else if (percentage <= 60) {
      return "Muy Afectada";
    } else {
      return "Estado Crítico";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Análisis Detallado de la Hoja"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Padding(padding: const EdgeInsets.all(16.0),
          child: Text(_errorMessage!, style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center)))
          : _buildResultView(),
    );
  }

  Widget _buildResultView() {if (_classificationResult == null || _segmentationResult == null) {
    return const Center(child: Text("No se pudieron cargar los resultados."));
  }

  final String label = _classificationResult!.predictedLabel.replaceAll('\r', '').trim();
  final double confidence = _classificationResult!.output.reduce((a, b) => a > b ? a : b);
  final double affectedRatio = _segmentationResult!.affectedAreaRatio;
  final img.Image resultImage = _segmentationResult!.overlayedImage;

  // --- NUEVO: Obtener los conteos ---
  final int leafCount = _segmentationResult!.leafCount;
  final int spotCount = _segmentationResult!.spotCount;
  final double maxSpotSizeCm = _segmentationResult!.maxSpotSizeCm;

  final bool isHealthy = label == "Hoja sana";
  final Color headerColor = isHealthy
      ? const Color.fromRGBO(0, 106, 94, 1.0)
      : const Color.fromRGBO(171, 78, 91, 1.0);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // --- CABECERA ACTUALIZADA ---
      // Pasamos los nuevos parámetros leafCount y spotCount
      _buildHeader(label, confidence, headerColor, leafCount, spotCount, maxSpotSizeCm),


      // --- IMAGEN CON MÁSCARA (DENTRO DE UN CUADRO) ---
      Expanded(
        child: Container(
          // Fondo general de la sección
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Container(
            // El "cuadro" que contiene la imagen
            padding: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(color: Colors.grey[300]!)
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6.0),
              child: Image.memory(
                Uint8List.fromList(img.encodeJpg(resultImage)),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),

      // --- PIE DE PÁGINA ---
      _buildFooter(affectedRatio, label),
    ],
  );
  }

  // --- CABECERA CON 3 CUADROS ---
  Widget _buildHeader(String label, double confidence, Color headerColor, int leafCount, int spotCount, double maxSpotSizeCm) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      child: Row(
        children: [
          // 1. Cuadro de Diagnóstico
          Expanded(
            child: _buildHeaderCard(
              title: "DIAGNÓSTICO",
              content: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              color: headerColor,
            ),
          ),
          const SizedBox(width: 6),

          // 2. Cuadro de Probabilidad
          Expanded(
            child: _buildHeaderCard(
              title: "PROBABILIDAD",
              content: Text(
                "${(confidence * 100).toStringAsFixed(1)}%",
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              color: headerColor,
            ),
          ),
          const SizedBox(width: 6),

          // 3. --- CUADRO DE DETECCIÓN ---
          Expanded(
            child: _buildHeaderCard(
              title: "DETECCIÓN",
              content: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  //Text("$leafCount Hojas", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text("$spotCount Manchas", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),

                  // Línea divisoria sutil
                  if (spotCount > 0) ...[
                    // const Padding(
                    //   padding: EdgeInsets.symmetric(vertical: 2.0),
                    //   child: Divider(color: Colors.white54, height: 4, thickness: 1),
                    // ),
                    Text(
                      "Max: ${maxSpotSizeCm.toStringAsFixed(1)} cm",
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ]
                ],
              ),
              color: headerColor,
            ),
          ),
        ],
      ),
    );
  }

  // Helper para crear las tarjetitas de la cabecera y evitar repetir código
  Widget _buildHeaderCard({required String title, required Widget content, required Color color}) {
    return Container(
      // Altura fija para que todos los cuadros sean iguales
      height: 85,
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w300)),
          Expanded(
            child: Center(child: content),
          ),
        ],
      ),
    );
  }


  // --- AJUSTAR ESTILOS DEL PIE DE PÁGINA ---
  Widget _buildFooter(double affectedRatio, String label) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.white,
      child: Column(
        // Centrar todo el contenido del pie de página
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Título del pie de página (centrado)
          Text(
            _getAffectedAreaText(affectedRatio, label),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          Stack(
            alignment: Alignment.center,
            children: [
              // 1. La barra de progreso (el fondo)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: affectedRatio,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    affectedRatio > 0.6
                        ? Colors.red
                        : (affectedRatio > 0.4
                        ? Colors.orange
                        : Colors.green),
                  ),
                  minHeight: 62.0, // Se mantiene tu valor
                ),
              ),
              // 2. El texto superpuesto
              Text(
                "Área afectada: ${(affectedRatio * 100).toStringAsFixed(1)}%",
                style: const TextStyle(
                  fontSize: 16, // Tamaño adecuado para estar dentro
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
