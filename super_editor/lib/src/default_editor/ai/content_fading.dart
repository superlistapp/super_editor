import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/default_editor/attributions.dart';
import 'package:super_editor/src/default_editor/layout_single_column/_presenter.dart';
import 'package:super_editor/src/default_editor/text.dart';
import 'package:super_editor/src/default_editor/text_ai.dart';

/// A style phase, which controls the opacity of content, so that content
/// fades in over time.
///
/// The opacity of the content, at a given moment, is determined by two
/// things: the creation time, and the given [blockNodeFadeInDuration] and
/// [textSnippetFadeInDuration].
///
/// Any content that needs to fade-in must be attributed with a [CreatedAtAttribution],
/// with a timestamp that represents when the content was first inserted/created.
/// Based on the "created at" timestamp, and the total fade-in duration, this styler
/// sets content opacity on every frame.
class FadeInStyler extends SingleColumnLayoutStylePhase {
  FadeInStyler(
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
      _ticker.stop();
    }

    return newViewModel;
  }

  /// If the given [viewModel] isn't animated, this method returns the [viewModel]
  /// unchanged, otherwise, if it is animating, then this method copies the [viewModel],
  /// updates the copy's time to the current time, and returns the copy.
  SingleColumnLayoutComponentViewModel _updateViewModelAnimation(SingleColumnLayoutComponentViewModel viewModel) {
    if (viewModel is! TextComponentViewModel) {
      final createdAt = viewModel.metadata[NodeMetadata.createdAt];
      if (createdAt == null || createdAt is! DateTime) {
        return viewModel;
      }
      final deltaTime = DateTime.now().difference(createdAt);
      if (deltaTime > blockNodeFadeInDuration) {
        return viewModel;
      }

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
    for (final span in fadeIns) {
      final fadeInAttribution = span.attribution as CreatedAtAttribution;
      final deltaTime = DateTime.now().difference(fadeInAttribution.start);
      final opacity = deltaTime > textSnippetFadeInDuration
          ? 1.0
          : fadeCurve.transform(deltaTime.inMilliseconds / textSnippetFadeInDuration.inMilliseconds);
      if (opacity < 1) {
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
    // Fade-in status changed somewhere in the document. Run the styler again.
    markDirty();
  }
}
