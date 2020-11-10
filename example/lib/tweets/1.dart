import 'dart:math';
import 'dart:ui';

import 'package:funvas/funvas.dart';

/// https://twitter.com/creativemaybeno/status/1325389303288107008?s=20
class One extends Funvas {
  @override
  void u(double t) {
    final w = x.width,
        h = x.height,
        m = min(w, h),
        center = Offset(w / 2, h / 2);

    // Draw background.
    c.drawPaint(Paint()..color = R(242, 227, 193));

    final outer = m * (.42 + C(t / 3) * 5e-2);

    // Draw background circle.
    c.drawCircle(
      center,
      outer,
      Paint()..color = R(50, 71, 104),
    );

    const padding = 8;

    // Draws a small circle.
    void sc(double delta, double radius) {
      void draw(double minorDelta) {
        c.drawCircle(
          center +
              Offset.fromDirection(
                  T(S(t + pow(.2, delta))) * pi * 2 + minorDelta / 100,
                  outer - padding - radius - minorDelta / 10),
          radius - minorDelta / 10,
          Paint()
            ..color = R(200 + delta * 40, 100 + delta * 80, 100 - minorDelta,
                .1 + delta / 5),
        );
      }

      for (var i = 0; i < delta * 10; i++) {
        draw(i * 7.0);
      }
    }

    for (var i = 0; i < 16; i++) {
      sc(i / 2 / 10, 120.0 - i * 7);
    }
  }
}
