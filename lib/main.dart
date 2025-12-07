import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screenshot/screenshot.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'dart:math' show tan, pi, atan; 

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
  
  String? currentDotName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    vision = FlutterVision();
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

// hàm detect và xử lý hình ảnh
  void _captureAndDetect() async { 
    setState(() { isProcessing = true; });

    try {
      // Chụp màn hình
      final Uint8List? imageBytes = await screenshotController.capture(pixelRatio: 1.0); 
      
      if (imageBytes != null) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;

        // Chạy YOLO AI để detect
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
            
            // Lưu bounding box (khung hình chữ nhật xanh 2D)
            setState(() {
              currentBoundingBox = [
                topResult['box'][0].toDouble(), // x_min
                topResult['box'][1].toDouble(), // y_min
                topResult['box'][2].toDouble(), // x_max
                topResult['box'][3].toDouble(), // y_max
              ];
              currentConfidence = topResult['box'][4]?.toDouble() ?? 0.0;
              status = "✅ Đã bắt được Switch!";
            });
            
            // ★ GỌI HÀM TÍNH TỌA ĐỘ 3D ★
            _place3DPoint(topResult['box'], screenWidth, screenHeight); 
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
  
  // hàm tính vị trí tọa độ  3D từ khung 2D khi đã detect được Switch
  void _place3DPoint(List<dynamic> box, double screenWidth, double screenHeight) {
    if (arCoreController == null) return;

 // tính khoảng cách Z
    final double boxHeight = (box[3] - box[1]).toDouble();
    const double REAL_SWITCH_HEIGHT = 0.044; // Chiều cao thực Switch = 44mm
    const double FOV_VERTICAL = 60.0;
    const double FOV_RAD = FOV_VERTICAL * pi / 180.0;
    
    // Công thức: distance = (chiều cao thực × chiều cao màn hình) / (2 × chiều cao box × tan(FOV/2))
    double distance = (REAL_SWITCH_HEIGHT * screenHeight) / (2 * boxHeight * tan(FOV_RAD / 2));
    distance = distance.clamp(0.3, 5.0);
    
  // tính tọa độ X,Y 
    final double centerX = (box[0] + box[2]) / 2.0; // Tâm X của box
    final double centerY = (box[1] + box[3]) / 2.0; // Tâm Y của box
    
    // Chuyển pixel → NDC (Normalized Device Coordinates: -1 đến +1)
    final double ndcX = (centerX / screenWidth) * 2.0 - 1.0;
    final double ndcY = -((centerY / screenHeight) * 2.0 - 1.0);
    
    // Tính FOV ngang
    final double aspectRatio = screenWidth / screenHeight;
    final double fovHorizontal = 2 * atan(tan(FOV_RAD / 2) * aspectRatio);
    
    // Tính kích thước frustum (hình chóp cụt mà camera nhìn thấy)
    final double frustumHeight = 2.0 * distance * tan(FOV_RAD / 2);
    final double frustumWidth = 2.0 * distance * tan(fovHorizontal / 2);
    
    // Chuyển NDC → World Space (tọa độ thực trong không gian 3D)
    double worldX = ndcX * (frustumWidth / 2.0);
    double worldY = ndcY * (frustumHeight / 2.0);
    double worldZ = -distance; // Âm vì camera nhìn về -Z
    
  // hạ thấp Y xuống 25 cm
    worldY -= 0.25;
    
    vector.Vector3 newPosition = vector.Vector3(worldX, worldY, worldZ);
    
 // xóa chấm đỏ cũ tạo chấm đỏ mới khi detect được switch khác
    if (currentDotName != null) {
      arCoreController!.removeNode(nodeName: currentDotName!);
      print("🗑️  Đã xóa chấm đỏ cũ: $currentDotName");
    }
    
    String nodeName = "SwitchDot_${DateTime.now().millisecondsSinceEpoch}";
    currentDotName = nodeName;
    lastStablePosition = newPosition;
    
    final materialDot = ArCoreMaterial(
      color: Colors.red,
      metallic: 1.0,
    );
    
    final sphereShape = ArCoreSphere(
      materials: [materialDot],
      radius: 0.025,
    );
    
    // Tạo node 3D tại tọa độ (worldX, worldY, worldZ)
    final nodeDot = ArCoreNode(
      name: nodeName, 
      shape: sphereShape,
      position: newPosition, // ★ ĐÂY LÀ TỌA ĐỘ CUỐI CÙNG ★
    );

    arCoreController!.addArCoreNode(nodeDot);
    frameVisible = true;
    
    setState(() { 
      status = "⚓ Đã neo - ${distance.toStringAsFixed(2)}m";
    });
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    print("🎯 TẠO CHẤM ĐỎ MỚI: $nodeName");
    print("   X = ${newPosition.x.toStringAsFixed(4)} m");
    print("   Y = ${newPosition.y.toStringAsFixed(4)} m (đã hạ 25cm)");
    print("   Z = ${newPosition.z.toStringAsFixed(4)} m");
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  }

  void _remove3DPoint() {
    if (frameVisible && arCoreController != null) {
      if (currentDotName != null) {
        arCoreController!.removeNode(nodeName: currentDotName!);
      }
      frameVisible = false;
      lastStablePosition = null;
      stabilityCounter = 0;
      currentBoundingBox = null;
      currentDotName = null;
      setState(() { status = "Đang tìm kiếm..."; });
    }
  }

  void _onArCoreViewCreated(ArCoreController controller) {
    arCoreController = controller;
    _clearAllNodes(); 
  }
  
  void _clearAllNodes() {
    if (arCoreController != null) {
      if (currentDotName != null) {
        arCoreController!.removeNode(nodeName: currentDotName!);
      }
      frameVisible = false;
      lastStablePosition = null;
      stabilityCounter = 0;
      currentBoundingBox = null;
      currentDotName = null;
    }
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
          
          Positioned(
            top: 50, left: 20, right: 20,
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
                  Text(
                    status,
                    style: const TextStyle(
                      color: Colors.white, 
                      fontSize: 16, 
                      fontWeight: FontWeight.bold
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
                      ? "⚓ Chấm đỏ đã neo cố định!\n🔄 Quay camera tìm Switch mới"
                      : "🔍 Hướng camera về Switch để đặt chấm đỏ",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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