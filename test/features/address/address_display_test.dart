import 'package:flutter_test/flutter_test.dart';

import 'package:wallet_test/features/address/address_display.dart';

void main() {
  test('short address is unchanged', () {
    expect(formatAddressForCell('0x1234', 2.0), '0x1234');
    expect(formatAddressForCell('123456789012', 1.0), '123456789012');
  });

  test('long 0x address uses 6 + 4 at normal scale', () {
    const address = '0x1234567890abcdef1234567890abcdef12345678';

    expect(formatAddressForCell(address, 1.0), '0x123456…5678');
  });

  test('large text scale uses 4 + 4', () {
    const address = '0x1234567890abcdef1234567890abcdef12345678';

    expect(formatAddressForCell(address, 1.6), '0x1234…5678');
  });

  test('address without 0x is shortened', () {
    const address = '1234567890abcdef1234567890abcdef12345678';

    expect(formatAddressForCell(address, 1.0), '123456…5678');
  });

  test('0x prefix is preserved', () {
    const address = '0xabcdefghijklmno';

    expect(formatAddressForCell(address, 1.0), '0xabcdef…lmno');
  });
}
