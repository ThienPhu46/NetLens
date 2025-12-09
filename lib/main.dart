import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screenshot/screenshot.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const ArSwitchScreen(),
    );
  }
}

// --- CLASS DỮ LIỆU (từ switch_ar.dart) ---
class PortData {
  final int portId;
  final String linkedDevice;
  final int status;
  final int vlan;

  PortData({
    required this.portId, 
    required this.linkedDevice, 
    required this.status,
    required this.vlan,
  });

  factory PortData.fromJson(Map<String, dynamic> json) {
    return PortData(
      portId: json['portId'] ?? 0,
      linkedDevice: json['linkedDevice'] ?? "",
      status: int.tryParse(json['Status'].toString()) ?? 0,
      vlan: int.tryParse(json['Vlan'].toString()) ?? 1,
    );
  }
}

class SwitchData {
  final String name;
  final String ip;
  final List<PortData> ports;

  SwitchData({required this.name, required this.ip, required this.ports});

  factory SwitchData.fromJson(Map<String, dynamic> json) {
    var list = json['port'] is List ? json['port'] as List : [];
    List<PortData> portList = list.map((i) => PortData.fromJson(i)).toList();
    return SwitchData(
      name: json['name'] ?? "",
      ip: json['ip'] ?? "",
      ports: portList,
    );
  }
}

class ArSwitchScreen extends StatefulWidget {
  const ArSwitchScreen({super.key});

  @override
  State<ArSwitchScreen> createState() => _ArSwitchScreenState();
}

class _ArSwitchScreenState extends State<ArSwitchScreen> with WidgetsBindingObserver {
  ArCoreController? arCoreController;
  late FlutterVision vision;
  final ScreenshotController screenshotController = ScreenshotController();
  
  bool hasPermission = false;
  bool isModelLoaded = false;
  bool isProcessing = false;
  
  Timer? scanTimer;
  String status = "Đang xin quyền...";
  
  bool frameVisible = false;
  DateTime lastDetectionTime = DateTime.now();
  
  vector.Vector3? lastStablePosition;
  int stabilityCounter = 0;
  
  List<double>? currentBoundingBox;
  double? currentConfidence;
  
  String? currentSwitchNodeName;
  String? currentLinesNodeName;
  String? currentLabelNodeName;

  // --- DỮ LIỆU SWITCH (từ switch_ar.dart) ---
  bool _showVlan = false;
  final Map<int, Color> _vlanColors = {
    1: Colors.blue[700]!,       
    2: Colors.orange[700]!,     
    3: Colors.green[700]!,      
    4: Colors.purple[700]!,     
    5: Colors.yellow[800]!,     
    6: Colors.red[700]!,        
    10: Colors.teal[700]!,
    20: Colors.brown[700]!,
  };

  final String jsonString1 = '''
  {
    "name": "SW Detected",
    "model": "Auto Detect",
    "ip": "192.168.1.1",
    "port": [
      { "portId": 1, "linkedDevice": "CS02-AP-D401","Status": 1, "Vlan": 1 },
      { "portId": 2, "linkedDevice": "CS02-AP-D402","Status": 1, "Vlan": 2 },
      { "portId": 3, "linkedDevice": "CS02-AP-D403","Status": 0, "Vlan": 4 },
      { "portId": 4, "linkedDevice": "CS02-AP-D404","Status": 1, "Vlan": 3 },
      { "portId": 5, "linkedDevice": "CS02-AP-D405","Status": 0, "Vlan": 5 },
      { "portId": 6, "linkedDevice": "Camera 2","Status": 1, "Vlan": 1 },
      { "portId": 7, "linkedDevice": "Printer","Status": 1, "Vlan": 2 },
      { "portId": 8, "linkedDevice": "Wifi AP","Status": 0, "Vlan": 3 },
      { "portId": 9, "linkedDevice": "Server","Status": 1, "Vlan": 4 },
      { "portId": 10, "linkedDevice": "Router","Status": 1, "Vlan": 1 },
      { "portId": 11, "linkedDevice": "","Status": 1, "Vlan": 2 },
      { "portId": 12, "linkedDevice": "Device D","Status": 0, "Vlan": 3 },
      { "portId": 13, "linkedDevice": "Device E","Status": 1, "Vlan": 4 },
      { "portId": 14, "linkedDevice": "Device F","Status": 1, "Vlan": 2 },
      { "portId": 15, "linkedDevice": "Device G","Status": 1, "Vlan": 3 },
      { "portId": 16, "linkedDevice": "Device H","Status": 0, "Vlan": 4 },
      { "portId": 17, "linkedDevice": "Device I","Status": 1, "Vlan": 5 },
      { "portId": 18, "linkedDevice": "Device J","Status": 1, "Vlan": 6 },
      { "portId": 19, "linkedDevice": "Device K","Status": 0, "Vlan": 4 },
      { "portId": 20, "linkedDevice": "Device L","Status": 1, "Vlan": 5 },
      { "portId": 21, "linkedDevice": "Device M","Status": 1, "Vlan": 6 },
      { "portId": 22, "linkedDevice": "Device N","Status": 0, "Vlan": 6 },
      { "portId": 23, "linkedDevice": "Device O","Status": 1, "Vlan": 2 },
      { "portId": 24, "linkedDevice": "Device P","Status": 1, "Vlan": 1 }
    ]
  }
  ''';

  late SwitchData switchData;
  Uint8List? _panelTextureCache;
  Uint8List? _linesTextureCache;
  Uint8List? _labelTextureCache;

  final double _switchWidth = 0.4;
  final double _switchHeight = 0.04445; 
  final double _linesHeight = 0.04445 * 3.0; 
  final double _labelWidth = 0.15;
  final double _labelHeight = 0.04;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    vision = FlutterVision();
    
    try {
      switchData = SwitchData.fromJson(jsonDecode(jsonString1));
    } catch (e) {
      print("Error parsing JSON: $e");
      switchData = SwitchData(name: "Error", ip: "", ports: []);
    }
    
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final cameraStatus = await Permission.camera.request();

    if (cameraStatus.isGranted) {
      setState(() { hasPermission = true; status = "Khởi động AR..."; });
      Future.delayed(const Duration(seconds: 1), _loadYoloModel);
    } else {
      setState(() { status = "❌ Cần quyền Camera!"; });
    }
  }

  Future<void> _loadYoloModel() async {
    try {
      setState(() { status = "Đang nạp AI..."; });
      await vision.loadYoloModel(
        labels: 'assets/labelmap.txt',
        modelPath: 'assets/detect.tflite', 
        modelVersion: "yolov8",
        quantization: true, 
        useGpu: false, 
      );
      setState(() {
        isModelLoaded = true;
        status = "✅ Sẵn sàng! Đang tự động quét...";
      });
      _startAutoScan(); 
    } catch (e) {
      setState(() { status = "❌ Lỗi Model: ${e.toString()}"; });
    }
  }

  void _startAutoScan() {
    scanTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (isModelLoaded && !isProcessing && arCoreController != null && mounted) {
        _captureAndDetect();
      }
    });
  }

  void _captureAndDetect() async { 
    setState(() { isProcessing = true; });

    try {
      final Uint8List? imageBytes = await screenshotController.capture(pixelRatio: 1.0); 
      
      if (imageBytes != null) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;

        final results = await vision.yoloOnImage(
          bytesList: imageBytes,
          imageHeight: screenHeight.toInt(),
          imageWidth: screenWidth.toInt(),
          confThreshold: 0.4,
          classThreshold: 0.5,
        );

        if (results.isNotEmpty) {
          final topResult = results.first;
          if (topResult['tag'] == 'Switch') {
            lastDetectionTime = DateTime.now(); 
            
            setState(() {
              currentBoundingBox = [
                topResult['box'][0].toDouble(),
                topResult['box'][1].toDouble(),
                topResult['box'][2].toDouble(),
                topResult['box'][3].toDouble(),
              ];
              currentConfidence = topResult['box'][4]?.toDouble() ?? 0.0;
              status = "✅ Đã bắt được Switch!";
            });
            
            _placeSwitch2D(topResult['box'], screenWidth, screenHeight); 
          }
        } else {
          setState(() {
            currentBoundingBox = null;
          });
        }
      }
    } catch (e) {
      print("Lỗi quét: $e");
    } finally {
      if (mounted) setState(() { isProcessing = false; });
    }
  }
  
  // 🔥 HÀM ĐẶT SWITCH 2D TẠI VỊ TRÍ PHÁT HIỆN
  void _placeSwitch2D(List<dynamic> box, double screenWidth, double screenHeight) async {
    if (arCoreController == null) return;

    // Tính khoảng cách Z
    final double boxHeight = (box[3] - box[1]).toDouble();
    const double REAL_SWITCH_HEIGHT = 0.044;
    const double FOV_VERTICAL = 60.0;
    const double FOV_RAD = FOV_VERTICAL * math.pi / 180.0;
    
    double distance = (REAL_SWITCH_HEIGHT * screenHeight) / (2 * boxHeight * math.tan(FOV_RAD / 2));
    distance = distance.clamp(0.3, 5.0);
    
    // Tính tọa độ X,Y 
    final double centerX = (box[0] + box[2]) / 2.0;
    final double centerY = (box[1] + box[3]) / 2.0;
    
    final double ndcX = (centerX / screenWidth) * 2.0 - 1.0;
    final double ndcY = -((centerY / screenHeight) * 2.0 - 1.0);
    
    final double aspectRatio = screenWidth / screenHeight;
    final double fovHorizontal = 2 * math.atan(math.tan(FOV_RAD / 2) * aspectRatio);
    
    final double frustumHeight = 2.0 * distance * math.tan(FOV_RAD / 2);
    final double frustumWidth = 2.0 * distance * math.tan(fovHorizontal / 2);
    
    double worldX = ndcX * (frustumWidth / 2.0);
    double worldY = ndcY * (frustumHeight / 2.0);
    double worldZ = -distance;
    
    worldY -= 0.25; // Hạ thấp 25cm
    
    vector.Vector3 newPosition = vector.Vector3(worldX, worldY, worldZ);

    // Xóa switch cũ nếu có
    _removeSwitch2D();

    // Tạo texture cho switch
    await _generateSwitchTextures();

    // Tạo các node mới
    String baseName = "Switch2D_${DateTime.now().millisecondsSinceEpoch}";
    currentSwitchNodeName = "${baseName}_panel";
    currentLinesNodeName = "${baseName}_lines";
    currentLabelNodeName = "${baseName}_label";

    final switchNode = _createNode(
      name: currentSwitchNodeName!,
      texture: _panelTextureCache,
      position: newPosition,
      size: vector.Vector3(_switchWidth, _switchHeight, 0.0001),
    );

    final linesNode = _createNode(
      name: currentLinesNodeName!,
      texture: _linesTextureCache,
      position: vector.Vector3(newPosition.x, newPosition.y, newPosition.z - 0.0005),
      size: vector.Vector3(_switchWidth, _linesHeight, 0.0001),
    );

    final labelPosition = vector.Vector3(
      newPosition.x - (_switchWidth / 2) - (_labelWidth / 2) - 0.01,
      newPosition.y,
      newPosition.z,
    );

    final labelNode = _createNode(
      name: currentLabelNodeName!,
      texture: _labelTextureCache,
      position: labelPosition,
      size: vector.Vector3(_labelWidth, _labelHeight, 0.0001),
    );

    arCoreController!.addArCoreNode(switchNode);
    arCoreController!.addArCoreNode(linesNode);
    arCoreController!.addArCoreNode(labelNode);

    frameVisible = true;
    lastStablePosition = newPosition;
    
    setState(() { 
      status = "⚓ Switch 2D đã neo - ${distance.toStringAsFixed(2)}m";
    });
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    print("🎯 TẠO SWITCH 2D: $baseName");
    print("   X = ${newPosition.x.toStringAsFixed(4)} m");
    print("   Y = ${newPosition.y.toStringAsFixed(4)} m");
    print("   Z = ${newPosition.z.toStringAsFixed(4)} m");
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  }

  Future<void> _generateSwitchTextures() async {
    _panelTextureCache = await _createSwitchPanelTexture(
      data: switchData,
      arWidth: _switchWidth,
      arHeight: _switchHeight,
      showVlan: _showVlan, 
    );
    _linesTextureCache = await _createLinesTexture(
      data: switchData,
      arWidth: _switchWidth,
      arHeight: _linesHeight,
      arBaseHeight: _switchHeight,
      showVlan: _showVlan, 
    );
    _labelTextureCache = await _createLabelTexture(
      data: switchData,
      arWidth: _labelWidth,
      arHeight: _labelHeight,
    );
  }

  ArCoreNode _createNode({
    required String name,
    required Uint8List? texture,
    required vector.Vector3 position,
    required vector.Vector3 size,
  }) {
    final material = ArCoreMaterial(
      textureBytes: texture,
      color: Colors.black.withOpacity(0.0),
      metallic: 0.0,
      reflectance: 0.0,
      roughness: 1.0,
    );

    final shape = ArCoreCube(
      materials: [material],
      size: size,
    );

    return ArCoreNode(
      shape: shape,
      position: position,
      name: name,
    );
  }

  void _removeSwitch2D() {
    if (currentSwitchNodeName != null) {
      try {
        arCoreController?.removeNode(nodeName: currentSwitchNodeName!);
      } catch (e) {}
    }
    if (currentLinesNodeName != null) {
      try {
        arCoreController?.removeNode(nodeName: currentLinesNodeName!);
      } catch (e) {}
    }
    if (currentLabelNodeName != null) {
      try {
        arCoreController?.removeNode(nodeName: currentLabelNodeName!);
      } catch (e) {}
    }
    
    frameVisible = false;
    lastStablePosition = null;
    stabilityCounter = 0;
    currentBoundingBox = null;
    currentSwitchNodeName = null;
    currentLinesNodeName = null;
    currentLabelNodeName = null;
  }

  void _onArCoreViewCreated(ArCoreController controller) {
    arCoreController = controller;
    _clearAllNodes(); 
  }
  
  void _clearAllNodes() {
    if (arCoreController != null) {
      _removeSwitch2D();
    }
  }

  void _toggleVlan() async {
    setState(() {
      _showVlan = !_showVlan;
    });

    if (arCoreController == null || !frameVisible) return;

    // Regenerate textures
    await _generateSwitchTextures();

    // Update nodes
    if (currentSwitchNodeName != null && lastStablePosition != null) {
      _removeSwitch2D();
      
      // Recreate at same position
      String baseName = "Switch2D_${DateTime.now().millisecondsSinceEpoch}";
      currentSwitchNodeName = "${baseName}_panel";
      currentLinesNodeName = "${baseName}_lines";
      currentLabelNodeName = "${baseName}_label";

      final switchNode = _createNode(
        name: currentSwitchNodeName!,
        texture: _panelTextureCache,
        position: lastStablePosition!,
        size: vector.Vector3(_switchWidth, _switchHeight, 0.0001),
      );

      final linesNode = _createNode(
        name: currentLinesNodeName!,
        texture: _linesTextureCache,
        position: vector.Vector3(lastStablePosition!.x, lastStablePosition!.y, lastStablePosition!.z - 0.0005),
        size: vector.Vector3(_switchWidth, _linesHeight, 0.0001),
      );

      final labelPosition = vector.Vector3(
        lastStablePosition!.x - (_switchWidth / 2) - (_labelWidth / 2) - 0.01,
        lastStablePosition!.y,
        lastStablePosition!.z,
      );

      final labelNode = _createNode(
        name: currentLabelNodeName!,
        texture: _labelTextureCache,
        position: labelPosition,
        size: vector.Vector3(_labelWidth, _labelHeight, 0.0001),
      );

      arCoreController!.addArCoreNode(switchNode);
      arCoreController!.addArCoreNode(linesNode);
      arCoreController!.addArCoreNode(labelNode);

      frameVisible = true;
    }
  }

  Set<int> _getActiveVlans() {
    Set<int> vlans = {};
    for (var port in switchData.ports) {
      vlans.add(port.vlan);
    }
    return vlans;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    scanTimer?.cancel();
    arCoreController?.dispose();
    vision.closeYoloModel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!hasPermission) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final List<int> sortedVlans = _getActiveVlans().toList()..sort();

    return Scaffold(
      body: Stack(
        children: [
          Screenshot(
            controller: screenshotController,
            child: ArCoreView(
              onArCoreViewCreated: _onArCoreViewCreated,
              enableTapRecognizer: true,
            ),
          ),
          
          if (currentBoundingBox != null)
            CustomPaint(
              size: MediaQuery.of(context).size,
              painter: BoundingBoxPainter(
                currentBoundingBox!,
                currentConfidence ?? 0.0,
              ),
            ),

          // VLAN Legend
          if (_showVlan && frameVisible)
            Positioned(
              top: 50,
              left: 20,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Chú thích VLAN",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    
                    ...sortedVlans.map((vlanId) {
                      final color = _vlanColors[vlanId] ?? Colors.grey;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: color,
                                border: Border.all(color: Colors.white),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Vlan $vlanId",
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          
          Positioned(
            top: _showVlan ? 240 : 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: frameVisible ? Colors.greenAccent : Colors.cyanAccent, 
                  width: 2
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    frameVisible ? Icons.gps_fixed : Icons.radar, 
                    color: frameVisible ? Colors.greenAccent : Colors.cyanAccent,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      status,
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 16, 
                        fontWeight: FontWeight.bold
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          Center(
            child: Container(
              width: frameVisible ? 100 : 80,
              height: frameVisible ? 100 : 80,
              decoration: BoxDecoration(
                border: Border.all(
                  color: frameVisible 
                    ? Colors.greenAccent 
                    : Colors.white.withOpacity(0.5), 
                  width: frameVisible ? 3 : 2,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  frameVisible ? Icons.check_circle : Icons.add, 
                  color: frameVisible ? Colors.greenAccent : Colors.white, 
                  size: frameVisible ? 26 : 20,
                ),
              ),
            ),
          ),
          
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    frameVisible ? Icons.check_circle_outline : Icons.search,
                    color: frameVisible ? Colors.greenAccent : Colors.cyanAccent,
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    frameVisible
                      ? "⚓ Switch 2D đã neo cố định!\n🔄 Quay camera tìm Switch mới"
                      : "🔍 Hướng camera về Switch để đặt Switch 2D",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _toggleVlan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showVlan ? Colors.orange.shade800 : Colors.grey.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    ),
                    child: Text(_showVlan ? "Hide VLAN" : "Show VLAN"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HÀM TẠO LABEL TEXTURE (từ switch_ar.dart) ---
  Future<Uint8List> _createLabelTexture({
    required SwitchData data, 
    required double arWidth,
    required double arHeight,
  }) async {
    final double aspectRatio = arHeight / arWidth;
    final int pixelWidth = 512;
    final int pixelHeight = (pixelWidth * aspectRatio).round();

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);

    final double labelRadius = 15.0;
    final Color labelBackgroundColor = const Color(0xFF4A80CC);
    final Color labelTextColor = Colors.white;

    final Rect labelRect = Rect.fromLTWH(0, 0, pixelWidth.toDouble(), pixelHeight.toDouble());
    final RRect labelRRect = RRect.fromRectAndRadius(labelRect, Radius.circular(labelRadius));
    canvas.drawRRect(labelRRect, ui.Paint()..color = labelBackgroundColor);

    final String line1Text = data.name; 
    final String line2Text = data.ip; 

    final ui.ParagraphBuilder pbLine1 = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: pixelHeight * 0.28, fontWeight: FontWeight.w600, height: 1.0));
    pbLine1.pushStyle(ui.TextStyle(color: labelTextColor)); 
    pbLine1.addText(line1Text);
    pbLine1.pop();
    final ui.Paragraph paragraphLine1 = pbLine1.build()..layout(ui.ParagraphConstraints(width: pixelWidth.toDouble()));

    final double text1Y = pixelHeight * 0.2;
    canvas.drawParagraph(paragraphLine1, ui.Offset(0, text1Y));

    final ui.ParagraphBuilder pbLine2 = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: pixelHeight * 0.22, fontWeight: FontWeight.w400, height: 1.0));
    pbLine2.pushStyle(ui.TextStyle(color: labelTextColor)); 
    pbLine2.addText(line2Text);
    pbLine2.pop();
    final ui.Paragraph paragraphLine2 = pbLine2.build()..layout(ui.ParagraphConstraints(width: pixelWidth.toDouble()));

    final double text2Y = pixelHeight * 0.55;
    canvas.drawParagraph(paragraphLine2, ui.Offset(0, text2Y));

    final picture = recorder.endRecording();
    final img = await picture.toImage(pixelWidth, pixelHeight);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // --- HÀM TẠO SWITCH PANEL TEXTURE ---
  Future<Uint8List> _createSwitchPanelTexture({
    required SwitchData data, 
    required double arWidth,
    required double arHeight,
    required bool showVlan,
  }) async {

    final int pixelWidth = 1024;
    final double aspectRatio = arHeight / arWidth;
    final int pixelHeight = (pixelWidth * aspectRatio).round();

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);

    canvas.drawRect(Rect.fromLTWH(0, 0, pixelWidth.toDouble(), pixelHeight.toDouble()), Paint()..blendMode = BlendMode.clear);

    final Color outerBorderColor = const Color(0xFF000080);
    final double outerBorderWidth = 3.0;
    final Color innerFillColor = Colors.white.withOpacity(0.0);
    
    final Color portColorBlue = const Color(0xFF4A80CC); 
    final Color portColorRed = const Color(0xFFD32F2F); 

    final Color portBorderColor = const Color(0xFFADD8E6);
    final Color lightStripeColor = const Color(0xFFFFFFFF).withOpacity(0.7);
    final Color textColor = Colors.white.withOpacity(0.9);
    final Color iconColor = Colors.white.withOpacity(0.8);
    final double mainBorderRadius = 15.0;

    final Rect frameRect = Rect.fromLTWH(0, 0, pixelWidth.toDouble(), pixelHeight.toDouble());
    final RRect frameRRect = RRect.fromRectAndRadius(frameRect, Radius.circular(mainBorderRadius));

    final Paint outerBorderPaint = ui.Paint()..color = outerBorderColor..style = ui.PaintingStyle.stroke..strokeWidth = outerBorderWidth;
    canvas.drawRRect(frameRRect, outerBorderPaint);

    final Rect innerFillRect = Rect.fromLTWH(frameRect.left + outerBorderWidth / 2, frameRect.top + outerBorderWidth / 2, frameRect.width - outerBorderWidth, frameRect.height - outerBorderWidth);
    final RRect innerFillRRect = RRect.fromRectAndRadius(innerFillRect, Radius.circular(mainBorderRadius - outerBorderWidth / 2));

    final innerFillPaint = ui.Paint()..color = innerFillColor;
    canvas.drawRRect(innerFillRRect, innerFillPaint);

    final int numRows = 2;
    final int numCols = 12;

    final double leftPadding = pixelWidth * 0.3;
    final double rightPadding = pixelWidth * 0.05;
    final double vPadding = pixelHeight * 0.15;
    final double portsDrawableWidth = pixelWidth - leftPadding - rightPadding;

    final double cellWidth = portsDrawableWidth / numCols;
    final double cellHeight = (pixelHeight - (vPadding * 2)) / numRows;

    final double portHeight = cellHeight * 0.7;
    final double portWidth = cellWidth * 0.8;

    final double hGap = cellWidth - portWidth;

    int portNumber = 0;

    for (int c = 0; c < numCols; c++) {
      for (int r = 0; r < numRows; r++) {
        portNumber = 1 + (c * numRows) + r;

        final double x = leftPadding + (c * cellWidth) + (hGap / 2);
        final double y = vPadding + (r * cellHeight) + ((cellHeight - portHeight) / 2);

        final double mainRectHeight = portHeight * 0.8;
        final double latchHeight = portHeight * 0.2;
        final double latchWidth = portWidth * 0.5;
        final double latchStartX = x + (portWidth - latchWidth) / 2;
        final double latchEndX = latchStartX + latchWidth;

        final Path portPath = Path();
        portPath.moveTo(x, y + latchHeight);
        portPath.lineTo(latchStartX, y + latchHeight);
        portPath.lineTo(latchStartX, y);
        portPath.lineTo(latchEndX, y);
        portPath.lineTo(latchEndX, y + latchHeight);
        portPath.lineTo(x + portWidth, y + latchHeight);
        portPath.lineTo(x + portWidth, y + portHeight);
        portPath.lineTo(x, y + portHeight);
        portPath.lineTo(x, y + latchHeight);
        portPath.close();

        final portInfo = data.ports.firstWhere(
          (p) => p.portId == portNumber, 
          orElse: () => PortData(portId: portNumber, linkedDevice: "", status: 0, vlan: 1)
        );

        Color currentFillColor;

        if (showVlan) {
           currentFillColor = _vlanColors[portInfo.vlan] ?? Colors.grey; 
        } else {
           if (portInfo.status == 1) {
             currentFillColor = portColorRed; 
           } else {
             currentFillColor = portColorBlue;
           }
        }

        canvas.drawPath(portPath, ui.Paint()..color = currentFillColor);

        canvas.drawPath(portPath, ui.Paint()..color = portBorderColor..style = ui.PaintingStyle.stroke..strokeWidth = 2.5);

        final double stripeY = y + latchHeight + mainRectHeight * 0.7;
        final double stripeHeight = portHeight * 0.08;
        final double stripeStartX = x + (portWidth - (portWidth * 0.7)) / 2;

        final linePaint = ui.Paint()..color = lightStripeColor..strokeWidth = 2.0;
        final int numLines = 8;
        final double lineSpacing = ((portWidth * 0.7) / (numLines + 1));
        
        for (int i = 0; i < numLines; i++) {
          final double lineX = stripeStartX + lineSpacing * (i + 1);
          canvas.drawLine(Offset(lineX, stripeY), Offset(lineX, stripeY + stripeHeight), linePaint);
        }

        final ui.ParagraphBuilder pb = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.left, fontSize: portHeight * 0.5, fontWeight: FontWeight.w300, height: 1.0));
        pb.pushStyle(ui.TextStyle(color: textColor));
        pb.addText('$portNumber');
        pb.pop();
        final ui.Paragraph paragraph = pb.build()..layout(ui.ParagraphConstraints(width: portWidth * 0.5));
        
        final double textX = x + (portWidth * 0.15);
        final double textY_for_PortNumber = y + latchHeight + (mainRectHeight * 0.3) - (paragraph.height / 2);
        canvas.drawParagraph(paragraph, ui.Offset(textX, textY_for_PortNumber));

        final double boltSize = portHeight * 0.30;
        final double boltX = x + portWidth * 0.60;
        final double boltY = y + latchHeight + mainRectHeight * 0.30;

        final Path boltPath = Path();
        boltPath.moveTo(boltX + boltSize, boltY);
        boltPath.lineTo(boltX + 0.3 * boltSize, boltY + 0.5 * boltSize);
        boltPath.lineTo(boltX, boltY + boltSize);
        boltPath.lineTo(boltX + 0.7 * boltSize, boltY + 0.5 * boltSize);
        boltPath.close();

        canvas.drawPath(boltPath, ui.Paint()..color = iconColor);

        final ui.ParagraphBuilder starPb = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: boltSize * 0.6, fontWeight: FontWeight.bold, height: 1.0));
        starPb.pushStyle(ui.TextStyle(color: iconColor));
        starPb.addText('**');
        starPb.pop();
        final ui.Paragraph starParagraph = starPb.build()..layout(ui.ParagraphConstraints(width: boltSize * 2));
        canvas.drawParagraph(starParagraph, ui.Offset(boltX + boltSize * 1.1, boltY + boltSize * 0.3));
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(pixelWidth, pixelHeight);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // --- HÀM TẠO LINES TEXTURE ---
  Future<Uint8List> _createLinesTexture({
    required SwitchData data, 
    required double arWidth,
    required double arHeight, 
    required double arBaseHeight, 
    required bool showVlan, 
  }) async {

    final int pixelWidth = 1024;
    final double totalAspectRatio = arHeight / arWidth;
    final int pixelHeight = (pixelWidth * totalAspectRatio).round();
    final double panelHeightRatio = arBaseHeight / arHeight;
    final int switchGraphicPixelHeight = (pixelHeight * panelHeightRatio).round();
    final double panelTopY = (pixelHeight / 2) - (switchGraphicPixelHeight / 2);

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    canvas.drawRect(Rect.fromLTWH(0, 0, pixelWidth.toDouble(), pixelHeight.toDouble()), Paint()..blendMode = BlendMode.clear);

    final int numRows = 2;
    final int numCols = 12;
    final double leftPadding = pixelWidth * 0.3;
    final double rightPadding = pixelWidth * 0.05;
    final double vPadding = switchGraphicPixelHeight * 0.15;
    final double portsDrawableWidth = pixelWidth - leftPadding - rightPadding;
    final double cellWidth = portsDrawableWidth / numCols;
    final double cellHeight = (switchGraphicPixelHeight - (vPadding * 2)) / numRows;
    final double portHeight = cellHeight * 0.7; 
    final double portWidth = cellWidth * 0.8;
    final double hGap = cellWidth - portWidth;

    final double labelTextFontSize = 14.0;
    final double labelMaxWidth = cellWidth * 1.6;
    final double labelHeight = labelTextFontSize * 1.2;
    final double rotationAngle = math.pi / 4; 
    final double lineToLabelSpacing = 3.0; 
    final double lineLengthReduction = 45.0; 
    final ui.FontWeight labelFontWeight = ui.FontWeight.w800; 
    final ui.Color labelColor = Colors.white; 

    for (int c = 0; c < numCols; c++) {
      for (int r = 0; r < numRows; r++) {
        int portNumber = 1 + (c * numRows) + r;

        final double x = leftPadding + (c * cellWidth) + (hGap / 2);
        final double y = panelTopY + vPadding + (r * cellHeight) + ((cellHeight - portHeight) / 2);

        final portData = data.ports.firstWhere(
          (p) => p.portId == portNumber,
          orElse: () => PortData(portId: portNumber, linkedDevice: "", status: 0, vlan: 1),
        );

        final double lineStartX = x + (portWidth / 2);

        double lineStartY, lineEndY;

        if (r == 0) {
          lineStartY = y;
          double pivotY = lineStartY - lineLengthReduction; 
          lineEndY = pivotY + lineToLabelSpacing + labelHeight/2; 
        } else {
          lineStartY = y + portHeight;
          double pivotY = lineStartY + lineLengthReduction; 
          lineEndY = pivotY - lineToLabelSpacing - labelHeight/2;
        }

        final portLinePaint = ui.Paint()..color = Colors.white.withOpacity(0.9)..style = ui.PaintingStyle.stroke..strokeWidth = 1.8;
        canvas.drawLine(Offset(lineStartX, lineStartY), Offset(lineStartX, lineEndY), portLinePaint);

        final ui.ParagraphBuilder pbLabel = ui.ParagraphBuilder(
          ui.ParagraphStyle(textAlign: TextAlign.start, fontSize: labelTextFontSize, fontWeight: labelFontWeight, height: 1.0));
        pbLabel.pushStyle(ui.TextStyle(color: labelColor));
        
        String labelText = "";
        if (showVlan) {
           labelText = "Vlan: ${portData.vlan}";
        } else {
           labelText = portData.linkedDevice.isNotEmpty 
            ? portData.linkedDevice 
            : "Port $portNumber"; 
        }

        pbLabel.addText(labelText);
        pbLabel.pop();

        final ui.Paragraph pLabel = pbLabel.build()..layout(ui.ParagraphConstraints(width: labelMaxWidth));
        
        canvas.save(); 

        double labelDrawX = 0;
        double labelDrawY = 0;

        canvas.translate(lineStartX, lineEndY); 

        if (r == 0) {
          canvas.rotate(-rotationAngle); 
          labelDrawY = -pLabel.height - lineToLabelSpacing; 
        } else {
          canvas.rotate(rotationAngle); 
          labelDrawY = lineToLabelSpacing; 
        }
        
        canvas.drawParagraph(pLabel, ui.Offset(labelDrawX, labelDrawY));

        canvas.restore(); 
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(pixelWidth, pixelHeight);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List(); 
  }
}

class BoundingBoxPainter extends CustomPainter {
  final List<double> box;
  final double confidence;
  
  BoundingBoxPainter(this.box, this.confidence);
  
  @override
  void paint(Canvas canvas, Size size) {
    final boxPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final rect = Rect.fromLTRB(box[0], box[1], box[2], box[3]);
    canvas.drawRect(rect, boxPaint);
    
    final cornerPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.fill;
    
    final cornerSize = 8.0;
    canvas.drawCircle(Offset(box[0], box[1]), cornerSize, cornerPaint);
    canvas.drawCircle(Offset(box[2], box[1]), cornerSize, cornerPaint);
    canvas.drawCircle(Offset(box[2], box[3]), cornerSize, cornerPaint);
    canvas.drawCircle(Offset(box[0], box[3]), cornerSize, cornerPaint);
    
    final centerPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    
    final centerX = (box[0] + box[2]) / 2;
    final centerY = (box[1] + box[3]) / 2;
    canvas.drawCircle(Offset(centerX, centerY), 8, centerPaint);
    
    final centerBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(Offset(centerX, centerY), 8, centerBorderPaint);
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Switch ${(confidence * 100).toStringAsFixed(0)}%',
        style: const TextStyle(
          color: Colors.greenAccent,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black87,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(canvas, Offset(box[0], box[1] - 25));
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}