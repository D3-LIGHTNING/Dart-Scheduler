abstract interface class SchedulerInterface<R> {
  Future<void> startExecution(
      {Function(R event) onResult,
      void Function(Object error, StackTrace stackTrace)? onError});

  void pauseExecution();

  void resumeExecution();

  Future<void> stopExecution();
}
