import 'package:flutter/src/scheduler/ticker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_text_layout/src/infrastructure/blink_controller.dart';

void main() {
  group("BlinkController", () {
    testWidgets("should notify its listeners when it stops blinking", (tester) async {
      bool hasNotifiedItsListener = false;

      final blinkController = BlinkController(tickerProvider: tester);
      blinkController.addListener(() { 
        hasNotifiedItsListener = true;
      });      
      
      blinkController.stopBlinking();
      
      // Ensure that the callback was called
      expect(hasNotifiedItsListener, true);
    });

    testWidgets("should notify its listeners when it starts blinking", (tester) async {
      // duration to switch between visible and invisible
      const flashPeriod = Duration(milliseconds: 500);

      bool hasNotifiedItsListeners = false;      
      
      // Create a fake ticker provider to be able to manually trigger a tick
      final tickerProvider = _TestSingleTickerProvider();          
      final blinkController = BlinkController(
        tickerProvider: tickerProvider, 
        flashPeriod: flashPeriod
      );
      blinkController.addListener(() { 
        hasNotifiedItsListeners = true;
      });      
      
      blinkController.startBlinking();
      // Trigger a tick with an ellapsed time greater than the flashPeriod,
      // so the controller should change its visible state and notify its listeners
      tickerProvider.tick(flashPeriod + const Duration(milliseconds: 1));  
    
      // Ensure that the callback was called
      expect(hasNotifiedItsListeners, true);
    });
  });
}

/// Ticker provider that creates a muted ticker
/// 
/// The tick method must be called manually
class _TestSingleTickerProvider implements TickerProvider {
  Ticker? _ticker;
  TickerCallback? _onTick;

  @override
  Ticker createTicker(TickerCallback onTick) {
    if (_ticker != null) {
      throw Exception('Only one ticker is supported');
    }
    _ticker = Ticker(onTick)
      ..muted = true;    
    _onTick = onTick;
    return _ticker!;
  }

  void tick(Duration duration) {
    if (_onTick == null) {
      throw Exception('Cannot tick if the ticker was not created');
    }
    _onTick!.call(duration);
  }
}

