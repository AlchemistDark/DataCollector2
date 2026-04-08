import 'package:flutter/material.dart';

/// A button that provides visual feedback through icon and shadow color changes when clicked.
/// 
/// Unlike standard buttons, this uses a [Listener] to provide immediate 
/// reactive feedback for the "isPressed" state without relying solely on the [onPressed] callback.
class AnimatedButton extends StatefulWidget {
  /// The icon displayed in the center of the button.
  final Icon icon;
  
  /// The callback function executed when the button is released.
  final Function onPressed;

  /// Creates an [AnimatedButton] with the specific [icon] and [onPressed] event.
  const AnimatedButton({
    required this.icon,
    required this.onPressed,
    super.key,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton> {
  /// Internal state tracking whether the user is currently holding the button down.
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF52B69A); // A soft teal/green
    const Color feedbackColor = Colors.blueAccent;

    return Listener(
      onPointerDown: (_) {
        setState(() {
          isPressed = true;
        });
      },
      onPointerUp: (_) {
        setState(() {
          isPressed = false;
        });
        widget.onPressed();
      },
      child: Container(
        height: 34,
        width: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          color: primaryColor,
          boxShadow: [
            BoxShadow(
              color: isPressed ? feedbackColor : primaryColor,
              blurRadius: isPressed ? 5 : 0,
              spreadRadius: 0,
            )
          ],
        ),
        child: widget.icon,
      ),
    );
  }
}
