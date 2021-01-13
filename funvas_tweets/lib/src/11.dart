import 'dart:math';
import 'dart:ui';

import 'package:funvas/funvas.dart';
import 'package:funvas_tweets/src/tweet_mixin.dart';

class Eleven extends Funvas with FunvasTweetMixin {
  @override
  String get tweet =>
      'https://twitter.com/creativemaybeno/status/1346101868079042561?s=20';

  @override
  void u(double t) {
    final s = s2q(750), w = s.width, h = s.height;

    c.drawPaint(Paint()..color = const Color(0xfffaddaa));

    const foregroundColor = Color(0xffff6a50);
    c.translate(w / 2, h / 2);
    c.drawCircle(Offset.zero, 76, Paint()..color = foregroundColor);

    const outerRadius = 108.0, step = 40, orbits = 7;
    for (var i = orbits - 1; i >= 0; i--) {
      final radius = outerRadius + step * i;

      c.drawCircle(
        Offset.zero,
        radius,
        Paint()
          ..color = foregroundColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );

      c.save();
      c.rotate(sin((t + i * 4.242424) * pi / 5) * 2 * pi);
      c.drawCircle(
        Offset.fromDirection(-pi / 2, radius),
        11,
        Paint()..color = foregroundColor,
      );
      c.restore();
    }
  }
}
