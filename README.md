# Dart Scheduler

A simple yet powerful Dart library for scheduling and running periodic tasks in a background isolate Modeled after the java "ScheduledExecuterService" API. This is useful for long-running or computationally intensive tasks that you don't want to block your application's main thread.

## Features

- ✅ **Background Execution**: Runs your tasks in a separate isolate to prevent blocking the main thread.
- ✅ **Lifecycle Management**: Easily start, pause, resume, and stop your scheduled tasks.
- ✅ **Periodic Execution**: Schedule a function to run at a fixed interval.
- ✅ **Type-Safe**: Fully generic, allowing you to return any data type from your background task.
- ✅ **Error Handling**: Provides simple callbacks for handling results and errors back on the main thread.

## Usage

Import the package in your Dart file:

```dart
import 'package:dart_scheduler/dart_scheduler.dart';
```

Here is a simple example of scheduling a task to run every 2 seconds. The task generates a random number in a background isolate and returns it to the main isolate.

```dart
import 'dart:isolate';
import 'dart:math';
import 'package:dart_scheduler/dart_scheduler.dart';

// This is the function that will be executed in the background isolate.
// It must be a top-level function or a static method.
Future<int> computation() async {
  final randomNumber = Random().nextInt(1000);
  print("Isolate Name: ${Isolate.current.debugName}, returning: $randomNumber");
  return randomNumber;
}

void main() async {
  // 1. Create a Scheduler instance.
  //    - Provide the computation function.
  //    - Set the execution interval.
  final scheduler = Scheduler<int>(
    computation,
    executionInterval: const Duration(seconds: 2),
  );

  // 2. Start the scheduler and listen for results or errors.
  print('Starting scheduler...');
  scheduler.startExecution(
    onResult: (result) => print('Main Isolate: Result received: $result'),
    onError: (error, stack) => print('Main Isolate: Error: $error'),
  );

  // Let it run for 10 seconds.
  await Future.delayed(const Duration(seconds: 10));

  // 3. Pause the scheduler.
  print('Pausing scheduler...');
  scheduler.pauseExecution();
  await Future.delayed(const Duration(seconds: 5)); // Wait while paused

  // 4. Resume the scheduler.
  print('Resuming scheduler...');
  scheduler.resumeExecution();
  await Future.delayed(const Duration(seconds: 10)); // Let it run again

  // 5. Stop the scheduler permanently.
  print('Stopping scheduler...');
  scheduler.stopExecution();
}
```