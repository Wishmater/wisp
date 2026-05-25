import 'dart:async';
import 'dart:isolate';

import 'package:fast_copy/src/copy.dart';
import 'package:fast_copy/src/operation.dart';
import 'package:fast_copy/src/types.dart';

class IsolateCopyRunner {
  final SendPort _workerSendPort;
  final ReceivePort _receiverPort;
  final Isolate _isolate;
  final Stream<dynamic> _broadcastStream;

  IsolateCopyRunner._({
    required SendPort workerSendPort,
    required ReceivePort receiverPort,
    required Stream<dynamic> broadcastStream,
    required Isolate isolate,
  }) : _workerSendPort = workerSendPort,
       _receiverPort = receiverPort,
       _broadcastStream = broadcastStream,
       _isolate = isolate;

  static Future<IsolateCopyRunner> spawn() async {
    final receiverPort = ReceivePort();
    final broadcast = receiverPort.asBroadcastStream();
    final isolate = await Isolate.spawn(_workerEntry, receiverPort.sendPort);

    final handshakeCompleter = Completer<SendPort>();

    final subscription = broadcast.listen((msg) {
      if (msg is SendPort) {
        handshakeCompleter.complete(msg);
      }
    });

    final workerSendPort = await handshakeCompleter.future;
    subscription.cancel();

    return IsolateCopyRunner._(
      workerSendPort: workerSendPort,
      receiverPort: receiverPort,
      broadcastStream: broadcast,
      isolate: isolate,
    );
  }

  Future<void> startCopy(
    ICopy copier,
    String sourcePath,
    String destPath, [
    bool paused = false,
  ]) async {
    await _request(
      _StartCopyRequest(copier: copier, sourcePath: sourcePath, destPath: destPath, paused: paused),
    );
    return;
  }

  Future<void> pause() async {
    await _request(_PauseRequest());
    return;
  }

  Future<void> resume() async {
    await _request(_ResumeRequest());
    return;
  }

  Future<CopyState> snapshot() async {
    final _SnapshotResponse response = await _request(_SnapshotRequest());
    return response.state;
  }

  void dispose() {
    _receiverPort.close();
    _isolate.kill(priority: Isolate.immediate);
  }

  Future<R> _request<R extends _Response>(_Request request) async {
    _workerSendPort.send(request);
    return (await _broadcastStream
        .where((msg) => msg is R)
        .cast<R>()
        .firstWhere((msg) => msg.id == request.id));
  }
}

void _workerEntry(SendPort mainSendPort) {
  final workerPort = ReceivePort();
  mainSendPort.send(workerPort.sendPort);

  CopyOperation? currentOp;

  workerPort.listen((msg) {
    switch (msg as _Request) {
      case _StartCopyRequest(:final id, :final copier, :final sourcePath, :final destPath, :final paused):
        currentOp = CopyOperation(
          DirectorySource(path: sourcePath),
          destPath,
          copier,
          paused,
        );
        mainSendPort.send(_StartCopyResponse(id));
      case _PauseRequest(:final id):
        currentOp!.pause();
        mainSendPort.send(_PauseResponse(id));
      case _ResumeRequest(:final id):
        currentOp!.resume();
        mainSendPort.send(_ResumeResponse(id));
      case _SnapshotRequest(:final id):
        mainSendPort.send(_SnapshotResponse(id, currentOp!.state));
    }
  });
}

int _genId = 0;

sealed class _Request {
  final int id;

  _Request() : id = _genId++;
}

class _StartCopyRequest extends _Request {
  final String sourcePath;
  final String destPath;
  final ICopy copier;
  final bool paused;

  _StartCopyRequest({
    required this.copier,
    required this.sourcePath,
    required this.destPath,
    required this.paused,
  });
}

class _PauseRequest extends _Request {}

class _ResumeRequest extends _Request {}

class _SnapshotRequest extends _Request {}

sealed class _Response {
  final int id;

  _Response(this.id);
}

class _StartCopyResponse extends _Response {
  _StartCopyResponse(super.id);
}

class _PauseResponse extends _Response {
  _PauseResponse(super.id);
}

class _ResumeResponse extends _Response {
  _ResumeResponse(super.id);
}

class _SnapshotResponse extends _Response {
  final CopyState state;
  _SnapshotResponse(super.id, this.state);
}
