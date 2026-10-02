import 'package:flutter/material.dart';


class AppColors {
  AppColors._();

  /// Primary dark brown — used for backgrounds, headings and primary text.
  static const Color primaryBrown = Color(0xFF582707);

  /// Primary orange — used for main call-to-action buttons and accents.
  static const Color orange = Color(0xFFED7D3A);

  /// Orange at 50% opacity — used for input fields and soft highlights.
  static const Color orange50 = Color(0x80ED7D3A);

  /// Secondary mauve/pink at 30% opacity — used for cards and soft surfaces.
  static const Color mauve30 = Color(0x4DBC7C9C);

  /// Main app background.
  static const Color background = Color(0xFFFFFFFF);

  /// Default text color (matches primaryBrown, kept separate for clarity).
  static const Color text = Color(0xFF582707);

  /// Secondary/muted text color for captions and less prominent labels.
  static const Color textSecondary = Color(0xFF8A6653);

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
}
