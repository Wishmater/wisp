import 'package:flutter_riverpod/flutter_riverpod.dart';

final appbarHeight = NotifierProvider<DimensionNotifier, double>(() {
  return DimensionNotifier(56);
});

final drawerWidth = NotifierProvider<DimensionNotifier, double>(() {
  return DimensionNotifier(128);
});

class DimensionNotifier extends Notifier<double> {
  final double initialValue;

  DimensionNotifier(this.initialValue);

  @override
  double build() {
    return initialValue;
  }

  void set(double value) {
    state = value;
  }
}
