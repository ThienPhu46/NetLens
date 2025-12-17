import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:screenshot/screenshot.dart';
import 'package:vector_math/vector_math_64.dart' as vector64;
import 'dart:math' as math;

// Import các file đã tách
import '../models/switch_model.dart';
import '../services/api_service.dart';
import '../utils/texture_generator.dart';
import 'qr_scanner_screen.dart';

class ArSwitchScreen extends StatefulWidget {
  final String targetIp;
  const ArSwitchScreen({super.key, required this.targetIp});

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
  bool isLoadingData = true;
  String status = "Đang kết nối API...";

  Timer? scanTimer;
  Timer? _apiTimer;

  bool frameVisible = false;
  vector64.Vector3? lastStablePosition;
  String? currentBaseName;
  bool _isUpdatingAr = false;

  late SwitchData switchData;
  SwitchData? _previousSwitchData;
  late String _currentTargetIp;
  bool _showVlan = false;

  // Cache Texture
  Uint8List? _panelTextureCache;
  Uint8List? _linesTextureCache;
  Uint8List? _labelTextureCache;

  // Kích thước
  final double _switchWidth = 0.4;
  final double _switchHeight = 0.04445;
  final double _linesHeight = 0.04445 * 3.0;
  final double _labelWidth = 0.15;
  final double _labelHeight = 0.045;

  // Bảng màu
  final Map<int, Color> _fixedVlanColors = {
    1: Colors.blue[700]!, 10: Colors.teal[700]!, 20: Colors.orange[800]!,
    30: Colors.purple[700]!, 40: Colors.pink[700]!, 50: Colors.green[800]!,
    99: Colors.red[900]!, 100: Colors.brown[700]!,
  };

  Color _getVlanColor(int vlanId) {
    return _fixedVlanColors[vlanId] ?? Colors.primaries[vlanId % Colors.primaries.length];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    vision = FlutterVision();
    _currentTargetIp = widget.targetIp;
    switchData = SwitchData(name: "Loading...", ip: _currentTargetIp, uptime: "", ports: []);
    _fetchData(isBackground: false);
    _startApiTimer();
  }

  void _startApiTimer() {
    _apiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) _fetchData(isBackground: true);
    });
  }

  Future<void> _fetchData({bool isBackground = false}) async {
    try {
      if (!isBackground) print("📡 API Calling: $_currentTargetIp");
      
      // GỌI SERVICE
      SwitchData newData = await ApiService.fetchSwitchData(_currentTargetIp);
      
      bool dataChanged = true;
      if (_previousSwitchData != null) {
         // Logic so sánh đơn giản
         if (_previousSwitchData!.ports.length == newData.ports.length && _previousSwitchData!.uptime == newData.uptime) {
             // dataChanged = false; // Có thể bật lại check này
         }
      }

      if (mounted) {
        setState(() {
          _previousSwitchData = switchData;
          switchData = newData;
          if (!isBackground) {
            isLoadingData = false;
            status = "Dữ liệu sẵn sàng. Khởi động...";
          }
        });

        if (frameVisible && lastStablePosition != null && dataChanged) {
           _updateArContentSmoothly();
        }
        if (!isBackground) _checkPermissions();
      }
    } catch (e) {
      if (!isBackground) {
        print("❌ Lỗi API: $e");
        setState(() {
          switchData = ApiService.getFallbackData(_currentTargetIp);
          isLoadingData = false;
          status = "⚠️ Dữ liệu Offline.";
        });
        _checkPermissions();
      }
    }
  }

  Future<void> _checkPermissions() async {
    final permissionStatus = await Permission.camera.request();
    if (permissionStatus.isGranted) {
      setState(() { hasPermission = true; status = "Khởi động AI..."; });
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
      setState(() { isModelLoaded = true; status = "✅ Sẵn sàng! Đang quét..."; });
      _startAutoScan();
    } catch (e) {
      setState(() { status = "❌ Lỗi Model: $e"; });
    }
  }

  void _startAutoScan() {
    scanTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (isModelLoaded && !isLoadingData && !isProcessing && arCoreController != null && mounted && !frameVisible) {
        _captureAndDetect();
      }
    });
  }

  void _captureAndDetect() async {
    setState(() { isProcessing = true; });
    try {
      final Uint8List? imageBytes = await screenshotController.capture(pixelRatio: 0.5);
      if (imageBytes != null) {
        final screenW = MediaQuery.of(context).size.width;
        final screenH = MediaQuery.of(context).size.height;
        final results = await vision.yoloOnImage(
          bytesList: imageBytes, imageHeight: screenH.toInt(), imageWidth: screenW.toInt(),
          confThreshold: 0.5, classThreshold: 0.5,
        );

        if (results.isNotEmpty) {
          final topResult = results.first;
          final double confidence = topResult['box'][4]?.toDouble() ?? 0.0;
          final String tag = topResult['tag'].toString();
          if (tag.contains('Switch') && confidence > 0.6) {
            scanTimer?.cancel();
            setState(() { status = "⚓ Đã neo Switch!"; frameVisible = true; });
            _placeSwitch2D(topResult['box'], screenW, screenH);
          }
        }
      }
    } catch (e) { print("Scan Error: $e"); } 
    finally { if (mounted) setState(() { isProcessing = false; }); }
  }

  void _placeSwitch2D(List<dynamic> box, double screenW, double screenH) async {
    if (arCoreController == null) return;
    final double boxH = (box[3] - box[1]).toDouble();
    const double FOV_RAD = 60.0 * math.pi / 180.0;
    double dist = (0.044 * screenH) / (2 * boxH * math.tan(FOV_RAD / 2));
    dist = dist.clamp(0.2, 3.0);
    
    final double cX = (box[0] + box[2]) / 2.0;
    final double cY = (box[1] + box[3]) / 2.0;
    final double ndcX = (cX / screenW) * 2.0 - 1.0;
    final double ndcY = -((cY / screenH) * 2.0 - 1.0);
    final double aspectRatio = screenW / screenH;
    final double fovH = 2 * math.atan(math.tan(FOV_RAD / 2) * aspectRatio);
    final double frustumW = 2.0 * dist * math.tan(fovH / 2);
    
    double worldX = ndcX * (frustumW / 2.0);
    double worldY = ndcY * (2.0 * dist * math.tan(FOV_RAD / 2) / 2.0);
    double worldZ = -dist;
    worldY -= 0.15;

    vector64.Vector3 newPos = vector64.Vector3(worldX, worldY, worldZ);
    lastStablePosition = newPos;

    String initName = "SW_${DateTime.now().millisecondsSinceEpoch}";
    currentBaseName = initName;
    await _generateSwitchTextures();
    _spawnArNodesAt(newPos, baseName: initName);
    
    setState(() { frameVisible = true; status = "⚓ Đã hiển thị: ${switchData.name}"; });
  }

  Future<void> _updateArContentSmoothly() async {
    if (_isUpdatingAr) return;
    _isUpdatingAr = true;
    try {
      String? oldBaseName = currentBaseName;
      await _generateSwitchTextures();
      String newBaseName = "SW_${DateTime.now().millisecondsSinceEpoch}";
      _spawnArNodesAt(lastStablePosition!, baseName: newBaseName);
      currentBaseName = newBaseName;
      await Future.delayed(const Duration(milliseconds: 50));
      if (oldBaseName != null) _removeSpecificNodes(oldBaseName);
    } catch (e) { print("AR Update Error: $e"); } finally { _isUpdatingAr = false; }
  }

  Future<void> _generateSwitchTextures() async {
    // GỌI UTILS
    _panelTextureCache = await TextureGenerator.createSwitchPanelTexture(
        data: switchData, arWidth: _switchWidth, arHeight: _switchHeight, showVlan: _showVlan, 
        getVlanColor: _getVlanColor); // Truyền hàm màu vào
    _linesTextureCache = await TextureGenerator.createLinesTexture(
        data: switchData, arWidth: _switchWidth, arHeight: _linesHeight, arBaseHeight: _switchHeight, showVlan: _showVlan);
    _labelTextureCache = await TextureGenerator.createLabelTexture(
        data: switchData, arWidth: _labelWidth, arHeight: _labelHeight);
  }

  void _spawnArNodesAt(vector64.Vector3 pos, {required String baseName}) {
    if (_panelTextureCache == null) return;
    final switchNode = ArCoreNode(
        name: "${baseName}_panel", 
        shape: ArCoreCube(materials: [ArCoreMaterial(textureBytes: _panelTextureCache, color: Colors.transparent)], size: vector64.Vector3(_switchWidth, _switchHeight, 0.0001)), 
        position: pos);
    final linesNode = ArCoreNode(
        name: "${baseName}_lines", 
        shape: ArCoreCube(materials: [ArCoreMaterial(textureBytes: _linesTextureCache, color: Colors.transparent)], size: vector64.Vector3(_switchWidth, _linesHeight, 0.0001)), 
        position: vector64.Vector3(pos.x, pos.y, pos.z - 0.0005));
    final labelNode = ArCoreNode(
        name: "${baseName}_label", 
        shape: ArCoreCube(materials: [ArCoreMaterial(textureBytes: _labelTextureCache, color: Colors.transparent)], size: vector64.Vector3(_labelWidth, _labelHeight, 0.0001)), 
        position: vector64.Vector3(pos.x - _switchWidth/2 - _labelWidth/2 - 0.01, pos.y, pos.z));

    arCoreController!.addArCoreNode(switchNode);
    arCoreController!.addArCoreNode(linesNode);
    arCoreController!.addArCoreNode(labelNode);
  }

  void _removeSpecificNodes(String baseName) {
    try { arCoreController?.removeNode(nodeName: "${baseName}_panel"); } catch(e){}
    try { arCoreController?.removeNode(nodeName: "${baseName}_lines"); } catch(e){}
    try { arCoreController?.removeNode(nodeName: "${baseName}_label"); } catch(e){}
  }

  void _toggleVlan() async {
    if (!frameVisible || lastStablePosition == null) return;
    setState(() { _showVlan = !_showVlan; });
    await _updateArContentSmoothly();
  }

  void _resetScanning() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const QrScannerScreen()));
  }
  
  void _onArCoreViewCreated(ArCoreController controller) {
    arCoreController = controller;
  }

  Set<int> _getActiveVlans() {
    Set<int> vlans = {};
    for (var port in switchData.ports) vlans.add(port.vlan);
    return vlans;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    scanTimer?.cancel();
    _apiTimer?.cancel();
    arCoreController?.dispose();
    vision.closeYoloModel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!hasPermission) return Scaffold(backgroundColor: Colors.black, body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(), const SizedBox(height: 20), Text(status, style: const TextStyle(color: Colors.white))])));
    
    final List<int> sortedVlans = _getActiveVlans().toList()..sort();

    return Scaffold(
      backgroundColor: Colors.black, 
      body: Stack(
        children: [
          Screenshot(controller: screenshotController, child: ArCoreView(onArCoreViewCreated: _onArCoreViewCreated, enableTapRecognizer: true)),
          
          if (!frameVisible) Positioned(top: 50, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16), decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(20)), child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))))),
          
          if (frameVisible && _showVlan) Positioned(top: 100, left: 20, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white24)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [const Text("Chú thích VLAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(height: 8), ...sortedVlans.map((vlanId) { final color = _getVlanColor(vlanId); return Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [Container(width: 16, height: 16, decoration: BoxDecoration(color: color, border: Border.all(color: Colors.white), borderRadius: BorderRadius.circular(4))), const SizedBox(width: 8), Text("Vlan $vlanId", style: const TextStyle(color: Colors.white, fontSize: 12))])); }).toList()]))),
            
           if (frameVisible) Positioned(bottom: 40, left: 0, right: 0, child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [ElevatedButton(onPressed: _toggleVlan, style: ElevatedButton.styleFrom(backgroundColor: _showVlan ? Colors.orange.shade800 : Colors.blue.withOpacity(0.8), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)), child: Text(_showVlan ? "Hide VLAN" : "Show VLAN")), const SizedBox(width: 10), FloatingActionButton.small(onPressed: _resetScanning, backgroundColor: Colors.redAccent, child: const Icon(Icons.qr_code_scanner, color: Colors.white))]))),
        ],
      ),
    );
  }
}