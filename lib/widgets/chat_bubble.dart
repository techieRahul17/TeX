import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:texting/config/theme.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isSender;
  final Color? color;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isSender,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        gradient: isSender
            ? LinearGradient(
                colors: [
                  color ?? StellarTheme.primaryNeon, 
                  (color ?? StellarTheme.primaryNeon).withOpacity(0.7)
                ],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              )
            : LinearGradient(
                colors: [
                  Colors.grey.shade900,
                  Colors.black,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: isSender ? const Radius.circular(16) : Radius.zero,
          bottomRight: isSender ? Radius.zero : const Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: isSender
                ? (color ?? StellarTheme.primaryNeon).withOpacity(0.3)
                : Colors.white.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(
          color: isSender ? Colors.transparent : Colors.white.withOpacity(0.1),
          width: 0.5,
        ),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
    ).animate().fade(duration: 300.ms).slideX(
          begin: isSender ? 1 : -1,
          end: 0,
          curve: Curves.easeOutCubic,
        );
  }
}