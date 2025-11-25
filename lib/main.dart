import 'package:flutter/material.dart';
import 'package:pruebaa/app.dart';
import 'package:pruebaa/core/services/tflite_service.dart';

Future<void> main() async {
  // Asegurar los bindings de Flutter
  WidgetsFlutterBinding.ensureInitialized();

  //Cargar los modelos de la app
  await TFLiteService().loadModelsAndLabels();

  runApp(const MyApp());
}
