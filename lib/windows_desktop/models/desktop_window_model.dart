import 'package:flutter/material.dart';

class DesktopWindowModel {
  final String id;
  final String title;
  final IconData icon;
  final Widget content;
  Offset position;
  Size size;
  Size previousSize;
  Offset previousPosition;
  bool isMinimized;
  bool isMaximized;
  int zIndex;
  final bool isAlwaysOnTop;

  DesktopWindowModel({
    required this.id,
    required this.title,
    required this.icon,
    required this.content,
    required this.position,
    required this.size,
    this.isMinimized = false,
    this.isMaximized = false,
    this.zIndex = 1,
    this.isAlwaysOnTop = false,
  })  : previousPosition = position,
        previousSize = size;
}
