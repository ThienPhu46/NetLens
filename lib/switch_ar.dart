import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector64;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';

// --- ENUM: QUẢN LÝ TRẠNG THÁI HIỂN THỊ ---
enum SwitchDisplay {
  none,
  switch1,
  switch2,
  both,
}

// --- CLASS DỮ LIỆU ---
class PortData {
  final int portId;
  final String linkedDevice;
  final int status; // Trạng thái: 1 = Đỏ, 0 = Xanh

  PortData({required this.portId, required this.linkedDevice, required this.status});

  factory PortData.fromJson(Map<String, dynamic> json) {
    return PortData(
      portId: json['portId'] ?? 0,
      linkedDevice: json['linkedDevice'] ?? "",
      // Chuyển đổi an toàn sang int
      status: int.tryParse(json['Status'].toString()) ?? 0,
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

class switch_AR extends StatefulWidget {
  const switch_AR({super.key});
  @override
  State<switch_AR> createState() => _switch_ARState();
}

class _switch_ARState extends State<switch_AR> {
  ArCoreController? arCoreController;

  // --- DỮ LIỆU JSON & CÁC BIẾN QUẢN LÝ ---
  SwitchDisplay _visibleSwitch = SwitchDisplay.none;

  // Dữ liệu Switch 1
  // Show Vlan
  //Show Vlan đổi tên port thành Vlan,
  //Thêm bảng chú thích màu của các port, vlan, 
  // Tạo button show vlan. git init
  final String jsonString1 = '''
  {
    "name": "SW Test 1",
    "model": "Test Model 1",
    "ip": "192.168.1.1",
    "port": [
      { "portId": 1, "linkedDevice": "CS02-AP-D401","Status": 1, "Vlan": 1 },
      { "portId": 2, "linkedDevice": "CS02-AP-D402","Status": 1 },
      { "portId": 3, "linkedDevice": "CS02-AP-D403","Status": 0 },
      { "portId": 4, "linkedDevice": "CS02-AP-D404","Status": 1 },
      { "portId": 5, "linkedDevice": "CS02-AP-D405","Status": 0 },
      { "portId": 6, "linkedDevice": "Camera 2","Status": 1 },
      { "portId": 7, "linkedDevice": "Printer","Status": 1 },
      { "portId": 8, "linkedDevice": "Wifi AP","Status": 1 },
      { "portId": 9, "linkedDevice": "Server","Status": 1 },
      { "portId": 10, "linkedDevice": "Router","Status": 1 },
      { "portId": 11, "linkedDevice": "","Status": 1 },
      { "portId": 12, "linkedDevice": "Device D","Status": 0 },
      { "portId": 13, "linkedDevice": "Device E","Status": 1 },
      { "portId": 14, "linkedDevice": "Device F","Status": 1 },
      { "portId": 15, "linkedDevice": "Device G","Status": 1 },
      { "portId": 16, "linkedDevice": "Device H","Status": 0 },
      { "portId": 17, "linkedDevice": "Device I","Status": 1 },
      { "portId": 18, "linkedDevice": "Device J","Status": 1 },
      { "portId": 19, "linkedDevice": "Device K","Status": 0 },
      { "portId": 20, "linkedDevice": "Device L","Status": 1 },
      { "portId": 21, "linkedDevice": "Device M","Status": 1 },
      { "portId": 22, "linkedDevice": "Device N","Status": 0 },
      { "portId": 23, "linkedDevice": "Device O","Status": 1 },
      { "portId": 24, "linkedDevice": "Device P","Status": 1 }
    ]
  }
  ''';
  
  // Dữ liệu Switch 2
  final String jsonString2 = '''
  {
    "name": "SW Test 2",
    "model": "Test Model 2",
    "ip": "192.168.2.1",
    "port": [
      { "portId": 1, "linkedDevice": "S2-Device A", "Status": 1 },
      { "portId": 2, "linkedDevice": "S2-Device B", "Status": 0 },
      { "portId": 3, "linkedDevice": "S2-Device C","Status": 1 },
      { "portId": 4, "linkedDevice": "S2-Device D","Status": 1 },
      { "portId": 5, "linkedDevice": "S2-Device E","Status": 0 },
      { "portId": 6, "linkedDevice": "S2-Device F","Status": 1 },
      { "portId": 7, "linkedDevice": "S2-Device G","Status": 1 },
      { "portId": 8, "linkedDevice": "S2-Device H","Status": 1 },
      { "portId": 9, "linkedDevice": "S2-Device I","Status": 1 },
      { "portId": 10, "linkedDevice": "S2-Device J","Status": 0 },
      { "portId": 11, "linkedDevice": "S2-Device K","Status": 0 },
      { "portId": 12, "linkedDevice": "S2-Device L","Status": 0 },
      { "portId": 13, "linkedDevice": "S2-Device M","Status": 1 },
      { "portId": 14, "linkedDevice": "S2-Device N","Status": 1 },
      { "portId": 15, "linkedDevice": "S2-Device O","Status": 1 },
      { "portId": 16, "linkedDevice": "S2-Device P","Status": 0 },
      { "portId": 17, "linkedDevice": "S2-Device Q","Status": 1 },
      { "portId": 18, "linkedDevice": "S2-Device R","Status": 1 },
      { "portId": 19, "linkedDevice": "S2-Device S","Status": 0 },
      { "portId": 20, "linkedDevice": "S2-Device T","Status": 1 },
      { "portId": 21, "linkedDevice": "S2-Device U","Status": 1 },
      { "portId": 22, "linkedDevice": "S2-Device V","Status": 1 },
      { "portId": 23, "linkedDevice": "S2-Device W","Status": 0 },
      { "portId": 24, "linkedDevice": "S2-Device X","Status": 1 }
    ]
  }
  ''';

  late SwitchData switchData1;
  late SwitchData switchData2;

  // --- CÁC BIẾN AR NODE CHO SWITCH 1 ---
  ArCoreNode? _switchNode1;
  ArCoreNode? _linesNode1;
  ArCoreNode? _labelNode1;

  // --- CÁC BIẾN AR NODE CHO SWITCH 2 ---
  ArCoreNode? _switchNode2;
  ArCoreNode? _linesNode2;
  ArCoreNode? _labelNode2;
  
  // Cache Texture chung cho 2 switch
  Uint8List? _panelTextureCache1;
  Uint8List? _linesTextureCache1;
  Uint8List? _labelTextureCache1;

  Uint8List? _panelTextureCache2; 
  Uint8List? _linesTextureCache2; 
  Uint8List? _labelTextureCache2; 

  // --- KÍCH THƯỚC VÀ VỊ TRÍ ---
  final double _switchWidth = 0.4;
  final double _switchHeight = 0.04445; 
  final double _linesHeight = 0.04445 * 3.0; 
  final double _labelWidth = 0.15;
  final double _labelHeight = 0.04;
  
  final double _switchGap = 0.25; // Khoảng cách
  final double _initialZ = -0.3; // Vị trí

  vector64.Vector3 currentPositionValue = vector64.Vector3(0, 0, -0.3); 
  
  double _sensitivity = 0.002;
  bool isDragging = false;

  @override
  void initState() {
    super.initState();
    try {
      switchData1 = SwitchData.fromJson(jsonDecode(jsonString1));
      switchData2 = SwitchData.fromJson(jsonDecode(jsonString2));
    } catch (e) {
      print("Error parsing JSON: $e");
      switchData1 = SwitchData(name: "Error 1", ip: "", ports: []);
      switchData2 = SwitchData(name: "Error 2", ip: "", ports: []);
    }
  }

  @override
  void dispose() {
    _removeAllNodes();
    arCoreController?.dispose();
    super.dispose();
  }

  void _removeNodeByName(String? name) {
    if (name != null) {
      try {
        arCoreController?.removeNode(nodeName: name);
      } catch (e) {
        // Ignored
      }
    }
  }

  void _removeAllNodes() {
    _removeNodeByName(_switchNode1?.name);
    _removeNodeByName(_linesNode1?.name);
    _removeNodeByName(_labelNode1?.name);
    _removeNodeByName(_switchNode2?.name);
    _removeNodeByName(_linesNode2?.name);
    _removeNodeByName(_labelNode2?.name);
  }

  void onArCoreViewCreated(ArCoreController controller) async {
    arCoreController = controller;
    
    // 1. Tạo cache textures cho Switch 1 (TỰ ĐỘNG MÀU THEO STATUS)
    _panelTextureCache1 = await _createSwitchPanelTexture(
      data: switchData1,
      arWidth: _switchWidth,
      arHeight: _switchHeight,
    );
    _linesTextureCache1 = await _createLinesTexture(
      data: switchData1,
      arWidth: _switchWidth,
      arHeight: _linesHeight,
      arBaseHeight: _switchHeight,
    );
    _labelTextureCache1 = await _createLabelTexture(
      data: switchData1,
      arWidth: _labelWidth,
      arHeight: _labelHeight,
    );

    // 2. Tạo cache textures cho Switch 2 (TỰ ĐỘNG MÀU THEO STATUS)
    _panelTextureCache2 = await _createSwitchPanelTexture(
      data: switchData2,
      arWidth: _switchWidth,
      arHeight: _switchHeight,
    );
    _linesTextureCache2 = await _createLinesTexture(
      data: switchData2,
      arWidth: _switchWidth,
      arHeight: _linesHeight,
      arBaseHeight: _switchHeight,
    );
    _labelTextureCache2 = await _createLabelTexture(
      data: switchData2,
      arWidth: _labelWidth,
      arHeight: _labelHeight,
    );
    
    _initNodes();
  }
  
  void _initNodes() {
    final pos1 = vector64.Vector3(0, _switchGap / 2, _initialZ);
    final pos2 = vector64.Vector3(0, -_switchGap / 2, _initialZ);
    
    // SỬ DỤNG LẠI _createNode (ArCoreCube) với kích thước mỏng
    _switchNode1 = _createNode(name: 'switch_node_1', texture: _panelTextureCache1, position: pos1, size: vector64.Vector3(_switchWidth, _switchHeight, 0.0001));
    _linesNode1 = _createNode(name: 'lines_node_1', texture: _linesTextureCache1, position: vector64.Vector3(pos1.x, pos1.y, pos1.z - 0.0005), size: vector64.Vector3(_switchWidth, _linesHeight, 0.0001));
    _labelNode1 = _createNode(name: 'label_node_1', texture: _labelTextureCache1, position: _getLabelPosition(pos1), size: vector64.Vector3(_labelWidth, _labelHeight, 0.0001));

    _switchNode2 = _createNode(name: 'switch_node_2', texture: _panelTextureCache2, position: pos2, size: vector64.Vector3(_switchWidth, _switchHeight, 0.0001));
    _linesNode2 = _createNode(name: 'lines_node_2', texture: _linesTextureCache2, position: vector64.Vector3(pos2.x, pos2.y, pos2.z - 0.0005), size: vector64.Vector3(_switchWidth, _linesHeight, 0.0001));
    _labelNode2 = _createNode(name: 'label_node_2', texture: _labelTextureCache2, position: _getLabelPosition(pos2), size: vector64.Vector3(_labelWidth, _labelHeight, 0.0001));
  }

  // HÀM TẠO NODE BẰNG ArCoreCube (TƯƠNG THÍCH VỚI PHIÊN BẢN CŨ)
  ArCoreNode _createNode({
    required String name,
    required Uint8List? texture,
    required vector64.Vector3 position,
    required vector64.Vector3 size,
  }) {
    final material = ArCoreMaterial(
      textureBytes: texture,
      // Đặt màu vật liệu cơ bản là TRẮNG TRONG SUỐT HOÀN TOÀN
      color: Colors.white.withOpacity(0.1), 
      metallic: 0.0,
      reflectance: 0.0,
      roughness: 1.0,
    );

    // Sử dụng ArCoreCube
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

  vector64.Vector3 _getLabelPosition(vector64.Vector3 switchPosition) {
    return vector64.Vector3(
      switchPosition.x - (_switchWidth / 2) - (_labelWidth / 2) - 0.01,
      switchPosition.y,
      switchPosition.z,
    );
  }

  void _updateDisplay(SwitchDisplay newDisplay) async {
    if (arCoreController == null) return;
    
    SwitchDisplay targetDisplay;

    // Toggle logic
    if (_visibleSwitch == newDisplay) {
      targetDisplay = SwitchDisplay.none; 
    } else {
      targetDisplay = newDisplay; 
    }
    
    // Reset vị trí Z nếu chuyển từ không hiển thị sang hiển thị
    if (targetDisplay != SwitchDisplay.none && _visibleSwitch == SwitchDisplay.none) {
      currentPositionValue = vector64.Vector3(
        currentPositionValue.x, 
        currentPositionValue.y, 
        _initialZ
      );
    } 

    // Xóa hết rồi vẽ lại
    _removeAllNodes();
    _initNodes(); 

    setState(() {
      _visibleSwitch = targetDisplay;
    });

    if (targetDisplay == SwitchDisplay.none) return;

    if (targetDisplay == SwitchDisplay.switch1 || targetDisplay == SwitchDisplay.both) {
      _addSwitchToScene(_switchNode1, _linesNode1, _labelNode1);
    }

    if (targetDisplay == SwitchDisplay.switch2 || targetDisplay == SwitchDisplay.both) {
      _addSwitchToScene(_switchNode2, _linesNode2, _labelNode2);
    }
  }

  void _addSwitchToScene(
    ArCoreNode? switchNode, 
    ArCoreNode? linesNode, 
    ArCoreNode? labelNode,
  ) {
    if (arCoreController == null || switchNode == null || linesNode == null || labelNode == null) return;
    
    arCoreController!.addArCoreNode(switchNode);
    arCoreController!.addArCoreNode(linesNode);
    arCoreController!.addArCoreNode(labelNode);
  }

  void _handleDrag(DragUpdateDetails details) {
    if (!isDragging || arCoreController == null || _visibleSwitch == SwitchDisplay.none) return;

    currentPositionValue = vector64.Vector3(
      currentPositionValue.x + details.delta.dx * _sensitivity,
      currentPositionValue.y - details.delta.dy * _sensitivity,
      currentPositionValue.z,
    );
    
    final pos1 = vector64.Vector3(currentPositionValue.x, currentPositionValue.y + _switchGap / 2, currentPositionValue.z);
    final labelPos1 = _getLabelPosition(pos1);
    final linesPos1 = vector64.Vector3(pos1.x, pos1.y, pos1.z - 0.0005);

    final pos2 = vector64.Vector3(currentPositionValue.x, currentPositionValue.y - _switchGap / 2, currentPositionValue.z);
    final labelPos2 = _getLabelPosition(pos2);
    final linesPos2 = vector64.Vector3(pos2.x, pos2.y, pos2.z - 0.0005);

    if (_visibleSwitch == SwitchDisplay.switch1 || _visibleSwitch == SwitchDisplay.both) {
      _switchNode1!.position?.value = pos1;
      _linesNode1!.position?.value = linesPos1;
      _labelNode1!.position?.value = labelPos1;
    }
    if (_visibleSwitch == SwitchDisplay.switch2 || _visibleSwitch == SwitchDisplay.both) {
      _switchNode2!.position?.value = pos2;
      _linesNode2!.position?.value = linesPos2;
      _labelNode2!.position?.value = labelPos2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          ArCoreView(
            onArCoreViewCreated: onArCoreViewCreated,
            enableTapRecognizer: true,
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) {
              setState(() => isDragging = true);
            },
            onPanUpdate: _handleDrag,
            onPanEnd: (details) {
              setState(() => isDragging = false);
            },
            child: Container(
              color: Colors.transparent,
            ),
          ),
          
          // UI Điều khiển (Đã xóa Input và Nút Set Color)
          Positioned(
            bottom: 20,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSwitchButton(SwitchDisplay.switch1, "Switch 1"),
                  _buildSwitchButton(SwitchDisplay.switch2, "Switch 2"),
                  _buildSwitchButton(SwitchDisplay.both, "Cả 2 Switch"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSwitchButton(SwitchDisplay display, String label) {
    bool isSelected = _visibleSwitch == display;
    return ElevatedButton(
      onPressed: () => _updateDisplay(display),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.green.shade700 : Colors.blueGrey.shade700,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      ),
      child: Text(label),
    );
  }

  // --- HÀM TẠO LABEL TEXTURE (GIỮ TRONG SUỐT) ---
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

    // 1. Đảm bảo nền texture là trong suốt (Clear background)
    canvas.drawRect(Rect.fromLTWH(0, 0, pixelWidth.toDouble(), pixelHeight.toDouble()), Paint()..blendMode = BlendMode.clear);

    // Đảm bảo không có lệnh vẽ nền mờ đục nào ở đây

    final Color labelTextColor = Colors.white;

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

  // --- 8. HÀM TẠO SWITCH PANEL TEXTURE (GIỮ TRONG SUỐT) ---
  Future<Uint8List> _createSwitchPanelTexture({
    required SwitchData data, // Dữ liệu chứa Status
    required double arWidth,
    required double arHeight,
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
    
    // MÀU SẮC PORT (Status: 1 = Đỏ, 0 = Xanh)
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

        // 🔥 TỰ ĐỘNG CHỌN MÀU DỰA TRÊN STATUS 🔥
        final portInfo = data.ports.firstWhere(
          (p) => p.portId == portNumber, 
          orElse: () => PortData(portId: portNumber, linkedDevice: "", status: 0) // <-- ĐÃ SỬA lỗi
        );

        Color currentFillColor;
        if (portInfo.status == 1) {
          currentFillColor = portColorRed; 
        } else {
          currentFillColor = portColorBlue;
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

  // --- 9. HÀM TẠO LINES TEXTURE (GIỮ TRONG SUỐT) ---
  Future<Uint8List> _createLinesTexture({
    required SwitchData data, 
    required double arWidth,
    required double arHeight, 
    required double arBaseHeight, 
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
          orElse: () => PortData(portId: portNumber, linkedDevice: "", status: 0), // <-- Sửa lỗi PortData
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

        // 1. Vẽ Đường kẻ
        final portLinePaint = ui.Paint()..color = Colors.white.withOpacity(0.9)..style = ui.PaintingStyle.stroke..strokeWidth = 1.8;
        canvas.drawLine(Offset(lineStartX, lineStartY), Offset(lineStartX, lineEndY), portLinePaint);

        // --- 2. ÁP DỤNG XOAY (ROTATION) CHO LABEL ---
        final ui.ParagraphBuilder pbLabel = ui.ParagraphBuilder(
          ui.ParagraphStyle(textAlign: TextAlign.start, fontSize: labelTextFontSize, fontWeight: labelFontWeight, height: 1.0));
        pbLabel.pushStyle(ui.TextStyle(color: labelColor));
        
        String labelText = portData.linkedDevice.isNotEmpty 
              ? portData.linkedDevice 
              : "Port $portNumber"; 

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
        
        // VẼ TEXT (KHÔNG CÓ NỀN)
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