import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'customer_signup_screen.dart';
import 'package:flutter/gestures.dart';
import 'dart:math';
import 'customer_forgot_password_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:menufood/welcome/choice_screen.dart';

class CustomerLoginScreen extends StatefulWidget {
  const CustomerLoginScreen({super.key});

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isVerifyingEmail = false;

  late AnimationController _swayAnimationController;
  late AnimationController _entryAnimationController;

  final List<String> _overlappingImages = [
    'assets/images/30-mon-ngon-nuc-long-nhat-dinh-phai-thu-khi-toi-ha-noi-phan-1.webp',
    'assets/images/bao-gia-chup-mon-an-dich-vu-chup-anh-do-an-chuyen-nghiep-4.jpg',
    'assets/images/comtam.jpg',
  ];

  final List<Map<String, dynamic>> _staticImageProps = [
    {'offset': const Offset(-80, 40), 'rotation': 0.15, 'scale': 0.8},
    {'offset': const Offset(80, -40), 'rotation': -0.1, 'scale': 0.9},
    {'offset': const Offset(0, 0), 'rotation': 0.05, 'scale': 1.0},
  ];

  @override
  void initState() {
    super.initState();
    _swayAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _swayAnimationController.repeat(reverse: true);

    _entryAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );
    _entryAnimationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _swayAnimationController.dispose();
    _entryAnimationController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isVerifyingEmail = false;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ChoiceScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = 'Không tìm thấy tài khoản với email này. Vui lòng đăng ký.';
      } else if (e.code == 'wrong-password') {
        message = 'Mật khẩu không đúng.';
      } else if (e.code == 'invalid-email') {
        message = 'Địa chỉ email không hợp lệ.';
      } else {
        message = 'Lỗi đăng nhập: ${e.message}';
      }
      setState(() {
        _errorMessage = message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Đã xảy ra lỗi không xác định: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();

      try {
        await googleSignIn.disconnect();
      } catch (e) {
      }

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ChoiceScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'account-exists-with-different-credential') {
        message = 'Tài khoản đã tồn tại với một phương thức đăng nhập khác.';
      } else if (e.code == 'invalid-credential') {
        message = 'Thông tin xác thực không hợp lệ từ Google.';
      } else {
        message = 'Lỗi đăng nhập Google: ${e.message}';
      }
      setState(() {
        _errorMessage = message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Đã xảy ra lỗi không xác định khi đăng nhập Google: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithFacebook() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tích hợp Facebook sẽ được triển khai.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 300,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: List.generate(_overlappingImages.length, (index) {
                    final props = _staticImageProps[index % _staticImageProps.length];

                    return AnimatedBuilder(
                      animation: Listenable.merge([_entryAnimationController, _swayAnimationController]),
                      builder: (context, child) {
                        final double startInterval = index * (1.0 / _overlappingImages.length);
                        final double endInterval = startInterval + (1.0 / _overlappingImages.length);
                        final CurvedAnimation staggeredAnimation = CurvedAnimation(
                          parent: _entryAnimationController,
                          curve: Interval(startInterval, endInterval, curve: Curves.easeOutCubic),
                        );

                        final double initialSlideOffset = (1.0 - staggeredAnimation.value) * 300;
                        final double opacity = staggeredAnimation.value;

                        double animValue = _swayAnimationController.value;
                        double phase = index * (pi / _overlappingImages.length);

                        double swayX = sin(animValue * 2 * pi + phase) * 15;
                        double swayY = cos(animValue * 2 * pi + phase * 0.5) * 10;
                        double swayRotation = sin(animValue * 2 * pi / 2 + phase * 0.7) * 0.05;
                        double swayScale = 1 + sin(animValue * 2 * pi / 3 + phase * 0.9) * 0.01;

                        return Positioned(
                          left: (MediaQuery.of(context).size.width * 0.5) - 100 + props['offset'].dx + swayX,
                          top: (300 / 2) - 100 + props['offset'].dy + swayY + initialSlideOffset,
                          child: Opacity(
                            opacity: opacity,
                            child: Transform.rotate(
                              angle: props['rotation'] + swayRotation,
                              child: Transform.scale(
                                scale: props['scale'] * swayScale,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(15.0),
                                  child: Image.asset(
                                    _overlappingImages[index],
                                    fit: BoxFit.cover,
                                    width: 200,
                                    height: 200,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey,
                                        width: 200,
                                        height: 200,
                                        child: const Center(
                                          child: Icon(Icons.broken_image, color: Colors.white, size: 50),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Hạnh phúc khi được ăn',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Địa chỉ email',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Mật khẩu',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const CustomerForgotPasswordScreen()),
                    );
                  },
                  child: Text(
                    'Quên mật khẩu?',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _isLoading
                  ? const CircularProgressIndicator(color: Colors.deepOrange)
                  : ElevatedButton(
                onPressed: _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  textStyle: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Đăng nhập'),
              ),
              const SizedBox(height: 20),

              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const CustomerSignupScreen()),
                  );
                },
                child: Text(
                  'Tạo tài khoản mới',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  const Expanded(child: Divider(color: Colors.grey)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('HOẶC', style: GoogleFonts.poppins(color: Colors.grey)),
                  ),
                  const Expanded(child: Divider(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: _isLoading ? null : _signInWithFacebook,
                icon: Image.asset(
                  'assets/images/icons8-facebook-logo-96.png',
                  height: 24,
                  width: 24,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.facebook, color: Colors.blue, size: 28);
                  },
                ),
                label: Text(
                  'Tiếp tục với Facebook',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 15),

              ElevatedButton.icon(
                onPressed: _isLoading ? null : _signInWithGoogle,
                icon: Image.asset(
                  'assets/images/icons8-google-logo-96.png',
                  height: 24,
                  width: 24,
                  errorBuilder: (context, url, error) {
                    return const Icon(Icons.g_mobiledata, color: Colors.blue, size: 28);
                  },
                ),
                label: Text(
                  'Tiếp tục với Google',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 30),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Text.rich(
                  TextSpan(
                    text: 'Bằng cách tiếp tục, bạn đồng ý với ',
                    style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12),
                    children: <TextSpan>[
                      TextSpan(
                        text: 'Điều khoản Dịch vụ',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                          },
                      ),
                      TextSpan(
                        text: ' của Quán và xác nhận rằng bạn đã đọc ',
                        style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12),
                      ),
                      TextSpan(
                        text: 'Chính sách quyền riêng tư',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                          },
                      ),
                      TextSpan(
                        text: ' của chúng tôi. ',
                        style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12),
                      ),
                      TextSpan(
                        text: 'Thông báo bộ sưu tập.',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                          },
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}