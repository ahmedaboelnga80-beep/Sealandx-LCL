import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'folder_list_screen.dart';

class AccountWrapper extends StatefulWidget {
  const AccountWrapper({super.key});

  @override
  State<AccountWrapper> createState() => _AccountWrapperState();
}

class _AccountWrapperState extends State<AccountWrapper> {
  bool _isLoggedIn = false;
  bool _isLoading = true;
  final TextEditingController _emailController = TextEditingController();

  // The Google Apps Script URL linked to your users list sheet
  final String _usersListUrl =
      'https://script.google.com/macros/s/AKfycbyVEY6juS8HsEI5OXWusKFZjnUJvWIwUv19ZY4WMc9XBlvWNnoGS6j_V_v7zZKdExaXzg/exec';

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Check SharedPreferences first (Works for Web & Mobile)
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('is_logged_in') == true) {
        setState(() {
          _isLoggedIn = true;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}

    if (kIsWeb) {
      setState(() => _isLoading = false);
      return;
    }

    // Legacy File check (for compatibility / offline session)
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final loginFile = File(path.join(appDir.path, '.user_session_lcl'));

      if (await loginFile.exists()) {
        final sessionData = await loginFile.readAsString();
        final email = sessionData.trim();
        final result = await _verifyUserRemotely(email, checkOnly: true);
        if (result['status']?.toLowerCase() == "success") {
          if (mounted) {
            setState(() {
              _isLoggedIn = true;
            });
            // Cache in SharedPreferences
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('is_logged_in', true);
            await prefs.setString('inspector_name', result['name'] ?? email);
          }
        }
      }
    } catch (e) {
      debugPrint('Login check error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>> _verifyUserRemotely(
    String email, {
    bool checkOnly = false,
  }) async {
    // Local overrides for testing/emergency bypass (identical to main app)
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail == 'mohamedashraf') {
      return {'status': 'success', 'name': 'Mohamed Ashraf'};
    }
    if (cleanEmail == 'ahmed') {
      return {'status': 'success', 'name': 'Ahmed'};
    }
    
    try {
      final baseUri = Uri.parse(_usersListUrl);
      final uri = baseUri.replace(queryParameters: {
        ...baseUri.queryParameters,
        'email': email.trim(),
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } catch (je) {
          return {
            'status': 'fail',
            'debug_error': 'JSON decode error: $je. Response body: ${response.body}'
          };
        }
      } else {
        return {
          'status': 'fail',
          'debug_error': 'Server returned HTTP status code: ${response.statusCode}. Response: ${response.body}'
        };
      }
    } catch (e) {
      if (checkOnly) {
        // Bypass for offline if session file existed
        return {'status': 'success'};
      }
      return {
        'status': 'fail',
        'debug_error': 'Exception/Network Error: $e'
      };
    }
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('برجاء إدخال اسم المستخدم أو الكود', style: TextStyle(fontFamily: 'Cairo')),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final response = await _verifyUserRemotely(email);
    final status = response['status'] ?? 'fail';
    final realName = response['name'] ?? email;

    Future<void> saveLoginSession(String email, String name) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('inspector_name', name);

        if (!kIsWeb) {
          final appDir = await getApplicationDocumentsDirectory();
          final loginFile = File(path.join(appDir.path, '.user_session_lcl'));
          await loginFile.writeAsString(email);
        }
      } catch (e) {
        debugPrint('Save session error: $e');
      }
    }

    if (status == 'success') {
      await saveLoginSession(email, realName);

      setState(() {
        _isLoggedIn = true;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      String message = 'بيانات الدخول غير صحيحة';
      if (status == 'added') {
        message = 'تم إرسال طلب الدخول للمدير، برجاء الانتظار للموافقة';
      } else if (status == 'blocked') {
        message = 'حسابك معطل حالياً، برجاء مراجعة المدير';
      }

      final debugError = response['debug_error'];

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF004D40),
              title: const Text(
                'خطأ في تسجيل الدخول',
                textAlign: TextAlign.right,
                style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      message,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontFamily: 'Cairo', color: Colors.white70),
                    ),
                    if (debugError != null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Debug Information:',
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        debugError.toString(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('حسناً', style: TextStyle(fontFamily: 'Cairo', color: Colors.tealAccent)),
                ),
              ],
            );
          },
        );
      }
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_logged_in');
      await prefs.remove('inspector_name');
    } catch (_) {}

    if (!kIsWeb) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final loginFile = File(path.join(appDir.path, '.user_session_lcl'));
        if (await loginFile.exists()) {
          await loginFile.delete();
        }
      } catch (e) {
        debugPrint('Logout error: $e');
      }
    }

    setState(() {
      _isLoggedIn = false;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF001e18),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF009688)),
        ),
      );
    }

    if (_isLoggedIn) {
      return FolderListScreen(onLogout: _logout);
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF001e18), Color(0xFF004D40)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              color: const Color(0xFF00382E),
              elevation: 12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 40,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.account_circle,
                      size: 80,
                      color: Color(0xFF009688),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'تسجيل دخول المفتشين',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'SealandX LCL Photo Scanner',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        labelText: 'اسم المستخدم / الكود',
                        labelStyle: const TextStyle(fontFamily: 'Cairo', color: Colors.white70),
                        prefixIcon: const Icon(Icons.person_outline, color: Colors.white70),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF009688),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'دخول النظام',
                          style: TextStyle(fontSize: 18, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'SealandX Cloud Security v2.0',
                      style: TextStyle(color: Colors.white30, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
