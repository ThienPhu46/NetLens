import 'dart:async';
import 'dart:typed_data';
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
      home: ArSwitchScreen(),
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    vision = FlutterVision();
    _checkPermissions();
  }

  // 1. XIN QUYỀN VÀ NẠP MODEL
  Future<void> _checkPermissions() async {
    final cameraStatus = await Permission.camera.request();
    final storageStatus = await Permission.storage.request();

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

  // 2. VÒNG LẶP QUÉT TỰ ĐỘNG
  void _startAutoScan() {
    scanTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (isModelLoaded && !isProcessing && arCoreController != null && mounted) {
        _captureAndDetect();
      }
    });
    
    // Timer dọn dẹp: Nếu 3 giây không thấy Switch thì ẩn chấm đỏ
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (frameVisible && DateTime.now().difference(lastDetectionTime).inSeconds > 3) {
            if (mounted) _remove3DPoint();
        }
    });
  }

  // 3. CHỤP & NHẬN DIỆN
  Future<void> _captureAndDetect() async {
    setState(() { isProcessing = true; });

    try {
      // Tăng tần suất chụp lên 0.5s/lần
      final Uint8List? imageBytes = await screenshotController.capture(pixelRatio: 0.5); 
      
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
            setState(() { status = "✅ Đã bắt được Switch!"; });
            
            // TỰ ĐỘNG GỌI PLACEMENT DỰA TRÊN KẾT QUẢ ĐETECT (Tâm điểm Box 2D)
            _place3DPoint(topResult['box'], screenWidth, screenHeight); 
          }
        }
      }
    } catch (e) {
      print("Lỗi quét: $e");
    } finally {
      if (mounted) setState(() { isProcessing = false; });
    }
  }

  // 4. HIỂN THỊ CHẤM ĐỎ 3D (TÍNH TOÁN X, Y & Z)
  void _place3DPoint(List<dynamic> box, double screenWidth, double screenHeight) {
    if (arCoreController == null) return;
    
    // Xóa node cũ
    arCoreController!.removeNode(nodeName: "SwitchDot");

    // A. Ước lượng khoảng cách (Z)
    final boxHeight = box[3] - box[1];
    double estimatedZ = -(screenHeight / boxHeight) * 0.12;
    estimatedZ = estimatedZ.clamp(-2.0, -0.2); 

    // B. Tính vị trí X, Y trong không gian 3D (Mapping 2D -> 3D)
    // Tọa độ 2D của tâm Switch:
    final double centerX = (box[0] + box[2]) / 2;
    final double centerY = (box[1] + box[3]) / 2;
    
    // CHUYỂN ĐỔI: Sử dụng tọa độ 2D của Switch để tính offset 3D
    // (Đây là heuristic tốt nhất để mô phỏng sự dịch chuyển X, Y trong AR)
    final double offsetX = (centerX - screenWidth / 2) * 0.001; 
    final double offsetY = -(centerY - screenHeight / 2) * 0.001; 
    // Hệ số 0.001 chuyển đổi pixel thành meter (ước lượng)
    
    // --- TẠO CHẤM ĐỎ (POINT) ---
    final materialDot = ArCoreMaterial(color: Colors.red, metallic: 1.0);
    final sphereShape = ArCoreSphere(materials: [materialDot], radius: 0.015);
    
    final nodeDot = ArCoreNode(
       name: "SwitchDot", 
       shape: sphereShape,
       
       // VỊ TRÍ CUỐI CÙNG (X, Y DỊCH CHUYỂN THEO BOX, Z LÀ KHOẢNG CÁCH ƯỚC LƯỢNG)
       position: vector.Vector3(offsetX, offsetY, estimatedZ), 
       rotation: vector.Vector4(0, 0, 0, 1), 
    );

    arCoreController!.addArCoreNode(nodeDot);
    frameVisible = true;
    print("✅ Đã đặt chấm đỏ 3D tại Z: ${estimatedZ.toStringAsFixed(2)}m");
  }

  // 5. XÓA CHẤM ĐỎ
  void _remove3DPoint() {
    if (frameVisible && arCoreController != null) {
      arCoreController!.removeNode(nodeName: "SwitchDot");
      frameVisible = false;
      setState(() { status = "Đang tìm kiếm..."; });
    }
  }

  // 6. ARCORE VIEW CREATED & CLEANUP
  void _onArCoreViewCreated(ArCoreController controller) {
    arCoreController = controller;
    _clearAllNodes(); 
  }
  
  void _clearAllNodes() {
    if (arCoreController != null) {
      arCoreController!.removeNode(nodeName: "SwitchDot");
      frameVisible = false;
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
          // LỚP 1: Camera AR
          Screenshot(
            controller: screenshotController,
            child: ArCoreView(
              onArCoreViewCreated: _onArCoreViewCreated,
              enableTapRecognizer: true,
            ),
          ),
          
          // LỚP 2: Thanh trạng thái
          Positioned(
            top: 50, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.cyanAccent, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(frameVisible ? Icons.check_circle : Icons.radar, 
                       color: frameVisible ? Colors.greenAccent : Colors.cyanAccent),
                  const SizedBox(width: 10),
                  Text(
                    status,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          
          // LỚP 3: Tâm ngắm (Crosshair)
          Center(
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}