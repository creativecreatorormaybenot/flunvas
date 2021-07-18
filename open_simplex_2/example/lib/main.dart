import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart' hide Image;
import 'package:funvas/funvas.dart';
import 'package:open_simplex_2/open_simplex_2.dart';

void main() {
  runApp(const ExampleApp());
}

/// Example app showcasing how to use the `open_simplex_2` package.
class ExampleApp extends StatefulWidget {
  const ExampleApp({Key? key}) : super(key: key);

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final _funvas = _OpenSimplex2Funvas()..initializeNoise(fast: true);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'open_simplex_2 example',
      home: Scaffold(
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _funvas.initializeNoise(fast: _funvas.noise is OpenSimplex2S);
          },
          child: SizedBox.expand(
            child: FunvasContainer(
              funvas: _funvas,
            ),
          ),
        ),
      ),
    );
  }
}

/// Example funvas using the `open_simplex_2` package.
///
/// Part of this code is ported from one of  Etienne Jacob's tutorials on his personal
/// website (https://bleuje.github.io/tutorial3/).
/// You can find it here: https://gist.githubusercontent.com/Bleuje/0ee88547c273b6ae49ae69527c13e611/raw/a28fb770ab6586a11cda227c44af0ac57f45e8d7/tuto3_entirecode.pde.
class _OpenSimplex2Funvas extends Funvas {
  static const dimension = 100.0;

  late OpenSimplex2 noise;

  void initializeNoise({required bool fast}) {
    if (fast) {
      noise = OpenSimplex2F(12345);
    } else {
      noise = OpenSimplex2S(12345);
    }
  }

  @override
  void u(double t) {
    s2q(dimension);
    c.drawColor(const Color(0xff000000), BlendMode.srcOver);

    draw2dNoise(t);
    drawPropagation(t);
    final textPainter = TextPainter(
      text: TextSpan(
        text: noise is OpenSimplex2S
            ? 'OpenSimplex2S (smoother)'
            : 'OpenSimplex2F (faster)',
        style: const TextStyle(
          fontSize: 3,
          color: Color(0xffffffff),
          backgroundColor: Color(0xff000000),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(c, Offset.zero);
  }

  void draw2dNoise(double t) {
    for (var x = 0.0; x < dimension; x++) {
      for (var y = 0.0; y < dimension; y++) {
        c.drawRect(
          Rect.fromLTWH(x, y, 1, 1),
          Paint()
            ..color = HSLColor.fromAHSL(
              1 / 2 + 1 / 2 * noise.noise3XYBeforeZ(x / 1e2, y / 1e2, t / 3),
              noise.noise2(x / 100, y / 100) * 180 + 180,
              3 / 4,
              3 / 4,
            ).toColor(),
        );
      }
    }
  }

  void drawPropagation(double t) {
    // This and below is the code ported from https://gist.githubusercontent.com/Bleuje/0ee88547c273b6ae49ae69527c13e611.
    const m = 45;
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < m; j++) {
        const margin = dimension / 10;
        final x = (dimension - margin * 2) * i / (m - 1) + margin;
        final y = (dimension - margin * 2) * j / (m - 1) + margin;

        final dx = 20.0 * periodicFunction(t / 3 - offset(x, y), 0, x, y);
        final dy = 20.0 * periodicFunction(t / 3 - offset(x, y), 123, x, y);

        c.drawCircle(
          Offset(x + dx, y + dy),
          dimension / 200,
          Paint()
            ..color = const Color.fromARGB(50, 255, 255, 255)
            ..blendMode = BlendMode.plus,
        );
      }
    }
  }

  double periodicFunction(double p, double seed, double x, double y) {
    const radius = 1.3;
    const scl = 0.018;
    return noise.noise4Classic(
      seed + radius * cos(2 * pi * p),
      radius * sin(2 * pi * p),
      scl * x,
      scl * y,
    );
  }

  double offset(double x, double y) {
    return 0.015 * sqrt(pow(dimension / 2 - x, 2) + pow(dimension / 2 - y, 2));
  }
}
