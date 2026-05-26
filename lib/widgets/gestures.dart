import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class ModifierIgnoringActivator with Diagnosticable implements ShortcutActivator {
  final LogicalKeyboardKey trigger;
  final bool includeRepeats;

  const ModifierIgnoringActivator(
    this.trigger, {
    this.includeRepeats = true,
  });

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    return (event is KeyDownEvent || (includeRepeats && event is KeyRepeatEvent)) &&
        triggers.contains(event.logicalKey);
  }

  @override
  Iterable<LogicalKeyboardKey> get triggers => <LogicalKeyboardKey>[trigger];

  @override
  String debugDescribeKeys() {
    return trigger.toString();
  }
}
