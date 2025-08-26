import 'dart:isolate';
import 'dart:math';
import 'package:dart_scheduler/dart_scheduler.dart';

void main() async {
  Scheduler<int> scheduler = Scheduler<int>(computation,
      executionInterval: const Duration(seconds: 2));

  scheduler.startExecution(
      onResult: (result) => print(
          'Isolate Name: ${Isolate.current.debugName}, Result received: $result'),
      onError: (error, stack) => print(
          'Isolate Name: ${Isolate.current.debugName}, Error: $error, Stack: $stack'));
  
  await Future.delayed(const Duration(seconds: 10));
  scheduler.pauseExecution();

  await Future.delayed(const Duration(seconds: 10));
  scheduler.resumeExecution();

  await Future.delayed(const Duration(seconds: 10));
  scheduler.stopExecution();
}

Future<int> computation() async {
  print("Isolate Name: ${Isolate.current.debugName}, returning random integer");
  return Random().nextInt(1000);
}
