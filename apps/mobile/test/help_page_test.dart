import 'package:flutter_test/flutter_test.dart';

Uri buildPhoneUri(String number) {
  final cleanNumber = number.replaceAll(' ', '');
  return Uri.parse('tel:$cleanNumber');
}

void main() {
  group('Help Page Tests', () {
    test('buildPhoneUri cleans spaces and creates valid tel: URI', () {
      expect(buildPhoneUri('119').toString(), 'tel:119');
      expect(buildPhoneUri('0912 345 678').toString(), 'tel:0912345678');
      expect(buildPhoneUri('02 2595 3316').toString(), 'tel:0225953316');
      expect(buildPhoneUri(' 1955  ').toString(), 'tel:1955');
    });
  });
}
