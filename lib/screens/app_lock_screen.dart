import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:texting/services/app_lock_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AppLockScreen extends StatefulWidget {
  final bool isSetup;
  final VoidCallback? onSuccess;
  final VoidCallback? onCancel;

  const AppLockScreen({
    super.key,
    this.isSetup = false,
    this.onSuccess,
    this.onCancel,
  });

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String _message = 'Enter PIN';
  
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    if (widget.isSetup) {
      _message = 'Set a new 4-digit PIN';
    } else {
      _message = 'Enter PIN to Unlock';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Safe check for mounted
        if (!mounted) return;
        final service = Provider.of<AppLockService>(context, listen: false);
        if (service.isBiometricEnabled) {
          _triggerBiometrics();
        }
      });
    }
  }
  
  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _triggerBiometrics() async {
    final service = Provider.of<AppLockService>(context, listen: false);
    bool authenticated = await service.authenticateWithBiometrics();
    if (authenticated && mounted) {
       widget.onSuccess?.call();
    }
  }

  void _onDigitPress(String digit) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
      });
      HapticFeedback.lightImpact();
      
      if (_enteredPin.length == 4) {
        // Small delay to show the last dot filled
        Future.delayed(const Duration(milliseconds: 100), _handlePinComplete);
      }
    }
  }

  void _onDeletePress() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
      HapticFeedback.lightImpact();
    }
  }

  void _handlePinComplete() async {
    final service = Provider.of<AppLockService>(context, listen: false);

    if (widget.isSetup) {
      if (!_isConfirming) {
         setState(() {
           _confirmPin = _enteredPin;
           _enteredPin = '';
           _isConfirming = true;
           _message = 'Confirm your PIN';
         });
      } else {
        if (_enteredPin == _confirmPin) {
          await service.setPin(_enteredPin);
          if (mounted) {
            if (widget.onSuccess != null) {
              widget.onSuccess!();
            } else {
              Navigator.pop(context);
            }
          }
        } else {
           _triggerShake('PINs do not match. Try again.');
           setState(() {
             _enteredPin = '';
             _confirmPin = '';
             _isConfirming = false;
           });
        }
      }
    } else {
      bool isValid = await service.validatePin(_enteredPin);
      if (isValid) {
        service.unlockApp();
        if (mounted) widget.onSuccess?.call();
      } else {
        _triggerShake('Incorrect PIN');
        setState(() {
          _enteredPin = '';
        });
      }
    }
  }
  
  void _triggerShake(String errorMsg) {
    _shakeController.forward(from: 0.0);
    setState(() {
      _message = errorMsg;
    });
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
            setState(() {
                 _message = widget.isSetup 
                    ? (_isConfirming ? 'Confirm your PIN' : 'Set a new 4-digit PIN')
                    : 'Enter PIN to Unlock';
            });
        }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
             // Top Bar
             SizedBox(
               height: 60,
               child: Stack(
                 children: [
                   if (widget.onCancel != null && widget.isSetup)
                      Positioned(
                        left: 10,
                        top: 0,
                        bottom: 0,
                        child: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: widget.onCancel,
                        ),
                      ),
                 ],
               ),
             ),
                
            const Spacer(flex: 1),
            
            // Icon
            Icon(Icons.lock_outline_rounded, size: 50, color: color)
                .animate()
                .fadeIn(duration: 600.ms)
                .scale(),
                
            const SizedBox(height: 20),
            
            // Message
            AnimatedBuilder(
              animation: _shakeController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value * 3 * ( _shakeController.value < 0.25 || (_shakeController.value > 0.5 && _shakeController.value < 0.75) ? -1 : 1), 0),
                  child: Text(
                    _message,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: _message.contains('Incorrect') || _message.contains('not match') 
                          ? Colors.red 
                          : textColor,
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 30),
            
            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                bool filled = index < _enteredPin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? color : Colors.transparent,
                    border: Border.all(
                        color: filled ? color : (isDark ? Colors.white54 : Colors.black54),
                        width: 1.5,
                    ),
                  ),
                );
              }),
            ),
            
            const Spacer(flex: 1),
            
            // Numpad
            Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                children: [
                  _buildRow('1', '2', '3'),
                  const SizedBox(height: 20),
                  _buildRow('4', '5', '6'),
                  const SizedBox(height: 20),
                  _buildRow('7', '8', '9'),
                  const SizedBox(height: 20),
                  _buildRow('biometric', '0', 'backspace'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRow(String v1, String v2, String v3) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildKey(v1),
        _buildKey(v2),
        _buildKey(v3),
      ],
    );
  }
  
  Widget _buildKey(String value) {
    // Biometric Button
    if (value == 'biometric') {
      if (widget.isSetup) return const SizedBox(width: 80, height: 80);
      
      return Consumer<AppLockService>(
        builder: (context, service, _) {
          // If biometric not enabled or not available (checked in service init, effectively), 
          // we might want to hide. 
          // But 'isBiometricEnabled' is the user preference. 
          // We can also check 'service.canCheckBiometrics' if we exposed it, 
          // but for now relying on user preference.
          if (!service.isBiometricEnabled) return const SizedBox(width: 80, height: 80);
          
          return InkWell(
            onTap: _triggerBiometrics,
            borderRadius: BorderRadius.circular(40),
            child: SizedBox(
              width: 80, 
              height: 80,
              child: Icon(Icons.fingerprint, size: 36, color: Theme.of(context).primaryColor),
            ),
          );
        },
      );
    }
    
    // Backspace
    if (value == 'backspace') {
      return InkWell(
        onTap: _onDeletePress,
        borderRadius: BorderRadius.circular(40),
        child: SizedBox(
          width: 80, 
          height: 80,
          child: Icon(Icons.backspace_outlined, size: 28, color: Theme.of(context).iconTheme.color),
        ),
      );
    }
    
    // Digits
    return InkWell(
      onTap: () => _onDigitPress(value),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Subtle background for keys
          color: Theme.of(context).brightness == Brightness.dark 
              ? Colors.white.withOpacity(0.05) 
              : Colors.black.withOpacity(0.03),
        ),
        child: Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w400,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ),
    );
  }
}
