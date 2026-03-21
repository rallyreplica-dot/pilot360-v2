import 'package:flutter/material.dart';

class Pilot360Logo extends StatelessWidget {
  final double width;
  final double height;
  const Pilot360Logo({super.key, this.width = 200, this.height = 80});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/pilot360_final_icon.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
    );
  }
}
