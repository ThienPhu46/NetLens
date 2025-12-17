import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Để dùng Clipboard
import 'qr_scanner_screen.dart'; // Import màn hình scan

class DeviceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> deviceData;

  const DeviceDetailScreen({super.key, required this.deviceData});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  // --- COLOR PALETTE (Đồng bộ với Device List) ---
  static const Color primaryBlue = Color(0xFF004AAD); // Xanh chủ đạo
  static const Color darkBlueBtn = Color(0xFF1E3A8A); // Màu nút SSH đậm
  static const Color backgroundCol = Color(0xFFF0F4F8); // Nền xám xanh
  static const Color textDark = Color(0xFF1E293B);
  static const Color textGrey = Color(0xFF64748B);

  // Dữ liệu giả lập chi tiết
  late Map<String, dynamic> _fullDetails;

  @override
  void initState() {
    super.initState();
    // Merge dữ liệu từ màn hình list với dữ liệu giả
    _fullDetails = {
      ...widget.deviceData,
      'model': 'Cisco Catalyst 9300',
      'mac': '00:1B:44:11:3A:B7',
      'uptime': '14 days, 2 hrs',
      'location': 'Server Room A',
    };
  }

  // Hàm copy
  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Đã sao chép $label: $text"),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // Hàm mở Scanner
  void _openQrScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check status từ dữ liệu
    bool isOnline = _fullDetails['status'] == 'Online';

    return Scaffold(
      backgroundColor: backgroundCol,
      body: Stack(
        children: [
          // 1. NỘI DUNG CHÍNH (SCROLLABLE)
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              children: [
                // --- HEADER ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        color: textDark,
                      ),
                      const Expanded(
                        child: Text(
                          "Chi tiết thiết bị",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40), // Cân bằng layout
                    ],
                  ),
                ),

                // --- HERO SECTION (AVATAR) ---
                Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
                            ],
                            color: Colors.black, // Placeholder màu đen cho server
                          ),
                          // Giả lập ảnh Server rack
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(60),
                            child: const Icon(Icons.dns, size: 60, color: Colors.white24),
                          ),
                        ),
                        Positioned(
                          bottom: 5,
                          right: 5,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isOnline ? Colors.green : Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(Icons.check, size: 16, color: Colors.white),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _fullDetails['name'] ?? "Device",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isOnline ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isOnline ? "ONLINE" : "OFFLINE",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isOnline ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _fullDetails['model'],
                          style: const TextStyle(color: textGrey, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // --- ACTION BUTTONS (Hình tròn to như ảnh) ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildCircleAction(
                        icon: Icons.terminal,
                        label: "SSH Connect",
                        bgColor: darkBlueBtn, // Màu xanh đậm đặc biệt
                        iconColor: Colors.white,
                        textColor: darkBlueBtn, // Label màu xanh
                        isMain: true,
                      ),
                      _buildCircleAction(
                        icon: Icons.wifi_tethering,
                        label: "Check Status",
                        bgColor: Colors.white,
                        iconColor: primaryBlue,
                        textColor: textDark,
                      ),
                      _buildCircleAction(
                        icon: Icons.edit,
                        label: "Edit Info",
                        bgColor: Colors.white,
                        iconColor: primaryBlue,
                        textColor: textDark,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // --- SYSTEM INFO ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "System Info",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildInfoRow(Icons.lan, "IP ADDRESS", _fullDetails['ip'], canCopy: true),
                            const Divider(height: 1, indent: 60, endIndent: 20, color: Color(0xFFF1F5F9)),
                            _buildInfoRow(Icons.fingerprint, "MAC ADDRESS", _fullDetails['mac'], canCopy: true),
                            const Divider(height: 1, indent: 60, endIndent: 20, color: Color(0xFFF1F5F9)),
                            _buildInfoRow(Icons.schedule, "UPTIME", _fullDetails['uptime']),
                            const Divider(height: 1, indent: 60, endIndent: 20, color: Color(0xFFF1F5F9)),
                            _buildInfoRow(Icons.location_on, "LOCATION", _fullDetails['location'], hasArrow: true),
                          ],
                        ),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // --- RECENT ACTIVITY ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text("Recent Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
                          Text("View All", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textGrey)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                        ),
                        child: Column(
                          children: [
                            _buildActivityItem(Colors.green, "System Online", "Recovered from reboot", "2m ago"),
                            const Divider(height: 1, indent: 20, endIndent: 20, color: Color(0xFFF1F5F9)),
                            _buildActivityItem(primaryBlue, "Config Changed", "Updated VLAN settings", "2h ago"),
                            const Divider(height: 1, indent: 20, endIndent: 20, color: Color(0xFFF1F5F9)),
                            _buildActivityItem(Colors.red, "Port 0/1 Down", "Link loss detected", "5h ago"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. BOTTOM NAVIGATION BAR (Giống hệt Device List)
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
                  // Tab Thiết bị (Vẫn active vì đang xem chi tiết thiết bị)
                  _buildNavItem(Icons.devices, "Thiết bị", isActive: true),
                  
                  // Nút giữa (Quét thiết bị)
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

                  // Tab Tài khoản
                  _buildNavItem(Icons.person, "Tài khoản", isActive: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPER ---

  // Nút hành động tròn to
  Widget _buildCircleAction({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color iconColor,
    required Color textColor,
    bool isMain = false,
  }) {
    return Column(
      children: [
        Container(
          width: 70, // Kích thước to
          height: 70,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: 30),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isMain ? primaryBlue : textDark, // Chữ SSH connect màu xanh nếu cần
          ),
        )
      ],
    );
  }

  // Dòng thông tin System Info
  Widget _buildInfoRow(IconData icon, String label, String value, {bool canCopy = false, bool hasArrow = false}) {
    return InkWell(
      onTap: canCopy ? () => _copyToClipboard(value, label) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD), // Nền xanh rất nhạt
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: primaryBlue, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textGrey, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
                  ),
                ],
              ),
            ),
            if (canCopy) const Icon(Icons.copy, size: 18, color: Color(0xFFCBD5E1)),
            if (hasArrow) const Icon(Icons.chevron_right, size: 20, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  // Dòng Activity
  Widget _buildActivityItem(Color dotColor, String title, String desc, String time) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: textDark)),
                Text(desc, style: const TextStyle(fontSize: 12, color: textGrey)),
              ],
            ),
          ),
          Text(time, style: const TextStyle(fontSize: 12, color: textGrey)),
        ],
      ),
    );
  }

  // Item Bottom Bar (Copy từ Device List)
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
}