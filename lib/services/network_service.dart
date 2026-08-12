import 'dart:async';

Future<T> withTimeout<T>(
  Future<T> future,
) async {
  return future.timeout(
    const Duration(seconds: 15),
  );
}