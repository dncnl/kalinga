import 'package:flutter/material.dart';

/// Shared back affordance for screens reached via `context.push(...)` that
/// don't otherwise have one (no AppBar, no bottom nav). `maybePop()` is a
/// safe no-op if there's nothing to pop back to.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Go back',
      button: true,
      child: Tooltip(
        message: 'Go back',
        child: SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            color: Colors.black87,
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.grey.shade300),
              shape: const CircleBorder(),
            ),
          ),
        ),
      ),
    );
  }
}
