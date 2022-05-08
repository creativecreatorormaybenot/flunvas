import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:funvas/funvas.dart';
import 'package:funvas_tweets/funvas_tweets.dart';
import 'package:path/path.dart' as p;

const fps = 50;
const animationDuration = Duration(seconds: 14);
const dimensions = Size(750, 750);
// If you use a different animation name, you will have to also consider that
// when assembling the animation using ffmpeg.
const animationName = 'animation';
const exportPath = 'export';

// Using a callback so that the constructor is run inside of the test.
Funvas funvasFactory() => Fifty();

Future<void> main() async {
  final time = ValueNotifier(.0);
  final funvas = funvasFactory();
  if (funvas is FunvasFutureMixin) {
    await funvas.future;
  }

  final rootWidget = SizedBox.fromSize(
    size: dimensions,
    child: CustomPaint(
      painter: FunvasPainter(
        time: time,
        delegate: funvas,
      ),
    ),
  );
  final binding = _RenderingFlutterBinding.ensureInitialized()
    ..setSurfaceSize(dimensions)
    ..attachRootWidget(rootWidget)
    ..scheduleWarmUpFrame();

  final microseconds = animationDuration.inMicroseconds,
      framesToRender = fps * (microseconds / 1e6) ~/ 1;
  final fileNameWidth = (framesToRender - 1).toString().length;

  final clock = Stopwatch()..start();
  final futures = <Future>[];
  for (var i = 0; i < framesToRender; i++) {
    time.value = microseconds / framesToRender * i / 1e6;

    // Render the page in the widget tree / render view.
    binding
      ..attachRootWidget(rootWidget)
      ..scheduleFrame()
      ..handleBeginFrame(clock.elapsed)
      ..handleDrawFrame();

    final renderView = binding.renderView;
    // We parallelize the saving of the rendered frames by running the futures
    // in parallel.
    futures.add(_exportFrame(
      renderView.layer.toImage(renderView.paintBounds),
      '$animationName/${'$i'.padLeft(fileNameWidth, '0')}.png',
    ));

    final frame = i + 1;
    final elapsedTime = clock.elapsed;
    final estimatedRemaining = Duration(
        microseconds:
            elapsedTime.inMicroseconds ~/ frame * (framesToRender - frame));
    // ignore: avoid_print
    print('$frame/$framesToRender, $elapsedTime, -$estimatedRemaining');
  }
  clock.stop();

  await Future.wait(futures);
  time.dispose();
}

Future<void> _exportFrame(Future<ui.Image> imageFuture, String fileName) async {
  final image = await imageFuture;
  final bytes = await image.clone().toByteData(format: ui.ImageByteFormat.png);
  image.dispose();

  final filePath = p.join(exportPath, animationName, fileName);
  final file = File(filePath);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
}

/// Binding implementation specifically tailored to rendering animations.
///
/// This binding allows setting the surface size of the root [RenderView] and
/// inserts an [_ExposedRenderView] for converting the rendered root to images.
class _RenderingFlutterBinding extends BindingBase
    with
        SchedulerBinding,
        ServicesBinding,
        GestureBinding,
        SemanticsBinding,
        RendererBinding,
        PaintingBinding,
        WidgetsBinding {
  static _RenderingFlutterBinding? _instance;
  static _RenderingFlutterBinding get instance =>
      BindingBase.checkInstance(_instance);

  static _RenderingFlutterBinding ensureInitialized() {
    if (_RenderingFlutterBinding._instance == null) {
      _RenderingFlutterBinding();
    }
    return _RenderingFlutterBinding.instance;
  }

  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
  }

  Size? _surfaceSize;

  void setSurfaceSize(Size? size) {
    if (_surfaceSize == size) return;
    _surfaceSize = size;
    handleMetricsChanged();
  }

  @override
  ViewConfiguration createViewConfiguration() {
    final devicePixelRatio = window.devicePixelRatio;
    final size = _surfaceSize ?? window.physicalSize / devicePixelRatio;
    return ViewConfiguration(
      size: size,
      devicePixelRatio: devicePixelRatio,
    );
  }

  @override
  void initRenderView() {
    renderView = _ExposedRenderView(
      configuration: createViewConfiguration(),
      window: window,
    );
    renderView.prepareInitialFrame();
  }

  @override
  _ExposedRenderView get renderView => super.renderView as _ExposedRenderView;
}

/// Render view implementation that exposes the [layer] as an [OffsetLayer]
/// for converting to images at the root level.
class _ExposedRenderView extends RenderView {
  _ExposedRenderView({
    RenderBox? child,
    required ViewConfiguration configuration,
    required ui.FlutterView window,
  }) : super(child: child, configuration: configuration, window: window);

  // Unprotect the layer getter.
  @override
  OffsetLayer get layer => super.layer as OffsetLayer;
}
