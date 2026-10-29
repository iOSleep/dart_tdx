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

  test('日K量额按 float32 解析', () {
    final raw = ByteData(18);
    raw.setUint16(0, 1, Endian.little);
    raw.setUint32(2, 20261029, Endian.little);
    raw.setUint8(6, 0x0A);
    raw.setUint8(7, 0x01);
    raw.setUint8(8, 0x02);
    raw.setUint8(9, 0x41);
    raw.setFloat32(10, 245278096, Endian.little);
    raw.setFloat32(14, 1104574464, Endian.little);

    final bars = parseSecurityBars(4, raw.buffer.asUint8List());
    expect(bars, hasLength(1));
    expect(bars.single.year, 2026);
    expect(bars.single.month, 10);
    expect(bars.single.day, 29);
    expect(bars.single.open, closeTo(0.010, 1e-9));
    expect(bars.single.close, closeTo(0.011, 1e-9));
    expect(bars.single.high, closeTo(0.012, 1e-9));
    expect(bars.single.low, closeTo(0.009, 1e-9));
    expect(bars.single.vol, closeTo(245278096, 32));
    expect(bars.single.amount, closeTo(1104574464, 128));
  });
}
