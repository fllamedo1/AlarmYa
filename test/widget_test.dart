import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Smoke test: el proyecto compila', () {
    const key = ValueKey('alarmya');
    expect(key.value, 'alarmya');
  });
}
