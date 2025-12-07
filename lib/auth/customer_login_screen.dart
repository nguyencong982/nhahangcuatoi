import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'customer_signup_screen.dart';
import 'package:flutter/gestures.dart';
import 'dart:math';
import 'customer_forgot_password_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:menufood/welcome/choice_screen.dart';
import 'package:menufood/home/shipper_home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:menufood/home/customer_home_screen.dart';
import 'package:menufood/admin/admin_dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

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

  List<String> _previousEmails = [];
  static const String _emailKey = 'previousCustomerEmails';

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
    _loadPreviousEmails();

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

  Future<void> _loadPreviousEmails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _previousEmails = prefs.getStringList(_emailKey) ?? [];
        if (_previousEmails.isNotEmpty) {
          _emailController.text = _previousEmails.first;
        }
      });
    } catch (e) {
      print('Lỗi khi tải email đã lưu: $e');
    }
  }

  Future<void> _saveEmail(String email) async {
    if (email.isEmpty) return;

    final normalizedEmail = email.trim().toLowerCase();

    _previousEmails.remove(normalizedEmail);

    _previousEmails.insert(0, normalizedEmail);

    if (_previousEmails.length > 5) {
      _previousEmails = _previousEmails.sublist(0, 5);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_emailKey, _previousEmails);
    } catch (e) {
      print('Lỗi khi lưu email mới: $e');
    }
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
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;
      if (user != null) {
        await _saveEmail(_emailController.text);

        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (userDoc.exists && userDoc.data() is Map<String, dynamic>) {
          final userData = userDoc.data() as Map<String, dynamic>;
          String role = userData['role'] ?? 'customer';
          bool isDeleted = userData['isDeleted'] ?? false;

          if (isDeleted) {
            await FirebaseAuth.instance.signOut();
            throw FirebaseAuthException(
              code: 'account-disabled',
              message: 'Tài khoản này đã bị vô hiệu hóa. Vui lòng liên hệ quản trị viên.',
            );
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userRole', role);

          if (mounted) {
            if (role == 'admin' || role == 'superAdmin' || role == 'manager') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
              );
            }
            else if (role == 'shipper') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const ShipperHomeScreen()),
              );
            }
            else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const ChoiceScreen()),
              );
            }
          }
        } else {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            print('Không tìm thấy document hồ sơ (role) cho UID: ${user.uid}.');
            setState(() {
              _errorMessage = 'Thông tin người dùng không hợp lệ. (Thiếu hồ sơ vai trò)';
            });
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        message = 'Email hoặc mật khẩu không đúng.';
      } else if (e.code == 'invalid-email') {
        message = 'Địa chỉ email không hợp lệ.';
      } else if (e.code == 'account-disabled') {
        message = e.message!;
      }
      else {
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

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      User? user = userCredential.user;
      if (user != null) {
        if (user.email != null) {
          await _saveEmail(user.email!);
        }

        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (userDoc.exists && userDoc.data() is Map<String, dynamic>) {
          final userData = userDoc.data() as Map<String, dynamic>;
          String role = userData['role'] ?? 'customer';
          bool isDeleted = userData['isDeleted'] ?? false;

          if (isDeleted) {
            await FirebaseAuth.instance.signOut();
            throw FirebaseAuthException(
              code: 'account-disabled',
              message: 'Tài khoản này đã bị vô hiệu hóa. Vui lòng liên hệ quản trị viên.',
            );
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userRole', role);

          if (mounted) {
            if (role == 'admin' || role == 'superAdmin' || role == 'manager') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
              );
            }
            else if (role == 'shipper') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const ShipperHomeScreen()),
              );
            }
            else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const ChoiceScreen()),
              );
            }
          }
        } else {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'email': user.email,
            'name': user.displayName ?? 'Người dùng mới',
            'role': 'customer',
            'isDeleted': false,
          });

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userRole', 'customer');

          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const ChoiceScreen()),
            );
          }
        }
      }

    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'account-exists-with-different-credential') {
        message = 'Tài khoản đã tồn tại với một phương thức đăng nhập khác.';
      } else if (e.code == 'invalid-credential') {
        message = 'Thông tin xác thực không hợp lệ từ Google.';
      } else if (e.code == 'account-disabled') {
        message = e.message!;
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;

        final AuthCredential credential = FacebookAuthProvider.credential(
          accessToken.token,
        );

        UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

        User? user = userCredential.user;
        if (user != null) {
          if (user.email != null) {
            await _saveEmail(user.email!);
          }

          DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

          if (userDoc.exists && userDoc.data() is Map<String, dynamic>) {
            final userData = userDoc.data() as Map<String, dynamic>;
            String role = userData['role'] ?? 'customer';
            bool isDeleted = userData['isDeleted'] ?? false;

            if (isDeleted) {
              await FirebaseAuth.instance.signOut();
              throw FirebaseAuthException(
                code: 'account-disabled',
                message: 'Tài khoản này đã bị vô hiệu hóa. Vui lòng liên hệ quản trị viên.',
              );
            }

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('userRole', role);

            if (mounted) {
              if (role == 'admin' || role == 'superAdmin' || role == 'manager') {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
                );
              }
              else if (role == 'shipper') {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const ShipperHomeScreen()),
                );
              }
              else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const ChoiceScreen()),
                );
              }
            }
          } else {
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'email': user.email,
              'name': user.displayName ?? 'Người dùng Facebook',
              'role': 'customer',
              'isDeleted': false,
            });

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('userRole', 'customer');

            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const ChoiceScreen()),
              );
            }
          }
        }
      } else if (result.status == LoginStatus.cancelled) {
        setState(() {
          _errorMessage = 'Đăng nhập Facebook bị hủy.';
        });
      } else if (result.status == LoginStatus.failed) {
        throw Exception(result.message ?? "Lỗi đăng nhập Facebook không xác định.");
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'account-exists-with-different-credential') {
        message = 'Tài khoản đã tồn tại với một phương thức đăng nhập khác.';
      } else if (e.code == 'invalid-credential') {
        message = 'Thông tin xác thực không hợp lệ từ Facebook.';
      } else if (e.code == 'account-disabled') {
        message = e.message!;
      } else {
        message = 'Lỗi đăng nhập Facebook: ${e.message}';
      }
      setState(() {
        _errorMessage = message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Đã xảy ra lỗi không xác định khi đăng nhập Facebook: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            if (mounted) {
              SystemNavigator.pop();
            }
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

                        double imageSize = 200;
                        double centerX = (screenWidth / 2) - (imageSize / 2);

                        return Positioned(
                          left: centerX + props['offset'].dx + swayX,
                          top: (300 / 2) - (imageSize / 2) + props['offset'].dy + swayY + initialSlideOffset,
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
                                    width: imageSize,
                                    height: imageSize,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey,
                                        width: imageSize,
                                        height: imageSize,
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

              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return _previousEmails;
                  }
                  return _previousEmails.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (String selection) {
                  _emailController.text = selection;
                },
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  if (_emailController.text.isNotEmpty && textEditingController.text.isEmpty) {
                    textEditingController.text = _emailController.text;
                  }

                  if (textEditingController.text.isNotEmpty) {
                    textEditingController.selection = TextSelection.fromPosition(
                      TextPosition(offset: textEditingController.text.length),
                    );
                  }

                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
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
                        borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (text) {
                      _emailController.text = text;
                    },
                    onSubmitted: (_) => onFieldSubmitted(),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 8.0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      color: Colors.grey[850],
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: 200, maxWidth: screenWidth - 48),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final String option = options.elementAt(index);
                            return InkWell(
                              onTap: () => onSelected(option),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  option,
                                  style: GoogleFonts.poppins(color: Colors.white70),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
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
                    borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
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