import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pruebaa/core/services/tflite_service.dart';
import 'package:image/image.dart' as img;
import 'package:pruebaa/features/classification/presentation/screens/classification_screen.dart';
import 'package:pruebaa/features/disease_info/presentation/screens/treatments_screen.dart';


class _ClassifiedLeaf {
  final img.Image image;
  final String label;
  final double confidence;

  _ClassifiedLeaf({
    required this.image,
    required this.label,
    required this.confidence,
  });
}

class _CertaintyStyle {
  final String text;
  final Color color;

  _CertaintyStyle(this.text, this.color);
}

class _SummaryResult {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String mostLikelyDisease;
  final _CertaintyStyle certainty;

  _SummaryResult({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.mostLikelyDisease,
    required this.certainty,
  });
}


class DetectionScreen extends StatefulWidget {
  final String imagePath;
  const DetectionScreen({Key? key, required this.imagePath}) : super(key: key);

  @override
  _DetectionScreenState createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  final TFLiteService _tfliteService = TFLiteService();
  List<_ClassifiedLeaf> _classifiedLeaves = [];
  _SummaryResult? _summaryResult;
  //double _mostAffectedAreaRatio = 0.0;
  double _maxSpotSizeCm = 0.0; // NUEVO
  bool _isLoading = true;
  String _loadingMessage = "Detectando hojas...";
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _runDetectionAndClassification();
  }

  Future<void> _runDetectionAndClassification() async {
    try {
      if (!mounted) return;
      setState(() {
        _loadingMessage = "Paso 1/4: Detectando hojas...";
      });
      final detectionInput = await _tfliteService.preprocessImageDetection(widget.imagePath);

      final detectionResult = await _tfliteService.makeInferenceDetection(
        detectionInput,
        widget.imagePath,
        confidenceThreshold: 0.9,
        iouThreshold: 0.5,
      );

      if (detectionResult.objectCount == 0) {
        if (mounted) setState(() {
          _errorMessage = "No se encontraron hojas en la imagen. Por favor, intente con otra foto.";
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _loadingMessage = "Paso 2/4: Analizando cada hoja...";
      });

      List<_ClassifiedLeaf> results = [];
      for (var i = 0; i < detectionResult.detectedObjects.length; i++) {
        final detectedObject = detectionResult.detectedObjects[i];

        if (!mounted) return;
        setState(() {
          _loadingMessage = "Paso 2/4: Analizando hoja ${i + 1} de ${detectionResult.objectCount}...";
        });

        final tempImagePath = await _saveImageToTempFile(detectedObject);
        final classificationInput = await _tfliteService.preprocessImageClassification(tempImagePath);
        final classificationResult = _tfliteService.makeInferenceClassification(classificationInput);

        final maxConfidence = classificationResult.output.reduce((a, b) => a > b ? a : b);

        results.add(_ClassifiedLeaf(
          image: detectedObject,
          label: classificationResult.predictedLabel,
          confidence: maxConfidence,
        ));
      }

      final summary = _calculateSummaryResult(results);

      // --- Ejecutar segmentación en la hoja más enferma ---
      if (summary.mostLikelyDisease.contains('Tizón temprano')) {
        if (!mounted) return;
        setState(() {
          _loadingMessage = "Paso 3/4: Midiendo área afectada...";
        });

        // Encontrar la hoja específica con tizón temprano de mayor probabilidad
        final mostLikelyTizonLeaf = results
            .where((leaf) => leaf.label.contains('Tizón temprano'))
            .reduce((a, b) => a.confidence > b.confidence ? a : b);

        final tempImagePath = await _saveImageToTempFile(mostLikelyTizonLeaf.image);
        final segmentationInput = await _tfliteService.preprocessImageSegmentation(tempImagePath);
        final segmentationResult = _tfliteService.makeInferenceSegmentation(segmentationInput, tempImagePath);

        // _mostAffectedAreaRatio = segmentationResult.affectedAreaRatio;
        _maxSpotSizeCm = segmentationResult.maxSpotSizeCm;
      }

      if (mounted) setState(() {
        _loadingMessage = "Paso 4/4: Mostrando resultados...";
        _classifiedLeaves = results;
        _summaryResult = summary;
        _isLoading = false;
      });

    } catch (e) {
      if (mounted) setState(() {
        _errorMessage = "Ocurrió un error durante el proceso: $e";
        _isLoading = false;
      });
      print("Error en _runDetectionAndClassification: $e");
    }
  }

  _SummaryResult _calculateSummaryResult(List<_ClassifiedLeaf> leaves) {
    const String healthyLabel = 'Hoja sana\r';

    final diseasedLeaves = leaves.where((leaf) => leaf.label != healthyLabel).toList();

    if (diseasedLeaves.isEmpty) {
      double avgConfidence = leaves.isNotEmpty ? leaves.map((l) => l.confidence).reduce((a, b) => a + b) / leaves.length : 1.0;
      return _SummaryResult(
        icon: Icons.sentiment_very_satisfied,
        iconColor: Colors.green,
        title: "Planta Sana",
        mostLikelyDisease: "",
        certainty: _getCertaintyStyle(avgConfidence),
      );
    } else {
      diseasedLeaves.sort((a, b) => b.confidence.compareTo(a.confidence));
      _ClassifiedLeaf mostLikelySickLeaf = diseasedLeaves.first;

      return _SummaryResult(
        icon: Icons.sentiment_very_dissatisfied,
        iconColor: Colors.red,
        title: "Planta Enferma con",
        mostLikelyDisease: mostLikelySickLeaf.label,
        certainty: _getCertaintyStyle(mostLikelySickLeaf.confidence),
      );
    }
  }

  Future<String> _saveImageToTempFile(img.Image image) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String tempPath = tempDir.path;
    final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final File tempFile = File('$tempPath/$fileName');
    await tempFile.writeAsBytes(img.encodeJpg(image));
    return tempFile.path;
  }

  _CertaintyStyle _getCertaintyStyle(double confidence) {
    if (confidence >= 0.85) {
      return _CertaintyStyle("Alta", const Color.fromRGBO(171, 78, 91, 1.0));
    } else if (confidence >= 0.50) {
      return _CertaintyStyle("Media", const Color.fromRGBO(171, 100, 78, 1.0));
    } else {
      return _CertaintyStyle("Baja", const Color.fromRGBO(78, 111, 171, 1.0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cleanDiseaseName = _summaryResult?.mostLikelyDisease.replaceAll('\r', '').trim() ?? '';
    final showTreatmentButton = cleanDiseaseName == 'Tizón temprano';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Resultados del Análisis", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        automaticallyImplyLeading: true,
      ),
      body: Center(
        child: _isLoading
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(_loadingMessage, style: const TextStyle(fontSize: 16)),
          ],
        )
            : _errorMessage.isNotEmpty
            ? Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 18)),
        )
            : Column(
          children: [
            if (_summaryResult != null) _buildSummaryBar(_summaryResult!),
            Expanded(child: _buildResultsGrid()),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[700],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Volver', style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                  if (showTreatmentButton) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TreatmentsScreen(
                                diseaseName: cleanDiseaseName,
                                maxSpotSizeCm: _maxSpotSizeCm, // <<< PASANDO EL DATO
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(0, 106, 94, 1.0),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Tratamientos', style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBar(_SummaryResult summary) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(0, 106, 94, 1.0),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.grey[400]!, width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), spreadRadius: 1, blurRadius: 5, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(summary.icon, color: summary.iconColor, size: 48),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.3),
                      children: [
                        TextSpan(text: '${summary.title} '),
                        TextSpan(text: summary.mostLikelyDisease.replaceAll('\r', ''), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Stack(
                    children: [
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..color = Colors.black,
                          ),
                          children: [const TextSpan(text: 'Probabilidad '), TextSpan(text: summary.certainty.text)],
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          children: [
                            const TextSpan(text: 'Probabilidad ', style: TextStyle(color: Colors.white)),
                            TextSpan(text: summary.certainty.text, style: TextStyle(color: summary.certainty.color)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.0,
        mainAxisSpacing: 12.0,
        childAspectRatio: 0.75,
      ),
      itemCount: _classifiedLeaves.length,
      itemBuilder: (context, index) {
        final classifiedLeaf = _classifiedLeaves[index];
        final certaintyStyle = _getCertaintyStyle(classifiedLeaf.confidence);
        final Uint8List imageBytes = Uint8List.fromList(img.encodeJpg(classifiedLeaf.image));

        return GestureDetector(
          onTap: () async {
            final String tempImagePath = await _saveImageToTempFile(classifiedLeaf.image);
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ClassificationScreen(imagePath: tempImagePath)),
              );
            }
          },
          child: Card(
            elevation: 4.0,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0), side: const BorderSide(color: Colors.black, width: 2)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: const Color.fromRGBO(0, 106, 94, 1.0),
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Text(classifiedLeaf.label.replaceAll('\r', ''), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    color: Colors.black.withOpacity(0.05),
                    child: Image.memory(imageBytes, fit: BoxFit.contain),
                  ),
                ),
                Container(
                  color: const Color.fromRGBO(0, 106, 94, 1.0),
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    children: [
                      const Text("Probabilidad", style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                      Stack(
                        children: [
                          Text(
                            certaintyStyle.text,
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..color = Colors.black),
                          ),
                          Text(certaintyStyle.text, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: certaintyStyle.color)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
