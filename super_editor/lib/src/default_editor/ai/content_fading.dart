import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_presenter.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/default_editor/text_ai.dart';

class FadeInTextStyler extends SingleColumnLayoutStylePhase {
  FadeInTextStyler(
    TickerProvider tickerProvider, {
    this.blockNodeFadeInDuration = const Duration(milliseconds: 1500),
    this.textSnippetFadeInDuration = const Duration(milliseconds: 250),
    this.fadeCurve = Curves.easeInOut,
  }) {
    _ticker = tickerProvider.createTicker(_onTick);
  }

  final Duration blockNodeFadeInDuration;
  final Duration textSnippetFadeInDuration;
  final Curve fadeCurve;

  @override
  void dispose() {
    _ticker.stop();
    super.dispose();
  }

  late final Ticker _ticker;

  bool _isFading = false;

  @override
  SingleColumnLayoutViewModel style(Document document, SingleColumnLayoutViewModel viewModel) {
    print("Running FadeInTextStyler - style()");
    _isFading = false;

    final newViewModel = SingleColumnLayoutViewModel(
      padding: viewModel.padding,
      componentViewModels: [
        for (final viewModel in viewModel.componentViewModels) //
          _updateViewModelAnimation(viewModel),
      ],
    );

    if (!_isFading && _ticker.isActive) {
      // No fading is required. Stop ticking.
      print("Stopping fade-in ticker");
      _ticker.stop();
    }

    return newViewModel;
  }

  /// If the given [viewModel] isn't animated, this method returns the [viewModel]
  /// unchanged, otherwise, if it is animating, then this method copies the [viewModel],
  /// updates the copy's time to the current time, and returns the copy.
  SingleColumnLayoutComponentViewModel _updateViewModelAnimation(SingleColumnLayoutComponentViewModel viewModel) {
    print("_updateViewModelAnimation(): $viewModel");
    if (viewModel is! TextComponentViewModel) {
      print("Inspecting a non-text node");
      final createdAt = viewModel.metadata['createdAt'];
      if (createdAt == null || createdAt is! DateTime) {
        print("Non-text node has no created at");
        return viewModel;
      }
      final deltaTime = DateTime.now().difference(createdAt);
      if (deltaTime > blockNodeFadeInDuration) {
        print("Non-text node is already faded in");
        return viewModel;
      }

      print("Fading in non-text node. Delta time: $deltaTime");
      final opacity = fadeCurve.transform(lerpDouble(
        0,
        1,
        deltaTime.inMilliseconds / blockNodeFadeInDuration.inMilliseconds,
      )!
          .clamp(0, 1));

      // An animation is ongoing. We need to schedule another frame to continue
      // updating the view model, which will then cause the component widget to
      // re-render and show the animation.
      _isFading = true;
      _scheduleAnotherFrame();

      return viewModel.copy()
        ..opacity = opacity
        ..latestClockTick = DateTime.now();
    }

    final fadeIns = viewModel.text.getAttributionSpansByFilter((a) => a is CreatedAtAttribution).toList();
    final fadeInAttributions = fadeIns.map((s) => s.attribution).toList().cast<CreatedAtAttribution>();
    if (fadeInAttributions.isEmpty) {
      return viewModel;
    }
    final isFading = fadeInAttributions.fold(false, (isFading, fadeIn) => isFading || _isTextFading(fadeIn.start));
    print(
        "View model ($viewModel) fade-ins:\n${fadeInAttributions.map((a) => "Fading: ${_isTextFading(a.start)}, start: ${a.start}, expiry: ${DateTime.now()}, time since start: ${DateTime.now().difference(a.start)}").join("\n")}");
    if (!isFading) {
      return viewModel;
    }

    // An animation is ongoing. We need to schedule another frame to continue
    // updating the view model, which will then cause the component widget to
    // re-render and show the animation.
    _isFading = true;
    _scheduleAnotherFrame();

    // We know we're fading something. Create a copy of the view model so we can
    // change it.
    final textViewModel = (viewModel.copy()..latestClockTick = DateTime.now()) as TextComponentViewModel;

    // Add opacity attributions based on created-at timestamps.
    // TODO: Once the fade-in-to-opacity relationship works, replace FadeInAttribution
    //       with a CreatedAtAttribution.
    for (final span in fadeIns) {
      final fadeInAttribution = span.attribution as CreatedAtAttribution;
      final deltaTime = DateTime.now().difference(fadeInAttribution.start);
      final opacity = deltaTime > textSnippetFadeInDuration
          ? 1.0
          : fadeCurve.transform(deltaTime.inMilliseconds / textSnippetFadeInDuration.inMilliseconds);
      if (opacity < 1) {
        print("Fade-in span (${span.range.start} -> ${span.range.end}) - opacity: $opacity");
        textViewModel.text.addAttribution(
          OpacityAttribution(opacity),
          span.range,
        );
      }
    }

    return textViewModel;
  }

  bool _isTextFading(DateTime startTime) {
    return (DateTime.now().difference(startTime) < textSnippetFadeInDuration);
  }

  void _scheduleAnotherFrame() {
    if (_ticker.isActive) {
      return;
    }

    _ticker.start();
  }

  void _onTick(Duration elapsedTime) {
    print("_onTick() - duration: $elapsedTime");
    // Fade-in status changed somewhere in the document. Run the styler again.
    markDirty();
  }
}
