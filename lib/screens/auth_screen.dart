import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:texting/config/theme.dart';
import 'package:texting/config/wallpapers.dart';
import 'package:texting/services/auth_service.dart';
import 'package:texting/widgets/stellar_textfield.dart';

import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:texting/screens/web_login_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool isLogin = true;
  bool isLoading = false;

  void _authenticate() async {
    final authService = Provider.of<AuthService>(context, listen: false);

    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (!isLogin && _passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    if (!isLogin && _passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      if (isLogin) {
        await authService.signIn(
          _emailController.text,
          _passwordController.text,
        );
      } else {
        await authService.signUp(
          _emailController.text,
          _passwordController.text,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _authenticateWithGoogle() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    setState(() {
      isLoading = true;
    });
    try {
      await authService.signInWithGoogle();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())), // Often returns null if cancelled, handle gracefully
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const WebLoginScreen();
    }
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: Wallpapers.options[0].colors,
            begin: Wallpapers.options[0].begin,
            end: Wallpapers.options[0].end,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo / Title
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            StellarTheme.primaryGradient.createShader(bounds),
                        child: const Text(
                          "TeX",
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 4,
                          ),
                        ),
                      ).animate().fadeIn(duration: 800.ms).scale(),
                      const SizedBox(height: 8),
                      Text(
                        isLogin ? "Vanakkam da Mappla!!!" : "Create Account",
                        style: const TextStyle(
                          color: StellarTheme.textSecondary,
                          fontSize: 18,
                        ),
                      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 48),

                      // Glass Card
                      GlassmorphicContainer(
                        width: double.infinity,
                        height: isLogin ? 480 : 560, // Increased height for Google button
                        borderRadius: 24,
                        blur: 20,
                        alignment: Alignment.center,
                        border: 2,
                        linearGradient: StellarTheme.glassGradient,
                        borderGradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.5),
                            Colors.white.withOpacity(0.1),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              StellarTextField(
                                controller: _emailController,
                                hintText: "Email",
                                obscureText: false,
                                prefixIcon: Icon(
                                  PhosphorIcons.envelope(),
                                  color: StellarTheme.textSecondary,
                                ),
                                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                              ),
                              const SizedBox(height: 16),
                              StellarTextField(
                                controller: _passwordController,
                                hintText: "Password",
                                obscureText: true,
                                prefixIcon: Icon(
                                  PhosphorIcons.lock(),
                                  color: StellarTheme.textSecondary,
                                ),
                                onFieldSubmitted: (_) {
                                  if (isLogin) {
                                    _authenticate();
                                  } else {
                                    FocusScope.of(context).nextFocus();
                                  }
                                },
                              ),
                              if (!isLogin) ...[
                                const SizedBox(height: 16),
                                StellarTextField(
                                  controller: _confirmPasswordController,
                                  hintText: "Confirm Password",
                                  obscureText: true,
                                  prefixIcon: Icon(
                                    PhosphorIcons.checkCircle(),
                                    color: StellarTheme.textSecondary,
                                  ),
                                  onFieldSubmitted: (_) => _authenticate(),
                                ),
                              ],
                              const SizedBox(height: 32),
                              isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                        color: StellarTheme.primaryNeon,
                                      ),
                                    )
                                  : Column(
                                      children: [
                                        ElevatedButton(
                                          onPressed: _authenticate,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            padding: EdgeInsets.zero,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: Ink(
                                            decoration: BoxDecoration(
                                              gradient:
                                                  StellarTheme.primaryGradient,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Container(
                                              alignment: Alignment.center,
                                              constraints: const BoxConstraints(
                                                minHeight: 56,
                                                minWidth: double.infinity,
                                              ),
                                              child: Text(
                                                isLogin
                                                    ? "Sign In"
                                                    : "Create Account",
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          "OR",
                                          style: TextStyle(
                                              color: StellarTheme.textSecondary),
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton(
                                          onPressed: _authenticateWithGoogle,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: Colors.black,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            minimumSize:
                                                const Size(double.infinity, 56),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(PhosphorIcons.googleLogo()),
                                              SizedBox(width: 12),
                                              Text(
                                                "Continue with Google",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0),
                      const SizedBox(height: 24),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            isLogin
                                ? "New here? "
                                : "Already have an account? ",
                            style: const TextStyle(
                              color: StellarTheme.textSecondary,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                isLogin = !isLogin;
                              });
                            },
                            child: Text(
                              isLogin ? "Sign Up" : "Log In",
                              style: const TextStyle(
                                color: StellarTheme.primaryNeon,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 700.ms),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
