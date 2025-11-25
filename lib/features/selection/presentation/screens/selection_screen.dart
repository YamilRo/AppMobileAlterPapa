import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pruebaa/features/camera/presentation/screens/camera_screen.dart';
import 'package:pruebaa/features/classification/presentation/screens/detection_screen.dart';

class SelectionScreen extends StatelessWidget {
  const SelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
      ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo aplicacion
              Container(
                width: 300,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(
                    color: Color.fromRGBO(23, 29, 27, 0.2),
                    width: 2,
                  ),
                  borderRadius:  BorderRadius.circular(5),
                ),
                child: Column(
                  children: [
                    Text(
                      'AlterPapa',
                      style: TextStyle(
                        fontSize: 52, // Texto más grande
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 8), // Espacio entre título y descripción
                    Text(
                      'Diagnósico de tizón temprano en papa',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54, // Color más tenue para la descripción
                      ),
                      textAlign: TextAlign.center, // Centrar texto
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),

              //Boton de CAMARA
              SizedBox(
                width: 300, // Ancho fijo para ambos botones
                height: 56,
                child: ElevatedButton(
                  // Evento al presionar el boton
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CameraScreen()),
                    );
                  },

                  // Estilo del boton
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromRGBO(0, 106, 94, 1.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16), // Solo altura
                  ),

                  // Texto del boton
                  child: Text(
                    'Usar Cámara',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18, // Texto más grande
                    ),
                  ),
                ),
              ),
              SizedBox(height: 5),

              //Boton de seleccion por GALERIA
              SizedBox(
                width: 300, // Ancho fijo para ambos botones
                height: 56,
                child: ElevatedButton(
                  // Evento al presionar el boton
                  onPressed: () async {
                    final picker = ImagePicker();
                    final image = await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetectionScreen(imagePath: image.path), //ClassificationScreen(imagePath: image.path),
                        ),
                      );
                    }
                  },

                  // Estilo del boton
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromRGBO(0, 106, 94, 1.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16), // Solo altura
                  ),

                  // Texto del boton
                  child: Text(
                    'Elegir Archivo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18, // Texto más grande
                    ),
                  ),
                ),
              ),
              SizedBox(height: 5),
            ],
          ),
        ),
    );
  }
}