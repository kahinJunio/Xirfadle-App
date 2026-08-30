import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Decouples the network layer from the auth feature: the interceptor reports
/// an unrecoverable 401 here, and the auth controller listens and signs out.
class SessionGate {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get onExpired => _controller.stream;

  void notifyExpired() {
    if (!_controller.isClosed) _controller.add(null);
  }

  void dispose() => _controller.close();
}

final sessionGateProvider = Provider<SessionGate>((ref) {
  final gate = SessionGate();
  ref.onDispose(gate.dispose);
  return gate;
});
