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
const animationDuration = Duration(seconds: 8);
const dimensions = Size(750, 750);
// If you use a different animation name, you will have to also consider that
// when assembling the animation using ffmpeg.
const animationName = 'animation';
const exportPath = 'export';

// Using a callback so that the constructor is executed after initializing the
// binding.
Funvas funvasFactory() => Four();

Future<void> main() async {
  _RenderingFlutterBinding.ensureInitialized();

  final time = ValueNotifier(.0);
  final funvas = funvasFactory();
  if (funvas is FunvasFutureMixin) await funvas.future;
  final rootWidget = SizedBox.fromSize(
    size: dimensions,
    child: CustomPaint(
      painter: FunvasPainter(
        time: time,
        delegate: funvas,
      ),
    ),
  );

  _RenderingFlutterBinding.instance
    ..setSurfaceSize(dimensions)
    ..attachRootWidget(rootWidget)
    // Schedule and render a warm-up frame.
    ..scheduleWarmUpFrame()
    ..handleBeginFrame(Duration.zero)
    ..handleDrawFrame();
  await _renderFrame();

  final microseconds = animationDuration.inMicroseconds,
      framesToRender = fps * (microseconds / 1e6) ~/ 1;

  final clock = Stopwatch()..start();
  final futures = <Future>[];
  for (var i = 0; i < framesToRender; i++) {
    time.value = microseconds / framesToRender * i / 1e6;

    // Render the funvas animation / frame in the render view.
    _RenderingFlutterBinding.instance
      ..scheduleFrame()
      ..handleBeginFrame(clock.elapsed)
      ..handleDrawFrame();

    final image = await _renderFrame();
    final frame = i + 1;
    // We parallelize the saving of the rendered frames by running the futures
    // in parallel.
    futures.add(_exportFrame(image, clock, framesToRender, frame));

    final elapsedTime = clock.elapsed;
    final estimatedRemaining = Duration(
        microseconds:
            elapsedTime.inMicroseconds ~/ frame * (framesToRender - frame));
    print('[r] $frame/$framesToRender, $elapsedTime, -$estimatedRemaining');
  }

  await Future.wait(futures);
  time.dispose();
  clock.stop();
  exit(0);
}

Future<ui.Image> _renderFrame() {
  final renderView = _RenderingFlutterBinding.instance.renderView;
  return renderView.layer.toImage(renderView.paintBounds);
}

Future<void> _exportFrame(
    ui.Image image, Stopwatch clock, int framesToRender, int frame) async {
  final bytes = await image.clone().toByteData(format: ui.ImageByteFormat.png);
  image.dispose();

  final fileNameWidth = (framesToRender - 1).toString().length;
  final fileName = '${'${frame - 1}'.padLeft(fileNameWidth, '0')}.png';
  final filePath = p.join(exportPath, animationName, fileName);
  final file = File(filePath);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);

  final elapsedTime = clock.elapsed;
  final estimatedRemaining = Duration(
      microseconds:
          elapsedTime.inMicroseconds ~/ frame * (framesToRender - frame));
  print('[e] $frame/$framesToRender, $elapsedTime, -$estimatedRemaining');
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
    return ViewConfiguration(
      size: _surfaceSize ?? dimensions,
      devicePixelRatio: 1,
    );
  }

  @override
  void initRenderView() {
    renderView = _ExposedRenderView(
      configuration: createViewConfiguration(),
      view: platformDispatcher.implicitView!,
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
    required ui.FlutterView view,
  }) : super(child: child, configuration: configuration, view: view);

  // Unprotect the layer getter.
  @override
  OffsetLayer get layer => super.layer as OffsetLayer;
}
