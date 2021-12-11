import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '_logging.dart';

/// Animates the scroll offset of a given [scrollPosition] based on a
/// given speed percent.
class AutoScroller {
  AutoScroller({
    required TickerProvider vsync,
    double maxScrollSpeed = 5,
    ScrollPosition? scrollPosition,
  })  : _maxScrollSpeed = maxScrollSpeed,
        _scrollPosition = scrollPosition {
    _ticker = vsync.createTicker(_onTick);
  }

  void dispose() {
    _ticker.dispose();
  }

  final double _maxScrollSpeed;

  ScrollPosition? _scrollPosition;
  set scrollPosition(ScrollPosition? scrollPosition) => _scrollPosition = scrollPosition;

  double _scrollSpeedPercent = 0.0;

  bool _scrollUpOnTick = false;

  bool _scrollDownOnTick = false;

  late Ticker _ticker;

  void startScrollingUp(double speedPercent) {
    _scrollSpeedPercent = speedPercent;

    if (_scrollUpOnTick) {
      return;
    }

    editorGesturesLog.finest('Starting to auto-scroll up');
    _scrollUpOnTick = true;
    _ticker.start();
  }

  void _scrollUp() {
    if (_scrollPosition == null) {
      editorGesturesLog.warning("Tried to scroll up but the scroll position is null");
      return;
    }

    if (_scrollPosition!.pixels <= 0) {
      editorGesturesLog.finest("Tried to scroll up but the scroll position is already at the top");
      return;
    }

    editorGesturesLog.finest("Scrolling up on tick");
    final scrollAmount = lerpDouble(0, _maxScrollSpeed, _scrollSpeedPercent);

    _scrollPosition!.jumpTo(_scrollPosition!.pixels - scrollAmount!);
  }

  void stopScrollingUp() {
    if (!_scrollUpOnTick) {
      return;
    }

    editorGesturesLog.finest('Stopping auto-scroll up');
    _scrollUpOnTick = false;
    _ticker.stop();
  }

  void startScrollingDown(double speedPercent) {
    _scrollSpeedPercent = speedPercent;

    if (_scrollDownOnTick) {
      return;
    }

    editorGesturesLog.finest('Starting to auto-scroll down');
    _scrollDownOnTick = true;
    _ticker.start();
  }

  void _scrollDown() {
    if (_scrollPosition == null) {
      editorGesturesLog.warning("Tried to scroll down but the scroll position is null");
      return;
    }

    if (_scrollPosition!.pixels >= _scrollPosition!.maxScrollExtent) {
      editorGesturesLog.finest("Tried to scroll down but the scroll position is already beyond the max");
      return;
    }

    editorGesturesLog.finest("Scrolling down on tick");
    final scrollAmount = lerpDouble(0, _maxScrollSpeed, _scrollSpeedPercent);

    _scrollPosition!.jumpTo(_scrollPosition!.pixels + scrollAmount!);
  }

  void stopScrollingDown() {
    if (!_scrollDownOnTick) {
      return;
    }

    editorGesturesLog.finest('Stopping auto-scroll down');
    _scrollDownOnTick = false;
    _ticker.stop();
  }

  void stopScrolling() {
    stopScrollingUp();
    stopScrollingDown();
  }

  void _onTick(elapsedTime) {
    if (_scrollUpOnTick) {
      _scrollUp();
    }
    if (_scrollDownOnTick) {
      _scrollDown();
    }
  }
}
