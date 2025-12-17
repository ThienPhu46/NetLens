import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'ar_switch_screen.dart'; // File AR cũ của bạn
import 'device_details.dart';   // File chi tiết vừa tạo
import 'add_device.dart';

// --- MODELS ---
enum DeviceStatus { online, offline }
enum DeviceType { router, server, laptop, printer, camera, other }

class DeviceModel {
  final String name;
  final String ip;
  final DeviceType type;
  final DeviceStatus status;

  DeviceModel({
    required this.name,
    required this.ip,
    required this.type,
    required this.status,
  });
}

// --- SCREEN: DANH SÁCH THIẾT BỊ ---
class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  // --- COLOR PALETTE (Lấy từ ảnh thiết kế) ---
  static const Color primaryBlue = Color(0xFF004AAD); // Màu xanh chủ đạo
  static const Color backgroundCol = Color(0xFFF0F4F8); // Màu nền xám xanh nhẹ
  static const Color textDark = Color(0xFF1E293B); // Màu chữ đậm
  static const Color textGrey = Color(0xFF64748B); // Màu chữ nhạt

  // --- DATA MẪU ---
  final List<DeviceModel> _onlineDevices = [
    DeviceModel(name: "Router Main", ip: "192.168.1.1", type: DeviceType.router, status: DeviceStatus.online),
    DeviceModel(name: "Web Server 01", ip: "10.0.0.52", type: DeviceType.server, status: DeviceStatus.online),
    DeviceModel(name: "MacBook Pro", ip: "192.168.1.104", type: DeviceType.laptop, status: DeviceStatus.online),
  ];

  final List<DeviceModel> _offlineDevices = [
    DeviceModel(name: "Printer Lab", ip: "192.168.1.15", type: DeviceType.printer, status: DeviceStatus.offline),
    DeviceModel(name: "Camera Cổng Sau", ip: "192.168.1.201", type: DeviceType.camera, status: DeviceStatus.offline),
  ];

  // Hàm chuyển sang màn hình Scan QR
  void _openQrScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );
  }

  // Hàm chuyển đổi Model sang Map cho màn hình Detail
  Map<String, dynamic> _deviceToMap(DeviceModel device) {
    return {
      'name': device.name,
      'ip': device.ip,
      'status': device.status == DeviceStatus.online ? 'Online' : 'Offline',
      'type': device.type.toString(),
      'icon': _getIconForType(device.type), // Truyền icon sang detail
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCol,
      body: Stack(
        children: [
          // 1. DANH SÁCH CUỘN (Content)
          CustomScrollView(
            slivers: [
              // Header & Search (Sticky)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 50, 16, 0), // Top padding cho status bar
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hàng Tiêu đề & Settings
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Danh sách thiết bị",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: primaryBlue,
                              letterSpacing: -0.5,
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.settings, color: Colors.black87),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Thanh tìm kiếm
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25), // Bo tròn như hình
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const TextField(
                          decoration: InputDecoration(
                            hintText: "Tìm tên hoặc IP...",
                            hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                            prefixIcon: Icon(Icons.search, color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Danh sách Online
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildSectionHeader("TRỰC TUYẾN (${_onlineDevices.length})"),
                    const SizedBox(height: 12),
                    ..._onlineDevices.map((d) => _buildDeviceCard(d)),
                    const SizedBox(height: 24),
                  ]),
                ),
              ),

              // Danh sách Offline
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120), // Padding dưới để né BottomBar
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildSectionHeader("NGOẠI TUYẾN (${_offlineDevices.length})"),
                    const SizedBox(height: 12),
                    ..._offlineDevices.map((d) => _buildDeviceCard(d)),
                  ]),
                ),
              ),
            ],
          ),

          // 2. FAB BUTTON (+)
          Positioned(
            bottom: 100, // Nằm trên BottomBar
            right: 20,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AddDeviceScreen()),
                );
              },
              backgroundColor: primaryBlue,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),

          // 3. BOTTOM NAVIGATION BAR
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Tab Thiết bị (Active)
                  _buildNavItem(Icons.devices, "Thiết bị", isActive: true),
                  
                  // Nút giữa (Quét thiết bị - Radar Icon)
                  GestureDetector(
                    onTap: _openQrScanner,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: primaryBlue,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.radar, color: Colors.white, size: 26),
                        ),
                        const Text(
                          "Quét thiết bị",
                          style: TextStyle(
                            fontSize: 10, 
                            fontWeight: FontWeight.bold, 
                            color: primaryBlue
                          ),
                        )
                      ],
                    ),
                  ),

                  // Tab Tài khoản (Inactive)
                  _buildNavItem(Icons.person, "Tài khoản", isActive: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET CON ---

  // Header phân loại (Online/Offline)
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: primaryBlue,
        fontWeight: FontWeight.bold,
        fontSize: 13,
        letterSpacing: 0.5,
      ),
    );
  }

  // Card thiết bị
  Widget _buildDeviceCard(DeviceModel device) {
    final bool isOnline = device.status == DeviceStatus.online;

    return GestureDetector(
      onTap: () {
        // Chuyển sang màn hình chi tiết
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DeviceDetailScreen(deviceData: _deviceToMap(device)),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon tròn bên trái
            Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.blue.shade50 : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIconForType(device.type),
                    color: isOnline ? primaryBlue : Colors.grey.shade600,
                    size: 24,
                  ),
                ),
                // Chấm trạng thái nhỏ
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(width: 16),
            
            // Tên và IP
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    device.ip,
                    style: const TextStyle(
                      fontSize: 13,
                      color: textGrey,
                      fontFamily: 'RobotoMono', // Giả lập font mono
                    ),
                  ),
                ],
              ),
            ),

            // Badge trạng thái
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isOnline ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2), // Xanh nhạt / Đỏ nhạt
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isOnline ? "Online" : "Offline",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isOnline ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }

  // Item Bottom Bar
  Widget _buildNavItem(IconData icon, String label, {required bool isActive}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: isActive ? primaryBlue : Colors.grey,
          size: 26,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? primaryBlue : Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        )
      ],
    );
  }

  IconData _getIconForType(DeviceType type) {
    switch (type) {
      case DeviceType.router: return Icons.router;
      case DeviceType.server: return Icons.dns;
      case DeviceType.laptop: return Icons.laptop_mac;
      case DeviceType.printer: return Icons.print;
      case DeviceType.camera: return Icons.videocam;
      default: return Icons.devices_other;
    }
  }
}

// --- MÀN HÌNH QUÉT QR (Giữ nguyên logic cũ) ---
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
      setState(() => isProcessing = true);
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
                    if (capture.barcodes.isNotEmpty) _handleBarcode(capture.barcodes.first);
                  },
                ),
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red.withOpacity(0.5), width: 3),
                      borderRadius: BorderRadius.circular(10),
                    ),
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
                style: TextStyle(color: Colors.black54),
              ),
            ),
          )
        ],
      ),
    );
  }
}