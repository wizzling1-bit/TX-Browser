import 'dart:async';

/// A simple debouncer for search input.
///
/// Usage:
/// ```dart
/// final debounce = Debounce(milliseconds: 250);
/// textController.addListener(() {
///   debounce.run(() => performSearch(textController.text));
/// });
/// ```

class Debounce {
  Debounce({this.milliseconds = 250});

  final int milliseconds;
  Timer? _timer;

  /// Runs [action] after the debounce period, cancelling any pending call.
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  /// Cancels any pending debounced action.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Cleans up the timer. Call in `dispose()`.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
