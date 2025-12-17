import 'dart:ui';
import 'package:flutter/material.dart';
import 'qr_scanner_screen.dart';
import 'device_list.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // --- Logic gốc (Giữ nguyên) ---
  bool _isPasswordVisible = false;
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // --- CẤU HÌNH MÀU SẮC CỐ ĐỊNH (LIGHT MODE) ---
    const primaryColor = Color(0xFF1E40AF); // Blue 800
    const backgroundColor = Color(0xFFF8FAFC); // Slate 50 (Nền sáng)
    const textColor = Color(0xFF0F172A); // Slate 900 (Chữ đen)
    const subTextColor = Color(0xFF64748B); // Slate 500 (Chữ xám)

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // --- Hiệu ứng nền (Background Blobs) ---
          Positioned(
            top: -50,
            right: -50,
            child: _buildBlurBlob(
              color: primaryColor.withOpacity(0.1),
              size: 200,
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: _buildBlurBlob(
              color: Colors.blue.shade200.withOpacity(0.3),
              size: 150,
            ),
          ),

          // --- Nội dung chính ---
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo Container
                  Container(
                    width: 96,
                    height: 96,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE2E8F0), // Slate 200
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.hub,
                        size: 48,
                        color: primaryColor,
                      ),
                    ),
                  ),

                  // Tiêu đề
                  const Text(
                    "Xin chào!",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Quản lý hệ thống mạng của bạn mọi lúc.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: subTextColor,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Input: Tài khoản
                  _buildInputField(
                    controller: _userController,
                    hintText: "Tên đăng nhập / Email",
                    icon: Icons.person_outline,
                  ),

                  const SizedBox(height: 20),

                  // Input: Mật khẩu
                  _buildInputField(
                    controller: _passController,
                    hintText: "Mật khẩu",
                    icon: _isPasswordVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    isPassword: true,
                    isVisible: _isPasswordVisible,
                    onIconTap: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),



                  const SizedBox(height: 16),

                  // Nút Đăng nhập
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        // --- Logic chuyển trang gốc ---
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (context) => const DeviceListScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Đăng nhập",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),


                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Widget con: Input Field (Luôn nền trắng) ---
  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onIconTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // Luôn trắng
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: const Color(0xFFE2E8F0), // Slate 200
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !isVisible,
        style: const TextStyle(
          color: Color(0xFF0F172A), // Slate 900
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8), // Slate 400
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          suffixIcon: GestureDetector(
            onTap: onIconTap,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Icon(
                icon,
                color: const Color(0xFF94A3B8), // Slate 400
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Widget con: Blur Blob Background
  Widget _buildBlurBlob({required Color color, required double size}) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
      child: Container(
        width: size * 2,
        height: size * 2,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}