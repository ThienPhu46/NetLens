import 'dart:ui';
import 'package:flutter/material.dart';
import 'qr_scanner_screen.dart'; // Import để nút Scan hoạt động

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  // --- COLOR PALETTE (Từ HTML mới) ---
  static const Color headerBlue = Color(0xFF002060); // Darkblue header
  static const Color primaryBlue = Color(0xFF1E3A8A); // Primary
  static const Color bgLight = Color(0xFFF8FAFC); // Background Slate-50
  static const Color textDark = Color(0xFF0F172A); // Slate-900
  static const Color textGrey = Color(0xFF64748B); // Slate-500
  static const Color borderCol = Color(0xFFE2E8F0); // Slate-200

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  String? _selectedType;
  bool _isMonitoring = false;
  bool _isNotification = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      // Custom AppBar để giống HTML (Dark blue header)
      appBar: AppBar(
        backgroundColor: headerBlue,
        elevation: 4,
        leadingWidth: 80,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Hủy", style: TextStyle(color: Colors.white70, fontSize: 14)),
        ),
        centerTitle: true,
        title: const Text(
          "Thêm thiết bị",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: () {
                // Xử lý lưu
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              child: const Text("Lưu", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          // 1. FORM CONTENT
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120), // Padding cho BottomBar
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section 1: Thông tin cơ bản
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Thông tin cơ bản",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: headerBlue),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Nhập các thông tin nhận dạng thiết bị.",
                        style: TextStyle(fontSize: 14, color: textGrey),
                      ),
                    ],
                  ),
                ),

                // Fields
                _buildInputLabel("Tên thiết bị"),
                _buildTextField(
                  controller: _nameController,
                  hint: "Ví dụ: Router Tầng 1",
                  icon: Icons.router,
                ),

                _buildInputLabel("Địa chỉ IP"),
                _buildTextField(
                  controller: _ipController,
                  hint: "192.168.1.1",
                  icon: Icons.hub, // Icon hub thay cho material symbol
                  inputType: TextInputType.number,
                ),

                _buildInputLabel("Loại thiết bị"),
                _buildDropdown(),

                const SizedBox(height: 16),
                
                // Divider dashed line giả lập
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(color: borderCol, thickness: 1, height: 32),
                ),

                // Section 2: Cấu hình
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "Cấu hình & Trạng thái",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: headerBlue),
                  ),
                ),
                const SizedBox(height: 12),

                _buildInputLabel("Mô tả / Ghi chú"),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderCol),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 2, offset: const Offset(0, 1)),
                      ],
                    ),
                    child: TextField(
                      controller: _descController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: "Nhập ghi chú về vị trí lắp đặt hoặc chức năng...",
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Toggles
                _buildToggleCard(
                  icon: Icons.show_chart, // monitoring
                  iconBg: Colors.blue.shade50,
                  iconColor: headerBlue,
                  title: "Theo dõi hoạt động",
                  subtitle: "Ghi lại log và uptime",
                  value: _isMonitoring,
                  onChanged: (val) => setState(() => _isMonitoring = val),
                ),
                
                const SizedBox(height: 12),

                _buildToggleCard(
                  icon: Icons.notifications_active,
                  iconBg: Colors.red.shade50,
                  iconColor: Colors.red.shade700,
                  title: "Thông báo lỗi",
                  subtitle: "Báo động khi mất kết nối",
                  value: _isNotification,
                  onChanged: (val) => setState(() => _isNotification = val),
                ),
              ],
            ),
          ),

          // 2. BOTTOM NAVIGATION BAR (Giữ nguyên style của device_list)
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
                  // Tab Thiết bị (Vẫn active)
                  _buildNavItem(Icons.devices, "Thiết bị", isActive: true),
                  
                  // Nút giữa (Quét thiết bị)
                  GestureDetector(
                    onTap: () {
                       Navigator.of(context).push(
                         MaterialPageRoute(builder: (context) => const QrScannerScreen()),
                       );
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: headerBlue, // Dùng màu header cho đồng bộ màn này
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: headerBlue.withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 26),
                        ),
                        const Text(
                          "Quét thiết bị",
                          style: TextStyle(
                            fontSize: 10, 
                            fontWeight: FontWeight.bold, 
                            color: textGrey
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

  // --- WIDGET HELPERS ---

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8, top: 12),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14, 
          fontWeight: FontWeight.w600, 
          color: Color(0xFF334155) // Slate-700
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderCol),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 2, offset: const Offset(0, 1)),
          ],
        ),
        child: TextField(
          controller: controller,
          keyboardType: inputType,
          style: const TextStyle(fontSize: 16, color: textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 15),
            prefixIcon: Icon(icon, color: Colors.grey.shade400),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderCol),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 2, offset: const Offset(0, 1)),
          ],
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedType,
            hint: const Text("Chọn loại thiết bị", style: TextStyle(color: textDark)),
            icon: const Icon(Icons.expand_more, color: textGrey),
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: "router", child: Text("Router")),
              DropdownMenuItem(value: "switch", child: Text("Switch")),
              DropdownMenuItem(value: "access_point", child: Text("Access Point")),
              DropdownMenuItem(value: "server", child: Text("Server")),
              DropdownMenuItem(value: "camera", child: Text("Camera IP")),
            ],
            onChanged: (val) => setState(() => _selectedType = val),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderCol),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 2, offset: const Offset(0, 1)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textDark)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: textGrey)),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              activeColor: headerBlue,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, {required bool isActive}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: isActive ? headerBlue : Colors.grey.shade400,
          size: 28,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: isActive ? headerBlue : Colors.grey.shade400,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        )
      ],
    );
  }
}