import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanity check passes', () {
    expect(1 + 1, 2);
  });

  test('string normalization baseline', () {
    expect(' Volunteer '.trim().toLowerCase(), 'volunteer');
  });
}
