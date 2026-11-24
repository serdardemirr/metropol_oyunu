// `flutter create .` bu dosyayı varsayılan bir sayaç testiyle oluşturur;
// burada önceden durması onun üzerine yazılmasını engeller.
import 'package:flutter_test/flutter_test.dart';
import 'package:metropol/core/utils/room_code.dart';

void main() {
  test('oda kodu 4 haneli', () {
    for (var i = 0; i < 100; i++) {
      expect(RoomCode.isValid(RoomCode.generate()), isTrue);
    }
    expect(RoomCode.isValid('0123'), isFalse);
    expect(RoomCode.isValid('12a4'), isFalse);
  });
}
