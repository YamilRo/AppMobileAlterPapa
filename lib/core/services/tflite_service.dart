import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'dart:collection';

class ClassificationResult {
  final int predictedClass;
  final String predictedLabel;
  final List<double> output;
  final Color labelColor;

  ClassificationResult({
    required this.predictedClass,
    required this.predictedLabel,
    required this.output,
    required this.labelColor,
  });

  // Helper para obtener el color basado en la clase predicha.
  static Color _getColorForClass(int predictedClass) {
    switch (predictedClass) {
      case 0:
        return Colors.orange;
      case 1:
        return Colors.green;
      case 2:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/// Contiene el resultado de una inferencia de segmentación.
class SegmentationResult {
  final img.Image overlayedImage;
  final double affectedAreaRatio;
  final int leafCount;
  final int spotCount;
  final double maxSpotSizeCm; // Nuevo campo

  SegmentationResult({
    required this.overlayedImage,
    required this.affectedAreaRatio,
    required this.leafCount,
    required this.spotCount,
    required this.maxSpotSizeCm,
  });
}

/// Contiene el resultado de una inferencia de detección.
class DetectionResult {
  final List<img.Image> detectedObjects;
  final List<Rect> boundingBoxes; // Coordenadas relativas (0.0 a 1.0)
  final int objectCount;

  DetectionResult({
    required this.detectedObjects,
    required this.boundingBoxes,
    required this.objectCount,
  });
}

// Clase auxiliar para NMS
class _CandidateBox {
  final Rect box;
  final double score;
  _CandidateBox(this.box, this.score);
}



// Una clase simple para almacenar coordenadas de píxeles
class _PixelCoord {
  final int x;
  final int y;

  _PixelCoord(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is _PixelCoord && runtimeType == other.runtimeType && x == other.x && y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

/// Resultado del análisis de conectividad.
class ConnectivityResult {
  final int leafCount;
  final int spotsOnLeafCount;
  final double maxSpotSizeCm; // Nuevo campo

  ConnectivityResult(this.leafCount, this.spotsOnLeafCount, this.maxSpotSizeCm);
}

/// Analiza la máscara para contar, medir y filtrar.
ConnectivityResult analyzeConnectivity(List<List<int>> classMask) {
  if (classMask.isEmpty || classMask[0].isEmpty) {
    return ConnectivityResult(0, 0, 0.0);
  }

  int height = classMask.length;
  int width = classMask[0].length;
  var visited = List.generate(height, (_) => List.filled(width, false));

  // Listas para guardar la longitud máxima (en píxeles) de cada objeto encontrado
  List<double> leafLengths = [];
  List<double> spotLengths = [];

  // Configuración: Longitud mínima para considerar algo como una "hoja" real y no ruido
  const double minLeafLengthPx = 15.0;

  // 1. Encontrar componentes y calcular sus dimensiones
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      if (visited[y][x]) continue;

      int currentClass = classMask[y][x];
      // Clase 1: Mancha, Clase 2: Hoja
      if (currentClass == 1 || currentClass == 2) {
        // _findComponentDimensions devuelve la longitud diagonal del objeto
        double objectLength = _findComponentDimensions(classMask, visited, x, y, currentClass);

        if (currentClass == 2) {
          // Solo contamos hojas si superan el umbral de ruido
          if (objectLength >= minLeafLengthPx) {
            leafLengths.add(objectLength);
          }
        } else {
          // Las manchas suelen ser pequeñas, las guardamos todas (o puedes poner un umbral mínimo menor)
          spotLengths.add(objectLength);
        }
      }
    }
  }

  // 2. Calcular estadísticas
  int validLeafCount = leafLengths.length;

  // Buscamos la hoja más grande y la mancha más grande (en píxeles)
  double maxLeafPx = leafLengths.isNotEmpty ? leafLengths.reduce(max) : 0.0;
  double maxSpotPx = spotLengths.isNotEmpty ? spotLengths.reduce(max) : 0.0;

  // 3. Aproximación a Centímetros
  // Asumimos que la hoja más grande encontrada mide aprox 7cm en la realidad.
  double maxSpotSizeCm = 0.0;

  if (maxLeafPx > 0) {
    // Regla de 3: Si maxLeafPx es 7cm, entonces maxSpotPx es X cm.
    double pixelsToCmRatio = 6.0 / maxLeafPx;
    maxSpotSizeCm = maxSpotPx * pixelsToCmRatio;
  }

  int spotCount = spotLengths.length;

  return ConnectivityResult(validLeafCount, spotCount, maxSpotSizeCm);
}

/// BFS que calcula el Bounding Box y devuelve la diagonal (longitud)
double _findComponentDimensions(
    List<List<int>> mask,
    List<List<bool>> visited,
    int startX,
    int startY,
    int targetClass) {

  int height = mask.length;
  int width = mask[0].length;

  // Variables para trackear los límites
  int minX = startX;
  int maxX = startX;
  int minY = startY;
  int maxY = startY;

  Queue<_PixelCoord> queue = Queue();
  queue.add(_PixelCoord(startX, startY));
  visited[startY][startX] = true;

  while (queue.isNotEmpty) {
    _PixelCoord current = queue.removeFirst();

    // Actualizar límites del Bounding Box
    if (current.x < minX) minX = current.x;
    if (current.x > maxX) maxX = current.x;
    if (current.y < minY) minY = current.y;
    if (current.y > maxY) maxY = current.y;

    for (var neighbor in _get8WayNeighbors(current, width, height)) {
      if (!visited[neighbor.y][neighbor.x] && mask[neighbor.y][neighbor.x] == targetClass) {
        visited[neighbor.y][neighbor.x] = true;
        queue.add(neighbor);
      }
    }
  }

  // Calcular distancia diagonal del bounding box (Teorema de Pitágoras)
  double w = (maxX - minX).toDouble() + 1; // +1 porque si maxX==minX el ancho es 1 pixel
  double h = (maxY - minY).toDouble() + 1;

  return sqrt((w * w) + (h * h));
}

/// Algoritmo BFS (Flood-fill) para encontrar un componente conectado.
void _findComponent(
    List<List<int>> mask,
    List<List<bool>> visited,
    int startX,
    int startY,
    int targetClass,
    List<_PixelCoord> component) {

  int height = mask.length;
  int width = mask[0].length;
  Queue<_PixelCoord> queue = Queue();

  queue.add(_PixelCoord(startX, startY));
  visited[startY][startX] = true;
  component.add(_PixelCoord(startX, startY));

  while (queue.isNotEmpty) {
    _PixelCoord current = queue.removeFirst();

    for (var neighbor in _get8WayNeighbors(current, width, height)) {
      if (!visited[neighbor.y][neighbor.x] && mask[neighbor.y][neighbor.x] == targetClass) {
        visited[neighbor.y][neighbor.x] = true;
        component.add(neighbor);
        queue.add(neighbor);
      }
    }
  }
}

/// Devuelve los vecinos válidos (8 direcciones) de un píxel.
Iterable<_PixelCoord> _get8WayNeighbors(_PixelCoord pixel, int width, int height) sync* {
  for (int dy = -1; dy <= 1; dy++) {
    for (int dx = -1; dx <= 1; dx++) {
      if (dx == 0 && dy == 0) continue; // No es vecino

      int nx = pixel.x + dx;
      int ny = pixel.y + dy;

      // Comprobar límites
      if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
        yield _PixelCoord(nx, ny);
      }
    }
  }
}


class TFLiteService {
  static final TFLiteService _instance = TFLiteService._internal();

  factory TFLiteService() {
    return _instance;
  }

  // Constructor interno privado
  TFLiteService._internal();

  Interpreter? _classificationInterpreter;
  Interpreter? _segmentationInterpreter;
  Interpreter? _detectionInterpreter;
  List<String> _labels = [];

  // Getters para acceder a los modelos y etiquetas de forma segura
  Interpreter? get classificationInterpreter => _classificationInterpreter;
  Interpreter? get segmentationInterpreter => _segmentationInterpreter;
  Interpreter? get detectionInterpreter => _detectionInterpreter;
  List<String> get labels => _labels;

  Future<void> loadModelsAndLabels() async {
    if (_classificationInterpreter != null && _segmentationInterpreter != null && _labels.isNotEmpty) {
      print("Modelos y etiquetas ya están cargados.");
      return;
    }

    try {
      print("Cargando modelos y etiquetas...");
      final classificationOptions = InterpreterOptions();
      _classificationInterpreter = await Interpreter.fromAsset('assets/models/diagnostico.tflite', options: classificationOptions);

      final segmentationOptions = InterpreterOptions();
      _segmentationInterpreter = await Interpreter.fromAsset('assets/models/medir.tflite', options: segmentationOptions);

      final detectionInterpreter = InterpreterOptions();
      _detectionInterpreter = await Interpreter.fromAsset('assets/models/detection.tflite', options: detectionInterpreter);

      final labelData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelData.split('\n').where((label) => label.isNotEmpty).toList();

      print("Modelos y etiquetas cargados exitosamente.");
    } catch (e) {
      print("Error al cargar modelos o etiquetas: $e");
    }
  }

  Future<List<List<List<List<double>>>>> preprocessImageDetection(String imagePath) async {
    // 1. Cargar y decodificar la imagen
    final imageBytes = await File(imagePath).readAsBytes();
    final img.Image? baseImage = img.decodeImage(imageBytes);

    if (baseImage == null) {
      throw Exception("No se pudo decodificar la imagen en la ruta: $imagePath");
    }

    // 2. Redimensionar la imagen
    final img.Image resizedImage = img.copyResize(
      baseImage,
      width: 768,
      height: 768,
      interpolation: img.Interpolation.linear,
    );


    // 3. --- Construir el tensor 4D manualmente ---
    // En lugar de un Float32List, creamos la estructura anidada que coincide con [1, 768, 768, 3]
    var tensor = List.generate(
      1,
          (_) => List.generate(
        768, // height
            (y) => List.generate(
          768, // width
              (x) {
            final pixel = resizedImage.getPixel(x, y);
            // Normaliza los valores y los devuelve como una lista de 3 doubles (RGB)
            return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
          },
        ),
      ),
    );

    return tensor;
  }

  Future<List<List<List<List<double>>>>> preprocessImageClassification(String imagePath) async {
    final image = img.decodeImage(File(imagePath).readAsBytesSync())!;
    final resizedImage = img.copyResize(image, width: 224, height: 224);

    // Crear el tensor de entrada en tres dimensiones
    List<List<List<double>>> input = List.generate(224, (i) =>
        List.generate(224, (j) =>
            List.filled(3, 0.0)));

    // Normalizar la imagen
    for (int x = 0; x < 224; x++) {
      for (int y = 0; y < 224; y++) {
        final pixel = resizedImage.getPixel(x, y);
        input[x][y][0] = pixel.r.toDouble();  // Canal R
        input[x][y][1] = pixel.g.toDouble(); // Canal G
        input[x][y][2] = pixel.b.toDouble();  // Canal B
      }
    }

    return [input];
  }

  Future<List<List<List<List<double>>>>> preprocessImageSegmentation(String imagePath) async {
    final image = img.decodeImage(File(imagePath).readAsBytesSync())!;
    final resizedImage = img.copyResize(image, width: 128, height: 128);

    List<List<List<double>>> input = List.generate(128, (i) =>
        List.generate(128, (j) =>
            List.filled(3, 0.0)));

    // Normalize the image
    for (int x = 0; x < 128; x++) {
      for (int y = 0; y < 128; y++) {
        final pixel = resizedImage.getPixel(x, y);
        input[x][y][0] = (pixel.r.toDouble() / 225.0);
        input[x][y][1] = (pixel.g.toDouble() / 225.0);
        input[x][y][2] = (pixel.b.toDouble() / 225.0);

        final temp = input[x][y][0];
        input[x][y][0] = input[x][y][2];
        input[x][y][2] = temp;
      }
    }

    return [input];
  }

  /// Ejecuta la inferencia de clasificación y devuelve un resultado estructurado.
  ClassificationResult makeInferenceClassification(List<List<List<List<double>>>> input) {
    if (_classificationInterpreter == null) throw Exception("Modelo de clasificación no cargado.");
    if (_labels.isEmpty) throw Exception("Etiquetas no cargadas.");

    // La salida es [1, 3] para 3 clases.
    var output = List.filled(1 * 3, 0.0).reshape([1, 3]);
    _classificationInterpreter!.run(input, output);

    // Encuentra la clase con la probabilidad más alta.
    List<double> outputList = output[0];

    int predictedClass = (output[0]! as List<double>)
        .indexOf((output[0]! as List<double>).reduce((a, b) => a > b ? a : b));

    // Asegurarse de que el índice no esté fuera de los límites de las etiquetas.
    String predictedLabel = (predictedClass < _labels.length) ? _labels[predictedClass] : "Desconocido";

    return ClassificationResult(
      predictedClass: predictedClass,
      predictedLabel: predictedLabel,
      output: outputList,
      labelColor: ClassificationResult._getColorForClass(predictedClass),
    );
  }

  /// Ejecuta la inferencia de segmentación y devuelve la imagen superpuesta y el área afectada.
  SegmentationResult makeInferenceSegmentation(List<List<List<List<double>>>> segInput, String originalImagePath) {
    if (_segmentationInterpreter == null) throw Exception("Modelo de segmentación no cargado.");

    // La salida es [1, 128, 128, 3] para 3 clases (fondo, hoja, mancha).
    var segmentationOutput = List.generate(1, (_) => List.generate(128, (_) => List.generate(128, (_) => List.filled(3, 0.0))));
    _segmentationInterpreter!.run(segInput, segmentationOutput);

    // 1. Calcular área afectada
    int areaSpot = 0; // Clase 1 = Mancha
    int areaLeaf = 0; // Clase 2 = Hoja

    // Convertir la salida de 3 canales a una salida de 1 clase por píxel
    List<List<int>> classOutput = List.generate(128, (i) =>
        List.generate(128, (j) {
          var pixel = segmentationOutput[0][i][j]; // Acceder a la primera dimensión
          int pixelClass = pixel.indexOf(pixel.reduce((curr, next) => curr > next ? curr : next));
          if (pixelClass == 1) areaSpot++;
          if (pixelClass == 2) areaLeaf++;
          // Devuelve la clase con la probabilidad más alta (0 = fondo, 1 = hoja, 2 = mancha)
          return pixelClass;
        })
    );

    double affectedAreaRatio = (areaLeaf + areaSpot > 0) ? (areaSpot / (areaLeaf + areaSpot)) : 0.0;

    ConnectivityResult analysis = analyzeConnectivity(classOutput);

    // 2. Generar imagen superpuesta
    img.Image overlayedImage = _overlaySegmentation(originalImagePath, classOutput);

    return SegmentationResult(
      overlayedImage: overlayedImage,
      affectedAreaRatio: affectedAreaRatio,
      leafCount: analysis.leafCount,
      spotCount: analysis.spotsOnLeafCount,
      maxSpotSizeCm: analysis.maxSpotSizeCm,
    );
  }

  /// Ejecuta la inferencia de detección con NMS y devuelve los objetos recortados.
  Future<DetectionResult> makeInferenceDetection(List<List<List<List<double>>>> input, String originalImagePath, {double confidenceThreshold = 0.45, double iouThreshold = 0.5}) async {
    if (_detectionInterpreter == null) throw Exception("Modelo de detección no cargado.");

    final outputShape = _detectionInterpreter!.getOutputTensor(0).shape;
    final numClassesPlusBox = outputShape[1];
    final numProposals = outputShape[2];

    var output = List.generate(1, (_) => List.generate(numClassesPlusBox, (_) => List.filled(numProposals, 0.0)));
    _detectionInterpreter!.run(input, output);

    final List<_CandidateBox> candidates = [];

    // 1. Recolectar candidatos
    for (int i = 0; i < numProposals; i++) {
      final score = output[0][4][i];
      if (score > confidenceThreshold) {
        final cx = output[0][0][i];
        final cy = output[0][1][i];
        final w = output[0][2][i];
        final h = output[0][3][i];
        final x1 = (cx - w / 2);
        final y1 = (cy - h / 2);
        candidates.add(_CandidateBox(Rect.fromLTWH(x1, y1, w, h), score));
      }
    }

    // 2. Aplicar NMS
    final List<Rect> finalBoxes = _nonMaximumSuppression(candidates, iouThreshold);

    // 3. Recortar los objetos de la imagen original usando las cajas finales
    final originalImage = img.decodeImage(await File(originalImagePath).readAsBytes())!;
    final List<img.Image> detectedObjects = [];

    for (final box in finalBoxes) {
      final int cropX = max(0, (box.left * originalImage.width).round());
      final int cropY = max(0, (box.top * originalImage.height).round());
      final int cropW = (box.width * originalImage.width).round();
      final int cropH = (box.height * originalImage.height).round();

      // Validar que el recorte esté dentro de los límites
      if (cropX >= 0 && cropY >= 0 && cropX + cropW <= originalImage.width && cropY + cropH <= originalImage.height) {
        final croppedObject = img.copyCrop(originalImage, x: cropX, y: cropY, width: cropW, height: cropH);
        detectedObjects.add(croppedObject);
      }
    }

    return DetectionResult(
      detectedObjects: detectedObjects,
      boundingBoxes: finalBoxes, // Guardamos las coordenadas relativas
      objectCount: detectedObjects.length,
    );
  }

  /// Implementación del algoritmo de Supresión de No Máximos (NMS).
  List<Rect> _nonMaximumSuppression(List<_CandidateBox> candidates, double iouThreshold) {
    if (candidates.isEmpty) {
      return [];
    }

    // Ordenar las cajas por su puntuación de confianza de mayor a menor
    candidates.sort((a, b) => b.score.compareTo(a.score));

    List<Rect> finalBoxes = [];
    while (candidates.isNotEmpty) {
      // 1. Tomar la caja con la puntuación más alta y añadirla a la lista final
      final _CandidateBox bestBox = candidates.removeAt(0);
      finalBoxes.add(bestBox.box);

      // 2. Comparar esta caja con todas las demás
      List<_CandidateBox> remainingCandidates = [];
      for (final candidate in candidates) {
        final double iou = _calculateIoU(bestBox.box, candidate.box);
        // 3. Si el IoU es bajo, la caja no se superpone mucho y se conserva
        if (iou < iouThreshold) {
          remainingCandidates.add(candidate);
        }
      }

      // 4. Reemplazar la lista de candidatos con los que sobrevivieron
      candidates = remainingCandidates;
    }

    return finalBoxes;
  }

  /// Calcula el "Índice de Intersección sobre Unión" (IoU) entre dos rectángulos.
  double _calculateIoU(Rect boxA, Rect boxB) {
    // Determinar las coordenadas (x, y) del rectángulo de intersección
    final double xA = max(boxA.left, boxB.left);
    final double yA = max(boxA.top, boxB.top);
    final double xB = min(boxA.right, boxB.right);
    final double yB = min(boxA.bottom, boxB.bottom);

    // Calcular el área de la intersección. max(0, ...) asegura que si no se solapan, el área sea 0.
    final double intersectionArea = max(0, xB - xA) * max(0, yB - yA);

    // Calcular el área de ambos rectángulos
    final double boxAArea = boxA.width * boxA.height;
    final double boxBArea = boxB.width * boxB.height;

    // Calcular la unión: suma de las áreas menos el área de intersección
    final double unionArea = boxAArea + boxBArea - intersectionArea;

    // Calcular el IoU
    if (unionArea <= 0) {
      return 0.0;
    }
    return intersectionArea / unionArea;
  }


  /// Dibuja la máscara de segmentación sobre la imagen original.
  img.Image _overlaySegmentation(String imagePath, List<List<int>> classOutput) {
    final originalImage = img.decodeImage(File(imagePath).readAsBytesSync())!;
    final resizedImage = img.copyResize(originalImage, width: 128, height: 128);
    final overlayedImage = img.Image.from(resizedImage);

    final colorLeaf = img.ColorRgba8(0, 255, 0, 96); // Verde semitransparente
    final colorSpot = img.ColorRgba8(255, 0, 0, 96); // Rojo semitransparente

    for (int y = 0; y < 128; y++) {
      for (int x = 0; x < 128; x++) {
        final pixelClass = classOutput[y][x];
        img.Color? overlayColor;
        switch (pixelClass) {
          case 1: overlayColor = colorSpot; break; // Mancha
          case 2: overlayColor = colorLeaf; break; // Hoja
          default: break;
        }
        if (overlayColor != null) {
          // Dibuja el color de la máscara sobre la imagen. 'drawPixel' hace alpha blending.
          img.drawPixel(overlayedImage, y, x, overlayColor);
        }
      }
    }
    // Devuelve la imagen redimensionada al tamaño original
    return img.copyResize(overlayedImage, width: originalImage.width, height: originalImage.height);
  }

  void dispose() {
    _classificationInterpreter?.close();
    _segmentationInterpreter?.close();
    _detectionInterpreter?.close();
  }
}
