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
import 'package:vector_math/vector_math_64.dart' as vector64;
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

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
      home: const QrScannerScreen(),
    );
  }
}

// --- CLASS DỮ LIỆU ---
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
  final String uptime;
  final List<PortData> ports;

  SwitchData({
    required this.name,
    required this.ip,
    required this.uptime,
    required this.ports,
  });

  factory SwitchData.fromJson(Map<String, dynamic> json) {
    var list = json['port'] is List ? json['port'] as List : [];
    List<PortData> portList = list.map((i) => PortData.fromJson(i)).toList();
    return SwitchData(
      name: json['name'] ?? "",
      ip: json['ip'] ?? "",
      uptime: json['uptime'] ?? "",
      ports: portList,
    );
  }
}

// --- MÀN HÌNH QUÉT QR CODE ---
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    returnImage: false,
  );

  bool isProcessing = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _handleBarcode(Barcode barcode) {
    if (isProcessing) return;
    String? ipAddress = barcode.rawValue;

    if (ipAddress != null && ipAddress.isNotEmpty) {
      setState(() {
        isProcessing = true;
      });
      controller.stop();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ArSwitchScreen(targetIp: ipAddress),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quét mã QR Switch')),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                MobileScanner(
                  controller: controller,
                  onDetect: (capture) {
                    if (capture.barcodes.isNotEmpty) {
                      _handleBarcode(capture.barcodes.first);
                    }
                  },
                ),
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.red.withOpacity(0.5), width: 3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'Hướng camera vào mã QR chứa IP của Switch',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          )
        ],
      ),
    );
  }
}

// --- MÀN HÌNH AR REALTIME 1 GIÂY ---
class ArSwitchScreen extends StatefulWidget {
  final String targetIp;
  const ArSwitchScreen({super.key, required this.targetIp});

  @override
  State<ArSwitchScreen> createState() => _ArSwitchScreenState();
}

class _ArSwitchScreenState extends State<ArSwitchScreen>
    with WidgetsBindingObserver {
  ArCoreController? arCoreController;
  late FlutterVision vision;
  final ScreenshotController screenshotController = ScreenshotController();

  bool hasPermission = false;
  bool isModelLoaded = false;
  bool isProcessing = false;

  Timer? scanTimer;
  Timer? _apiTimer;
  String status = "Đang kết nối API...";
  bool isLoadingData = true;

  bool frameVisible = false;
  vector64.Vector3? lastStablePosition;

  List<double>? currentBoundingBox;
  double? currentConfidence;

  String? currentBaseName;
  bool _isUpdatingAr = false;

  bool _showVlan = false;
  late SwitchData switchData;
  SwitchData? _previousSwitchData;

  // Bảng màu cố định cho các VLAN phổ biến
  final Map<int, Color> _fixedVlanColors = {
    1: Colors.blue[700]!,
    10: Colors.teal[700]!,
    20: Colors.orange[800]!,
    30: Colors.purple[700]!,
    40: Colors.pink[700]!,
    50: Colors.green[800]!,
    99: Colors.red[900]!,
    100: Colors.brown[700]!,
  };

  // Hàm lấy màu động cho VLAN
  Color _getVlanColor(int vlanId) {
    if (_fixedVlanColors.containsKey(vlanId)) {
      return _fixedVlanColors[vlanId]!;
    }
    return Colors.primaries[vlanId % Colors.primaries.length];
  }

  Uint8List? _panelTextureCache;
  Uint8List? _linesTextureCache;
  Uint8List? _labelTextureCache;

  final double _switchWidth = 0.4;
  final double _switchHeight = 0.04445;
  final double _linesHeight = 0.04445 * 3.0;
  final double _labelWidth = 0.15;
  final double _labelHeight = 0.045;

  late String _currentTargetIp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    vision = FlutterVision();
    _currentTargetIp = widget.targetIp;

    switchData = SwitchData(
        name: "Loading...", ip: _currentTargetIp, uptime: "", ports: []);

    _fetchSwitchDataFromApi();
    _startApiTimer();
  }

  void _startApiTimer() {
    _apiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _fetchSwitchDataFromApi(isBackground: true);
      }
    });
  }

  bool _isDataChanged(SwitchData oldData, SwitchData newData) {
    if (oldData.name != newData.name) return true;
    if (oldData.uptime != newData.uptime) return true;
    if (oldData.ports.length != newData.ports.length) return true;

    for (int i = 0; i < oldData.ports.length; i++) {
      if (oldData.ports[i].status != newData.ports[i].status ||
          oldData.ports[i].vlan != newData.ports[i].vlan) {
        return true;
      }
    }
    return false;
  }

  Future<void> _fetchSwitchDataFromApi({bool isBackground = false}) async {
    final String apiUrl =
        "http://172.0.0.192:9116/snmp?module=cisco&target=$_currentTargetIp";

    try {
      if (!isBackground) print("📡 Đang gọi API: $apiUrl");

      final response =
          await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        SwitchData newData =
            _parsePrometheusText(response.body, _currentTargetIp);

        bool dataChanged = true;
        if (_previousSwitchData != null) {
          dataChanged = _isDataChanged(_previousSwitchData!, newData);
        }

        if (mounted) {
          setState(() {
            _previousSwitchData = switchData;
            switchData = newData;
            if (!isBackground) {
              isLoadingData = false;
              status = "Dữ liệu sẵn sàng. Đang khởi động...";
            }
          });

          if (frameVisible && lastStablePosition != null && dataChanged) {
            _updateArContentSmoothly();
          }
          if (!isBackground) _checkPermissions();
        }
      }
    } catch (e) {
      if (!isBackground) {
        print("❌ Lỗi API ($e).");
        _useFallbackData();
      }
    }
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
      if (oldBaseName != null) {
        _removeSpecificNodes(oldBaseName);
      }
    } catch (e) {
      print("AR Update Error: $e");
    } finally {
      _isUpdatingAr = false;
    }
  }

  SwitchData _parsePrometheusText(String rawText, String targetIp) {
    String switchName = "Unknown Switch";
    String switchIp = targetIp;
    String uptimeStr = "N/A";
    List<PortData> ports = [];
    
    Map<int, int> portStatusMap = {};
    Map<int, String> portAliasMap = {};
    Map<int, int> portVlanMap = {};

    List<String> lines = const LineSplitter().convert(rawText);
    
    RegExp nameRegex = RegExp(r'sysName\{sysName="([^"]+)"\}');
    RegExp statusRegex = RegExp(r'ifOperStatus\{.*ifIndex="(\d+)".*\}\s+(\d+)');
    RegExp indexRegex = RegExp(r'ifIndex="(\d+)"');
    RegExp aliasRegex = RegExp(r'ifAlias="([^"]*)"');
    RegExp uptimeRegex = RegExp(r'sysUpTime\s+([0-9\.e\+\-]+)');
    RegExp vlanRegex = RegExp(r'(?:vmVlan|vlan_id|dot1qPvid|pvid).*ifIndex="(\d+)".*\s+(\d+)');

    for (var line in lines) {
      if (line.startsWith("#")) continue;

      var nameMatch = nameRegex.firstMatch(line);
      if (nameMatch != null) switchName = nameMatch.group(1) ?? "Unknown";

      var uptimeMatch = uptimeRegex.firstMatch(line);
      if (uptimeMatch != null) {
        try {
          double rawVal = double.parse(uptimeMatch.group(1)!);
          int totalSeconds = (rawVal / 100).round();
          Duration dur = Duration(seconds: totalSeconds);
          int days = dur.inDays;
          int hours = dur.inHours % 24;
          int minutes = dur.inMinutes % 60;
          int seconds = dur.inSeconds % 60;
          uptimeStr = "${days}d ${hours}h ${minutes}m ${seconds}s";
        } catch (e) {
          uptimeStr = "Err";
        }
      }

      var statusMatch = statusRegex.firstMatch(line);
      if (statusMatch != null) {
        int index = int.parse(statusMatch.group(1)!);
        int operStatus = int.parse(statusMatch.group(2)!);
        if (index >= 1 && index <= 24) {
          portStatusMap[index] = (operStatus == 1) ? 1 : 0;
        }
      }

      if (line.contains('ifAlias=')) {
        var idxMatch = indexRegex.firstMatch(line);
        var alMatch = aliasRegex.firstMatch(line);
        if (idxMatch != null && alMatch != null) {
          int index = int.parse(idxMatch.group(1)!);
          String alias = alMatch.group(1) ?? "";
          if (index >= 1 && index <= 24 && alias.trim().isNotEmpty) {
            portAliasMap[index] = alias;
          }
        }
      }

      var vlanMatch = vlanRegex.firstMatch(line);
      if (vlanMatch != null) {
        int index = int.parse(vlanMatch.group(1)!);
        int vlanId = int.parse(vlanMatch.group(2)!);
        if (index >= 1 && index <= 24) {
          portVlanMap[index] = vlanId;
        }
      }
    }

    for (int i = 1; i <= 24; i++) {
      ports.add(PortData(
        portId: i,
        linkedDevice: portAliasMap[i] ?? "",
        status: portStatusMap[i] ?? 0,
        vlan: portVlanMap[i] ?? 1,
      ));
    }
    return SwitchData(
        name: switchName, ip: switchIp, uptime: uptimeStr, ports: ports);
  }

  void _useFallbackData() {
    final String fallbackJson = '''
      {
        "name": "SW Offline",
        "model": "Fallback",
        "ip": "$_currentTargetIp",
        "uptime": "Unknown",
        "port": []
      }
    ''';
    SwitchData fallback = SwitchData.fromJson(jsonDecode(fallbackJson));
    for (int i = 1; i <= 24; i++) {
      fallback.ports
          .add(PortData(portId: i, linkedDevice: "", status: 0, vlan: 1));
    }
    setState(() {
      switchData = fallback;
      isLoadingData = false;
      status = "⚠️ Chế độ Offline. Đang khởi động...";
    });
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final cameraStatus = await Permission.camera.request();
    if (cameraStatus.isGranted) {
      setState(() {
        hasPermission = true;
        status = "Khởi động AR...";
      });
      Future.delayed(const Duration(seconds: 1), _loadYoloModel);
    } else {
      setState(() {
        status = "❌ Cần quyền Camera!";
      });
    }
  }

  Future<void> _loadYoloModel() async {
    try {
      setState(() {
        status = "Đang nạp AI...";
      });
      await vision.loadYoloModel(
        labels: 'assets/labelmap.txt',
        modelPath: 'assets/detect.tflite',
        modelVersion: "yolov8",
        quantization: true,
        useGpu: false,
      );
      setState(() {
        isModelLoaded = true;
        status = "✅ Sẵn sàng! Đang quét...";
      });
      _startAutoScan();
    } catch (e) {
      setState(() {
        status = "❌ Lỗi Model: ${e.toString()}";
      });
    }
  }

  void _startAutoScan() {
    scanTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (isModelLoaded &&
          !isLoadingData &&
          !isProcessing &&
          arCoreController != null &&
          mounted &&
          !frameVisible) {
        _captureAndDetect();
      }
    });
  }

  void _captureAndDetect() async {
    setState(() {
      isProcessing = true;
    });
    try {
      final Uint8List? imageBytes =
          await screenshotController.capture(pixelRatio: 0.5);
      if (imageBytes != null) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;

        final results = await vision.yoloOnImage(
          bytesList: imageBytes,
          imageHeight: screenHeight.toInt(),
          imageWidth: screenWidth.toInt(),
          confThreshold: 0.5,
          classThreshold: 0.5,
        );

        if (results.isNotEmpty) {
          final topResult = results.first;
          final double confidence = topResult['box'][4]?.toDouble() ?? 0.0;
          final String tag = topResult['tag'].toString();

          if (tag.contains('Switch') && confidence > 0.6) {
            scanTimer?.cancel();
            setState(() {
              currentBoundingBox = null;
              currentConfidence = confidence;
              status = "⚓ Đã neo Switch!";
              frameVisible = true;
            });
            _placeSwitch2D(topResult['box'], screenWidth, screenHeight);
          }
        }
      }
    } catch (e) {
      print("Scan Error: $e");
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  void _placeSwitch2D(
      List<dynamic> box, double screenWidth, double screenHeight) async {
    if (arCoreController == null) return;

    final double boxHeight = (box[3] - box[1]).toDouble();
    const double REAL_SWITCH_HEIGHT = 0.044;
    const double FOV_VERTICAL = 60.0;
    const double FOV_RAD = FOV_VERTICAL * math.pi / 180.0;

    double distance = (REAL_SWITCH_HEIGHT * screenHeight) /
        (2 * boxHeight * math.tan(FOV_RAD / 2));
    distance = distance.clamp(0.2, 3.0);

    final double centerX = (box[0] + box[2]) / 2.0;
    final double centerY = (box[1] + box[3]) / 2.0;
    final double ndcX = (centerX / screenWidth) * 2.0 - 1.0;
    final double ndcY = -((centerY / screenHeight) * 2.0 - 1.0);

    final double aspectRatio = screenWidth / screenHeight;
    final double fovHorizontal =
        2 * math.atan(math.tan(FOV_RAD / 2) * aspectRatio);

    final double frustumHeight = 2.0 * distance * math.tan(FOV_RAD / 2);
    final double frustumWidth = 2.0 * distance * math.tan(fovHorizontal / 2);

    double worldX = ndcX * (frustumWidth / 2.0);
    double worldY = ndcY * (frustumHeight / 2.0);
    double worldZ = -distance;

    worldY -= 0.15;

    vector64.Vector3 newPosition = vector64.Vector3(worldX, worldY, worldZ);
    lastStablePosition = newPosition;

    String initName = "SW_${DateTime.now().millisecondsSinceEpoch}";
    currentBaseName = initName;

    await _generateSwitchTextures();
    _spawnArNodesAt(newPosition, baseName: initName);

    setState(() {
      frameVisible = true;
      status = "⚓ Đã hiển thị: ${switchData.name}";
    });
  }

  void _spawnArNodesAt(vector64.Vector3 position, {required String baseName}) {
    final switchNode = _createNode(
      name: "${baseName}_panel",
      texture: _panelTextureCache,
      position: position,
      size: vector64.Vector3(_switchWidth, _switchHeight, 0.0001),
    );

    final linesNode = _createNode(
      name: "${baseName}_lines",
      texture: _linesTextureCache,
      position:
          vector64.Vector3(position.x, position.y, position.z - 0.0005),
      size: vector64.Vector3(_switchWidth, _linesHeight, 0.0001),
    );

    final labelPosition = vector64.Vector3(
      position.x - (_switchWidth / 2) - (_labelWidth / 2) - 0.01,
      position.y,
      position.z,
    );

    final labelNode = _createNode(
      name: "${baseName}_label",
      texture: _labelTextureCache,
      position: labelPosition,
      size: vector64.Vector3(_labelWidth, _labelHeight, 0.0001),
    );

    arCoreController!.addArCoreNode(switchNode);
    arCoreController!.addArCoreNode(linesNode);
    arCoreController!.addArCoreNode(labelNode);
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
    required vector64.Vector3 position,
    required vector64.Vector3 size,
  }) {
    final material = ArCoreMaterial(
      textureBytes: texture,
      color: Colors.black.withOpacity(0.0),
      metallic: 0.0,
      reflectance: 0.0,
      roughness: 1.0,
    );
    final shape = ArCoreCube(materials: [material], size: size);
    return ArCoreNode(shape: shape, position: position, name: name);
  }

  void _removeSpecificNodes(String baseName) {
    try {
      arCoreController?.removeNode(nodeName: "${baseName}_panel");
    } catch (e) {}
    try {
      arCoreController?.removeNode(nodeName: "${baseName}_lines");
    } catch (e) {}
    try {
      arCoreController?.removeNode(nodeName: "${baseName}_label");
    } catch (e) {}
  }

  void _removeSwitch2D() {
    if (currentBaseName != null) {
      _removeSpecificNodes(currentBaseName!);
      currentBaseName = null;
    }
  }

  void _onArCoreViewCreated(ArCoreController controller) {
    arCoreController = controller;
    if (currentBaseName != null) _removeSwitch2D();
  }

  void _toggleVlan() async {
    if (!frameVisible || lastStablePosition == null) return;
    setState(() {
      _showVlan = !_showVlan;
    });
    await _updateArContentSmoothly();
    frameVisible = true;
  }

  void _resetScanning() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );
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
    _apiTimer?.cancel();
    arCoreController?.dispose();
    vision.closeYoloModel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!hasPermission) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(status, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    final List<int> sortedVlans = _getActiveVlans().toList()..sort();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Screenshot(
            controller: screenshotController,
            child: ArCoreView(
              onArCoreViewCreated: _onArCoreViewCreated,
              enableTapRecognizer: true,
            ),
          ),
          if (!frameVisible)
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    status,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          if (frameVisible && _showVlan)
            Positioned(
              top: 100,
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
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    ...sortedVlans.map((vlanId) {
                      final color = _getVlanColor(vlanId);
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
                                    borderRadius: BorderRadius.circular(4))),
                            const SizedBox(width: 8),
                            Text("Vlan $vlanId",
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          if (frameVisible)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: _toggleVlan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _showVlan
                            ? Colors.orange.shade800
                            : Colors.blue.withOpacity(0.8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      child: Text(_showVlan ? "Hide VLAN" : "Show VLAN"),
                    ),
                    const SizedBox(width: 10),
                    FloatingActionButton.small(
                      onPressed: _resetScanning,
                      backgroundColor: Colors.redAccent,
                      child: const Icon(Icons.qr_code_scanner,
                          color: Colors.white),
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- TEXTURE FUNCTIONS: CẬP NHẬT LABEL ---
  Future<Uint8List> _createLabelTexture(
      {required SwitchData data,
      required double arWidth,
      required double arHeight}) async {
    final double aspectRatio = arHeight / arWidth;
    final int pixelWidth = 512;
    final int pixelHeight = (pixelWidth * aspectRatio).round();
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    final double labelRadius = 15.0;
    final Color labelBackgroundColor = const Color(0xFF4A80CC);
    final Color labelTextColor = Colors.white;
    final Rect labelRect =
        Rect.fromLTWH(0, 0, pixelWidth.toDouble(), pixelHeight.toDouble());
    final RRect labelRRect =
        RRect.fromRectAndRadius(labelRect, Radius.circular(labelRadius));
    canvas.drawRRect(labelRRect, ui.Paint()..color = labelBackgroundColor);

    // Dòng 1: Name
    final ui.ParagraphBuilder pbLine1 = ui.ParagraphBuilder(ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: pixelHeight * 0.22,
        fontWeight: FontWeight.w600,
        height: 1.0));
    pbLine1.pushStyle(ui.TextStyle(color: labelTextColor));
    pbLine1.addText(data.name);
    final ui.Paragraph paragraphLine1 = pbLine1.build()
      ..layout(ui.ParagraphConstraints(width: pixelWidth.toDouble()));
    canvas.drawParagraph(paragraphLine1, ui.Offset(0, pixelHeight * 0.15));

    // Dòng 2: IP
    final ui.ParagraphBuilder pbLine2 = ui.ParagraphBuilder(ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: pixelHeight * 0.18,
        fontWeight: FontWeight.w400,
        height: 1.0));
    pbLine2.pushStyle(ui.TextStyle(color: labelTextColor));
    pbLine2.addText(data.ip);
    final ui.Paragraph paragraphLine2 = pbLine2.build()
      ..layout(ui.ParagraphConstraints(width: pixelWidth.toDouble()));
    canvas.drawParagraph(paragraphLine2, ui.Offset(0, pixelHeight * 0.45));

    // Dòng 3: Uptime
    final ui.ParagraphBuilder pbLine3 = ui.ParagraphBuilder(ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: pixelHeight * 0.14,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        height: 1.0));
    pbLine3.pushStyle(ui.TextStyle(color: Colors.white.withOpacity(0.9)));
    pbLine3.addText("Up: ${data.uptime}");
    final ui.Paragraph paragraphLine3 = pbLine3.build()
      ..layout(ui.ParagraphConstraints(width: pixelWidth.toDouble()));
    canvas.drawParagraph(paragraphLine3, ui.Offset(0, pixelHeight * 0.70));

    final picture = recorder.endRecording();
    final img = await picture.toImage(pixelWidth, pixelHeight);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // 🔥 UPDATE: MÀU PORT ONLINE/OFFLINE
  Future<Uint8List> _createSwitchPanelTexture(
      {required SwitchData data,
      required double arWidth,
      required double arHeight,
      required bool showVlan}) async {
    final int pixelWidth = 1024;
    final double aspectRatio = arHeight / arWidth;
    final int pixelHeight = (pixelWidth * aspectRatio).round();
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    canvas.drawRect(
        Rect.fromLTWH(0, 0, pixelWidth.toDouble(), pixelHeight.toDouble()),
        Paint()..blendMode = BlendMode.clear);
    final Color outerBorderColor = const Color(0xFF000080);
    final double outerBorderWidth = 3.0;
    final Color innerFillColor = Colors.white.withOpacity(0.0);
    
    // --- KHAI BÁO MÀU MỚI ---
    final Color portColorOnline = const Color(0xFF00E676); // Xanh lá cây sáng (GreenAccent)
    final Color portColorOffline = const Color(0xFFD32F2F); // Đỏ đậm (RedAccent)
    
    final Color portBorderColor = const Color(0xFFADD8E6);
    final Color lightStripeColor = const Color(0xFFFFFFFF).withOpacity(0.7);
    final Color textColor = Colors.white.withOpacity(0.9);
    final Color iconColor = Colors.white.withOpacity(0.8);
    final double mainBorderRadius = 15.0;
    final Rect frameRect =
        Rect.fromLTWH(0, 0, pixelWidth.toDouble(), pixelHeight.toDouble());
    final RRect frameRRect =
        RRect.fromRectAndRadius(frameRect, Radius.circular(mainBorderRadius));
    final Paint outerBorderPaint = ui.Paint()
      ..color = outerBorderColor
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = outerBorderWidth;
    canvas.drawRRect(frameRRect, outerBorderPaint);
    final Rect innerFillRect = Rect.fromLTWH(
        frameRect.left + outerBorderWidth / 2,
        frameRect.top + outerBorderWidth / 2,
        frameRect.width - outerBorderWidth,
        frameRect.height - outerBorderWidth);
    final RRect innerFillRRect = RRect.fromRectAndRadius(innerFillRect,
        Radius.circular(mainBorderRadius - outerBorderWidth / 2));
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
    int portNumber = 0;
    final double vGap = cellHeight - portHeight;

    for (int c = 0; c < numCols; c++) {
      for (int r = 0; r < numRows; r++) {
        portNumber = 1 + (c * numRows) + r;
        final double hGap = cellWidth - portWidth;
        final double x = leftPadding + (c * cellWidth) + (hGap / 2);
        final double y = vPadding + (r * cellHeight) + (vGap / 2);
        final double mainRectHeight = portHeight * 0.8;
        final double latchHeight = portHeight * 0.2;
        final double latchWidth = portWidth * 0.5;
        final double latchStartX = x + (portWidth - latchWidth) / 2;
        final double latchEndX = latchStartX + latchWidth;
        final Path portPath = Path()
          ..moveTo(x, y + latchHeight)
          ..lineTo(latchStartX, y + latchHeight)
          ..lineTo(latchStartX, y)
          ..lineTo(latchEndX, y)
          ..lineTo(latchEndX, y + latchHeight)
          ..lineTo(x + portWidth, y + latchHeight)
          ..lineTo(x + portWidth, y + portHeight)
          ..lineTo(x, y + portHeight)
          ..lineTo(x, y + latchHeight)
          ..close();
        final portInfo = data.ports.firstWhere((p) => p.portId == portNumber,
            orElse: () => PortData(
                portId: portNumber, linkedDevice: "", status: 0, vlan: 1));
        
        Color currentFillColor;
        if (showVlan) {
          currentFillColor = _getVlanColor(portInfo.vlan);
        } else {
          // 🔥 SỬ DỤNG MÀU MỚI: ONLINE -> XANH LÁ, OFFLINE -> ĐỎ
          currentFillColor =
              (portInfo.status == 1) ? portColorOnline : portColorOffline;
        }
        canvas.drawPath(portPath, ui.Paint()..color = currentFillColor);
        canvas.drawPath(
            portPath,
            ui.Paint()
              ..color = portBorderColor
              ..style = ui.PaintingStyle.stroke
              ..strokeWidth = 2.5);
        final double stripeY = y + latchHeight + mainRectHeight * 0.7;
        final double stripeHeight = portHeight * 0.08;
        final double stripeStartX = x + (portWidth - (portWidth * 0.7)) / 2;
        final int numLines = 8;
        final double lineSpacing = ((portWidth * 0.7) / (numLines + 1));
        for (int i = 0; i < numLines; i++) {
          final double lx = stripeStartX + (i * lineSpacing);
          canvas.drawLine(
              Offset(lx, stripeY),
              Offset(lx, stripeY + stripeHeight),
              ui.Paint()
                ..color = lightStripeColor
                ..strokeWidth = 2.0);
        }
        final ui.ParagraphBuilder pb = ui.ParagraphBuilder(ui.ParagraphStyle(
            textAlign: TextAlign.left,
            fontSize: portHeight * 0.5,
            fontWeight: FontWeight.w300,
            height: 1.0));
        pb.pushStyle(ui.TextStyle(color: textColor));
        pb.addText('$portNumber');
        final ui.Paragraph paragraph = pb.build()
          ..layout(ui.ParagraphConstraints(width: portWidth * 0.5));
        canvas.drawParagraph(
            paragraph,
            ui.Offset(
                x + portWidth * 0.15,
                y +
                    latchHeight +
                    (mainRectHeight * 0.3) -
                    (paragraph.height / 2)));
        final double boltSize = portHeight * 0.30;
        final double boltX = x + portWidth * 0.60;
        final double boltY = y + latchHeight + mainRectHeight * 0.30;
        final Path boltPath = Path()
          ..moveTo(boltX + boltSize, boltY)
          ..lineTo(boltX + 0.3 * boltSize, boltY + 0.5 * boltSize)
          ..lineTo(boltX, boltY + boltSize)
          ..lineTo(boltX + 0.7 * boltSize, boltY + 0.5 * boltSize)
          ..close();
        canvas.drawPath(boltPath, ui.Paint()..color = iconColor);
        final ui.ParagraphBuilder starPb = ui.ParagraphBuilder(
            ui.ParagraphStyle(
                fontSize: boltSize * 0.6,
                fontWeight: FontWeight.bold,
                height: 1.0));
        starPb.pushStyle(ui.TextStyle(color: iconColor));
        starPb.addText('**');
        final ui.Paragraph starParagraph = starPb.build()
          ..layout(ui.ParagraphConstraints(width: boltSize * 2));
        canvas.drawParagraph(starParagraph,
            ui.Offset(boltX + boltSize * 1.1, boltY + boltSize * 0.3));
      }
    }
    final picture = recorder.endRecording();
    final img = await picture.toImage(pixelWidth, pixelHeight);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> _createLinesTexture(
      {required SwitchData data,
      required double arWidth,
      required double arHeight,
      required double arBaseHeight,
      required bool showVlan}) async {
    final int pixelWidth = 1024;
    final double totalAspectRatio = arHeight / arWidth;
    final int pixelHeight = (pixelWidth * totalAspectRatio).round();
    final double panelHeightRatio = arBaseHeight / arHeight;
    final int switchGraphicPixelHeight =
        (pixelHeight * panelHeightRatio).round();
    final double panelTopY = (pixelHeight / 2) - (switchGraphicPixelHeight / 2);
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    canvas.drawRect(
        Rect.fromLTWH(0, 0, pixelWidth.toDouble(), pixelHeight.toDouble()),
        Paint()..blendMode = BlendMode.clear);
    final int numRows = 2;
    final int numCols = 12;
    final double leftPadding = pixelWidth * 0.3;
    final double rightPadding = pixelWidth * 0.05;
    final double vPadding = switchGraphicPixelHeight * 0.15;
    final double portsDrawableWidth = pixelWidth - leftPadding - rightPadding;
    final double cellWidth = portsDrawableWidth / numCols;
    final double cellHeight =
        (switchGraphicPixelHeight - (vPadding * 2)) / numRows;
    final double portHeight = cellHeight * 0.7;
    final double portWidth = cellWidth * 0.8;
    final double hGap = cellWidth - portWidth;
    final double vGap = cellHeight - portHeight;

    final double labelTextFontSize = 14.0;
    final double labelMaxWidth = cellWidth * 1.6;
    final double labelHeight = labelTextFontSize * 1.2;
    final double rotationAngle = math.pi / 4;
    final double lineToLabelSpacing = 3.0;
    final double lineLengthReduction = 45.0;
    final ui.FontWeight labelFontWeight = ui.FontWeight.w800;
    final ui.Color labelColor = Colors.black;
    for (int c = 0; c < numCols; c++) {
      for (int r = 0; r < numRows; r++) {
        int portNumber = 1 + (c * numRows) + r;
        final double x = leftPadding + (c * cellWidth) + (hGap / 2);
        final double y = panelTopY + vPadding + (r * cellHeight) + (vGap / 2);
        final portData = data.ports.firstWhere((p) => p.portId == portNumber,
            orElse: () => PortData(
                portId: portNumber, linkedDevice: "", status: 0, vlan: 1));
        final double lineStartX = x + (portWidth / 2);
        double lineStartY, lineEndY;
        if (r == 0) {
          lineStartY = y;
          double pivotY = lineStartY - lineLengthReduction;
          lineEndY = pivotY + lineToLabelSpacing + labelHeight / 2;
        } else {
          lineStartY = y + portHeight;
          double pivotY = lineStartY + lineLengthReduction;
          lineEndY = pivotY - lineToLabelSpacing - labelHeight / 2;
        }
        final portLinePaint = ui.Paint()
          ..color = Colors.white.withOpacity(0.9)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.8;
        canvas.drawLine(Offset(lineStartX, lineStartY),
            Offset(lineStartX, lineEndY), portLinePaint);
        final ui.ParagraphBuilder pbLabel = ui.ParagraphBuilder(
            ui.ParagraphStyle(
                textAlign: TextAlign.start,
                fontSize: labelTextFontSize,
                fontWeight: labelFontWeight,
                height: 1.0));
        pbLabel.pushStyle(ui.TextStyle(color: labelColor));
        String labelText = showVlan
            ? "Vlan: ${portData.vlan}"
            : (portData.linkedDevice.isNotEmpty
                ? portData.linkedDevice
                : "Port $portNumber");
        pbLabel.addText(labelText);
        final ui.Paragraph pLabel = pbLabel.build()
          ..layout(ui.ParagraphConstraints(width: labelMaxWidth));
        canvas.save();
        canvas.translate(lineStartX, lineEndY);
        if (r == 0) {
          canvas.rotate(-rotationAngle);
          canvas.drawParagraph(pLabel, ui.Offset(0, -pLabel.height));
        } else {
          canvas.rotate(rotationAngle);
          canvas.drawParagraph(pLabel, ui.Offset(0, 0));
        }
        canvas.restore();
      }
    }
    final picture = recorder.endRecording();
    final img = await picture.toImage(pixelWidth, pixelHeight);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}