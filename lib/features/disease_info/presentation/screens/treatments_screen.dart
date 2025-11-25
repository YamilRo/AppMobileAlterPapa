import 'package:flutter/material.dart';

class TreatmentsScreen extends StatefulWidget {
  final String diseaseName;
  final double maxSpotSizeCm;

  const TreatmentsScreen({
    Key? key,
    required this.diseaseName,
    required this.maxSpotSizeCm,
  }) : super(key: key);

  @override
  _TreatmentsScreenState createState() => _TreatmentsScreenState();
}

class _TreatmentsScreenState extends State<TreatmentsScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();

  // Estado para los pasos
  int? _step1Selection = 1;
  int? _step2Selection = 1;
  int _finalStepTabIndex = 0;

  final List<String> _step1Images = [
    "assets/images/fenologia-de-la-papa-1.jpg",
    "assets/images/fenologia-de-la-papa-2.jpg",
    "assets/images/fenologia-de-la-papa-3.jpg",
    "assets/images/fenologia-de-la-papa-4.jpg",
  ];

  final List<String> _step1Titles = [
    "Etapa 1: Primeras capa de hojas en crecimiento",
    "Etapa 2: Segunda capa de hojas en crecimiento",
    "Etapa 3: Floración de la planta de papa",
    "Etapa 4: Planta lista para cosechar",
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
  }

  void _previousPage() {
    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tratamiento para ${widget.diseaseName.replaceAll('\r', '')}'),
        backgroundColor: const Color.fromRGBO(0, 106, 94, 1.0),
      ),
      backgroundColor: Colors.grey[200],
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildStep1(),
          _buildStep2(),
          _buildResultScreen(),
        ],
      ),
    );
  }

  // --- PASO 1 ---
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepHeader(stepText: "Paso 1", instructionText: "Identificar la madurez del cultivo"),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.5), borderRadius: BorderRadius.circular(12), color: Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Seleccione la etapa más acorde a su cultivo", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.7),
                      itemCount: 4,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () => setState(() => _step1Selection = index + 1),
                          child: Container(
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _step1Selection == (index + 1) ? Theme.of(context).primaryColor : Colors.grey[400]!, width: 2.5)),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Text(_step1Titles[index], textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600), maxLines: 2),
                                ),
                                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.asset(_step1Images[index], fit: BoxFit.fitHeight, width: double.infinity))),
                                Radio<int>(value: index + 1, groupValue: _step1Selection, onChanged: (value) => setState(() => _step1Selection = value)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildFooter([_buildNavButton("Siguiente", _nextPage)]),
      ],
    );
  }

  // --- PASO 2 ---
  Widget _buildStep2() {
    return Column(
      children: [
        _buildStepHeader(stepText: "Paso 2", instructionText: "Identificar tipo de semilla plantada"),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.5), borderRadius: BorderRadius.circular(12), color: Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("¿Cuánto tiempo tarda en crecer su cultivo de papa?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildRadioTile("3 a 4 meses", 1),
                  _buildRadioTile("5 a 6 meses", 2),
                ],
              ),
            ),
          ),
        ),
        _buildFooter([
          _buildNavButton("Atrás", _previousPage, isSecondary: true),
          const SizedBox(width: 16),
          _buildNavButton("Siguiente", _nextPage),
        ]),
      ],
    );
  }

  // --- PANTALLA FINAL ---
  Widget _buildResultScreen() {
    return Column(
      children: [
        _buildStepHeader(stepText: "Tratamiento Identificado", instructionText: ""),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(children: [_buildFinalStepButton("Control Manual", 0), const SizedBox(width: 12), _buildFinalStepButton("Control Químico", 1)]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: IndexedStack(
              index: _finalStepTabIndex,
              children: [
                _step1Selection == 4 ? _buildLateStageManualControl() : _buildEarlyStageManualControl(),
                _buildChemicalControlContent(),
              ],
            ),
          ),
        ),
        _buildFooter([_buildNavButton("Atrás", _previousPage)]),
      ],
    );
  }

  // --- LÓGICA MODIFICADA DE CONTROL QUÍMICO ---
  Widget _buildChemicalControlContent() {
    // Definir los umbrales de TAMAÑO DE MANCHA (cm)
    // Opción 1 (3-4 meses) -> Umbral 0.5 cm
    // Opción 2 (5-6 meses) -> Umbral 0.1 cm
    final double thresholdCm = (_step2Selection == 1) ? 0.5 : 0.1;

    // Condición: Si la mancha es menor al umbral, NO aplicar.
    if (widget.maxSpotSizeCm < thresholdCm) {
      return _buildDoNotApplyFungicideScreen();
    }

    // Si es mayor o igual, SÍ aplicar.
    return _buildApplyFungicideScreen();
  }

  // --- PANTALLA DE NO APLICAR MODIFICADA ---
  Widget _buildDoNotApplyFungicideScreen() {
    return _buildContentCard(
      ListView(
        padding: EdgeInsets.zero,
        children: [
          const Text("Aún no es momento de aplicar fungicidas", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          const Align(alignment: Alignment.centerLeft, child: Text("¿Por qué?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          const Divider(),
          const SizedBox(height: 8),

          // Solo mostramos la imagen de manchas pequeñas, centrada o ocupando el ancho
          SizedBox(
            height: 180,
            child: Row( // Usamos Row para centrar si quieres, o un solo widget
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildImageWithTitle(
                    "assets/images/manchas_pequenhas.jpg",
                    "Las manchas son muy pequeñas\n(Est.: ${widget.maxSpotSizeCm.toStringAsFixed(2)} cm)" // Agregamos el tamaño estimado
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Align(alignment: Alignment.centerLeft, child: Text("Acciones a tomar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          const Divider(),
          const SizedBox(height: 8),
          const Text("Comprar fungicidas e implementos como:"),
          const SizedBox(height: 8),
          _buildNumberedListItem(1, "Mancozeb 80"),
          _buildNumberedListItem(2, "Mochila de aplicación"),
          _buildNumberedListItem(3, "Guantes"),
          _buildNumberedListItem(4, "Mascarilla"),
          const SizedBox(height: 24),
          const Center(child: Text("Realizar revisión en 7 días", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildApplyFungicideScreen() {
    return _buildContentCard(
      ListView(
        children: [
          const Text("Es momento de aplicar fungicidas", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          const Align(alignment: Alignment.centerLeft, child: Text("¿Qué debo hacer?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          const Divider(),
          _buildRecommendationItem("Agregar 36g o 3 cucharadas soperas de Mancozeb por cada 20 Litros de agua en una mochila pulverizadora."),
          _buildRecommendationItem("Aplicar sobre todas las hojas del cultivo, asegurándose de cubrir ambos lados de las hojas."),
          _buildRecommendationItem("Realizar repeticiones cada 7 días mientras haya calor y humedad constante."),
        ],
      ),
    );
  }

  Widget _buildEarlyStageManualControl() {
    return _buildContentCard(
      ListView(
        padding: EdgeInsets.zero,
        children: [
          const Text("Cambiar método de riego", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(),
          SizedBox(
            height: 150,
            child: Row(
              children: [
                _buildImageWithTitle("assets/images/riegoaspersion_portada.jpg", "Si utiliza riego por aspersión"),
                const SizedBox(width: 8),
                _buildImageWithTitle("assets/images/riego-por-goteo.jpeg", "Cambiar por riego por goteo"),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text("Separar cultivos", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(),
          const Text("Separar el cultivo de papa de otras plantas", style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: Image.asset("assets/images/apartar-plantas.jpg", fit: BoxFit.contain, width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _buildLateStageManualControl() {
    return _buildContentCard(
      ListView(
        padding: EdgeInsets.zero,
        children: [
          const Text("Quemar plantas afectadas", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(),
          const Text("Deseche o queme hojas, tubérculos y tallos con manchas marrones luego de la cosecha. No deje restos en el suelo."),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: Image.asset("assets/images/quemar-hojas-tallos.jpg", fit: BoxFit.contain, width: double.infinity),
          ),
          const SizedBox(height: 24),
          const Text("Separar semillas en mal estado", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(),
          const Text("No utilice para sembrar tubérculos con manchas marrones como en la imagen."),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: Image.asset("assets/images/papa-infectada.png", fit: BoxFit.contain, width: double.infinity),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS REUTILIZABLES ---

  Widget _buildImageWithTitle(String imagePath, String title, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Column(children: [Expanded(child: Image.asset(imagePath, fit: BoxFit.cover, width: double.infinity)), const SizedBox(height: 4), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))]),
    );
  }

  Widget _buildNumberedListItem(int number, String text) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4.0), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("$number. "), Expanded(child: Text(text))]));
  }

  Widget _buildRecommendationItem(String text) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.arrow_right, color: Colors.green), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(fontSize: 16)))]));
  }

  Widget _buildStepHeader({required String stepText, required String instructionText}) {
    return Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildStrokedText(stepText, size: 20), if (instructionText.isNotEmpty) ...[const SizedBox(height: 4), Text(instructionText, textAlign: TextAlign.left, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w800))]]));
  }

  Widget _buildFinalStepButton(String text, int index) {
    bool isSelected = _finalStepTabIndex == index;
    return Expanded(child: GestureDetector(onTap: () => setState(() => _finalStepTabIndex = index), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: isSelected ? const Color.fromRGBO(0, 26, 32, 1.0) : const Color.fromRGBO(0, 106, 94, 1.0), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2))]), child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))));
  }

  Widget _buildContentCard(Widget content) {
    return Container(width: double.infinity, height: double.infinity, padding: const EdgeInsets.all(16.0), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black)), child: content);
  }

  Widget _buildFooter(List<Widget> buttons) {
    return Container(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), color: Colors.white, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: buttons.map((button) => Expanded(child: button)).toList()));
  }

  Widget _buildNavButton(String text, VoidCallback onPressed, {bool isSecondary = false}) {
    return ElevatedButton(onPressed: onPressed, style: ElevatedButton.styleFrom(backgroundColor: isSecondary ? Colors.grey[700] : const Color.fromRGBO(0, 106, 94, 1.0), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(text, style: const TextStyle(fontSize: 18, color: Colors.white)));
  }

  Widget _buildRadioTile(String title, int value) {
    return Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(border: Border.all(color: _step2Selection == value ? Theme.of(context).primaryColor : Colors.grey, width: 1.5), borderRadius: BorderRadius.circular(8)), child: RadioListTile<int>(title: Text(title), value: value, groupValue: _step2Selection, onChanged: (val) => setState(() => _step2Selection = val), activeColor: Theme.of(context).primaryColor));
  }

  Widget _buildStrokedText(String text, {double size = 20}) {
    return Container(width: double.infinity, child: Stack(alignment: Alignment.centerLeft, children: [Text(text, style: TextStyle(fontSize: size, fontWeight: FontWeight.bold, foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..color = Colors.black)), Text(text, style: TextStyle(fontSize: size, fontWeight: FontWeight.bold, color: Colors.white))]));
  }
}
