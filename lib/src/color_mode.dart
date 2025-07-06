import 'package:flutter/material.dart';

enum ColorMode { day, night, sepia, grayscale }

Map<ColorMode, List<double>> predefinedFilters = {
  ColorMode.day: [
    //R  G   B    A  Const
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0, //
  ],
  ColorMode.grayscale: [
    //R  G   B    A  Const
    0.33, 0.59, 0.11, 0, 0, //
    0.33, 0.59, 0.11, 0, 0, //
    0.33, 0.59, 0.11, 0, 0, //
    0, 0, 0, 1, 0, //
  ],
  ColorMode.night: [
    //R  G   B    A  Const
    -1, 0, 0, 0, 255, //
    0, -1, 0, 0, 255, //
    0, 0, -1, 0, 255, //
    0, 0, 0, 1, 0, //
  ],
  ColorMode.sepia: [
    //R  G   B    A  Const
    0.393, 0.769, 0.189, 0, 0, //
    0.349, 0.686, 0.168, 0, 0, //
    0.172, 0.534, 0.131, 0, 0, //
    0, 0, 0, 1, 0, //
  ],
};

extension ColorModeExtension on ColorMode {
  Color get backgroundColor {
    switch (this) {
      case ColorMode.day:
        return Colors.grey.shade200;
      case ColorMode.night:
        return Colors.grey.shade800;
      case ColorMode.sepia:
        return const Color.fromARGB(220, 255, 255, 213);
      case ColorMode.grayscale:
        return Colors.grey.shade300;
    }
  }
}
