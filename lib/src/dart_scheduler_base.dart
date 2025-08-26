import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart_scheduler_interface.dart';


final class Scheduler<R> implements SchedulerInterface<R> {
  late final _RemoteScheduler<R> _remoteScheduler;
  late final ReceivePort _messageReceivePort;
  late final ReceivePort _errorMessageReceivePort;
  late final StreamSubscription<dynamic> _messageReceivePortSubscription;
  late final StreamSubscription<dynamic> _errorMessageReceivePortSubscription;
  late final Isolate _schedulerController;
  late final String? _debugName;
  late SchedulerLifeCycleState _lifeCycleState;
  late Capability? _isolateCapability;

  Scheduler(FutureOr<R> Function() computation,
      {required Duration executionInterval, String? debugName}) {
    _messageReceivePort = ReceivePort();
    _errorMessageReceivePort = ReceivePort();

    _remoteScheduler = _RemoteScheduler<R>(
        computation,
        _messageReceivePort.sendPort,
        _errorMessageReceivePort.sendPort,
        executionInterval);

    _debugName = debugName;
    _isolateCapability = null;

    _lifeCycleState = SchedulerLifeCycleState.created;
  }

  @override
  Future<void> startExecution(
      {ResultCallBack<R>? onResult, ErrorCallBack? onError}) async {
    if (_lifeCycleState != SchedulerLifeCycleState.created) {
      return;
    }

    ResultCallBack<R>? onMessageReceived = onResult;
    ErrorCallBack? onErrorReceived = onError;

    _messageReceivePortSubscription = _messageReceivePort.listen(
      (message) {
        try {
          R result = message as R;
          onMessageReceived?.call(result);
        } catch (error, stack) {
          onErrorReceived?.call(error, stack);
        }
      },
    );

    _errorMessageReceivePortSubscription = _errorMessageReceivePort.listen(
      (message) {
        try {
          Object error = message[0] as Object;
          String rawStackTrace = message[1] as String;
          StackTrace stackTrace = StackTrace.fromString(rawStackTrace);
          onErrorReceived?.call(error, stackTrace);
        } catch (error, stack) {
          onErrorReceived?.call(error, stack);
        }
      },
    );

    try {
      _schedulerController = await Isolate.spawn<_RemoteScheduler<R>>(
          _RemoteScheduler._startExecution, _remoteScheduler,
          debugName: _debugName ?? _getIsolateDebugName(),
          errorsAreFatal: true,
          onError: _errorMessageReceivePort.sendPort);

      _lifeCycleState = SchedulerLifeCycleState.active;
    } catch (error, stackTrace) {
      throw SchedulerException(error, stackTrace);
    }
  }

  String _getIsolateDebugName() {
    String debugName = "scheduler";
    int processNumber = Random().nextInt(9000) + 1000;

    return "$debugName-$processNumber";
  }

  @override
  void pauseExecution() {
    if (_lifeCycleState != SchedulerLifeCycleState.active ||
        _isolateCapability != null) {
      return;
    }

    try {
      Capability capability = _schedulerController.pause();
      _isolateCapability = capability;
      _lifeCycleState = SchedulerLifeCycleState.paused;
    } catch (error, stackTrace) {
      throw SchedulerException(error, stackTrace);
    }
  }

  @override
  void resumeExecution() {
    if (_lifeCycleState != SchedulerLifeCycleState.paused ||
        _isolateCapability == null) {
      return;
    }

    try {
      _schedulerController.resume(_isolateCapability!);
      _isolateCapability = null;
      _lifeCycleState = SchedulerLifeCycleState.active;
    } catch (error, stackTrace) {
      throw SchedulerException(error, stackTrace);
    }
  }

  @override
  Future<void> stopExecution() async {
    if (_lifeCycleState == SchedulerLifeCycleState.disposed ||
        _lifeCycleState == SchedulerLifeCycleState.created) {
      return;
    }

    try {
      _messageReceivePort.close();
      _errorMessageReceivePort.close();
      await _messageReceivePortSubscription.cancel();
      await _errorMessageReceivePortSubscription.cancel();
      _schedulerController.kill(priority: Isolate.immediate);
      _lifeCycleState = SchedulerLifeCycleState.disposed;
    } catch (error, stackTrace) {
      throw SchedulerException(error, stackTrace);
    }
  }
}

final class _RemoteScheduler<R> {
  final FutureOr<R> Function() computation;
  final SendPort sendPort;
  final SendPort errorSendPort;
  final Duration interval;

  const _RemoteScheduler(
      this.computation, this.sendPort, this.errorSendPort, this.interval);

  static void _startExecution<R>(_RemoteScheduler<R> remoteScheduler) async {
    while (true) {
      try {
        R result = await remoteScheduler.computation();
        remoteScheduler.sendPort.send(result);
      } catch (error, stack) {
        String rawStackTrace = stack.toString();
        remoteScheduler.errorSendPort.send([error, rawStackTrace]);
      } finally {
        await Future.delayed(remoteScheduler.interval);
      }
    }
  }
}

typedef ResultCallBack<R> = void Function(R result);

typedef ErrorCallBack = void Function(Object error, StackTrace stackTrace);

enum SchedulerLifeCycleState { created, active, paused, disposed }

final class SchedulerException implements Exception {
  final Object? rootCause;
  final StackTrace? rootStackTrace;
  const SchedulerException([this.rootCause, this.rootStackTrace]);

  @override
  String toString() {
    String description = "";
    if (rootCause != null) {
      description = "Root cause: $rootCause.";
    }
    if (rootStackTrace != null) {
      description = "$description\nRoot stackTrace: $rootStackTrace.";
    }

    return description;
  }
}