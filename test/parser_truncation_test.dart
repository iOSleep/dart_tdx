import 'dart:typed_data';

import 'package:test/test.dart';
import '../lib/src/parser.dart';

void main() {
  // 复现首次进入 App 时的崩溃：TDX 偶发返回截断短包（仅 2 字节），
  // 旧代码会在 parseSecurityBars 中抛 RangeError (byteOffset)。
  // 修复后：返回空列表，交由上层走重试/兜底，不崩溃。

  test('2字节响应(仅有 retCount 字段) 不抛异常并返回空', () {
    final twoBytes = Uint8List.fromList([0x01, 0x00]);
    expect(parseSecurityBars(4, twoBytes), isEmpty);
  });

  test('空响应(0字节) 不抛异常并返回空', () {
    final empty = Uint8List(0);
    expect(parseSecurityBars(4, empty), isEmpty);
  });

  test('声明 retCount 超出剩余字节(截断) 不抛异常并返回空', () {
    final truncated = Uint8List.fromList([0x05, 0x00, 0x01, 0x02]);
    expect(parseSecurityBars(4, truncated), isEmpty);
  });

  test('全零 64 字节(retCount=0) 不抛异常并返回空', () {
    final ok = Uint8List(64);
    expect(parseSecurityBars(4, ok), isEmpty);
  });
}
