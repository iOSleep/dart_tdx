import 'dart:typed_data';

import 'constants.dart';

/// Get security type string from market and code.
String getSecurityType(int market, String code) {
  final head = code.substring(0, 2);

  if (market == 0) {
    // 深圳
    if (['00', '30'].contains(head)) return 'SZ_A_STOCK';
    if (head == '20') return 'SZ_B_STOCK';
    if (head == '39') return 'SZ_INDEX';
    if (['15', '16'].contains(head)) return 'SZ_FUND';
    if (['10', '11', '12', '13', '14'].contains(head)) return 'SZ_BOND';
  } else if (market == 1) {
    // 上海
    if (['60', '68'].contains(head)) return 'SH_A_STOCK';
    if (head == '90') return 'SH_B_STOCK';
    if (['00', '88', '99'].contains(head)) return 'SH_INDEX';
    if (['5'].any((p) => head.startsWith(p))) return 'SH_FUND';
    if (['01', '10', '11', '12', '13', '14', '20'].contains(head)) return 'SH_BOND';
  } else if (market == 2) {
    // 北京 (BJ)
    if (['8'].any((p) => head.startsWith(p))) return 'BJ_A_STOCK';
    if (['4'].any((p) => head.startsWith(p))) return 'BJ_A_STOCK';
  }

  throw UnimplementedError('Unknown security type: market=$market, code=$code');
}

/// Get security price coefficient.
double getSecurityCoefficient(int market, String code) {
  final type = getSecurityType(market, code);
  final coeff = securityCoefficient[type];
  if (coeff == null || coeff.isEmpty) return 0.01;
  return coeff[0];
}

/// Determine market (0 for SZ, 1 for SH, 2 for BJ) from stock code.
/// Logic aligned with Python mootdx `get_stock_market`.
int getStockMarket(String symbol, [bool returnName = false]) {
  final code = symbol.replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');

  // Check explicit market prefix (always, matching Python behavior)
  if (code.startsWith('sh') || code.startsWith('SH')) return 1;
  if (code.startsWith('sz') || code.startsWith('SZ')) return 0;
  if (code.startsWith('bj') || code.startsWith('BJ')) return 2;

  // Multi-digit prefixes for Shanghai
  if (['50', '51', '60', '68', '90', '110', '113', '132', '204']
      .any((p) => code.startsWith(p))) {
    return 1;
  }

  // Multi-digit prefixes for Shenzhen
  if (['00', '12', '13', '18', '15', '16', '18', '20', '30', '39', '115', '1318']
      .any((p) => code.startsWith(p))) {
    return 0;
  }

  // Single-digit fallback
  if (['5', '6', '9', '7'].any((p) => code.startsWith(p))) return 1;
  if (['4', '8'].any((p) => code.startsWith(p))) return 2;

  return 1; // default to Shanghai (matching Python)
}

/// Determine markets for a list of stock symbols.
List<(int, String)> getStockMarkets(List<String> symbols) {
  return symbols.map((s) {
    // Remove market prefix if present (matching Python symbol.strip('sh').strip('sz'))
    String code = s;
    final lowered = code.toLowerCase();
    if (lowered.startsWith('sh') || lowered.startsWith('sz') || lowered.startsWith('bj')) {
      code = code.substring(2);
    }
    final market = getStockMarket(code);
    return (market, code);
  }).toList();
}

/// Get frequency int from string or int.
/// Aligned with Python mootdx `get_frequency` (FREQUENCY list index).
int getFrequency(dynamic freq) {
  if (freq is int) return freq;
  if (freq is String) {
    final idx = FREQUENCY.indexOf(freq.toLowerCase());
    if (idx >= 0) return idx;
  }
  return 0; // default to 5-minute K-line (matching Python)
}

/// Parse a variable-length integer from binary data.
/// This is a variable-length encoding similar to UTF-8 for signed numbers.
({int value, int newPos}) getPrice(Uint8List data, int pos) {
  int posByte = 6;
  int bdata = data[pos];
  int intData = bdata & 0x3F;
  bool sign = (bdata & 0x40) != 0;

  if ((bdata & 0x80) != 0) {
    while (true) {
      pos++;
      bdata = data[pos];
      intData += (bdata & 0x7F) << posByte;
      posByte += 7;
      if ((bdata & 0x80) == 0) break;
    }
  }
  pos++;

  if (sign) intData = -intData;
  return (value: intData, newPos: pos);
}

/// Calculate price from base and diff.
double calPrice(int basePrice, int diff, double coefficient) {
  return (basePrice + diff) * coefficient;
}

/// Parse volume from raw integer.
double getVolume(int vol) {
  int logPoint = vol >> (8 * 3);
  int hleax = (vol >> (8 * 2)) & 0xFF;
  int lheax = (vol >> 8) & 0xFF;
  int lleax = vol & 0xFF;

  int dwEcx = logPoint * 2 - 0x7F;
  int dwEdx = logPoint * 2 - 0x86;
  int dwEsi = logPoint * 2 - 0x8E;
  int dwEax = logPoint * 2 - 0x96;

  int tmpEax;
  if (dwEcx < 0) {
    tmpEax = -dwEcx;
  } else {
    tmpEax = dwEcx;
  }

  double dblXmm6 = _pow2(tmpEax);
  if (dwEcx < 0) dblXmm6 = 1.0 / dblXmm6;

  double dblXmm4;
  if (hleax > 0x80) {
    int dwtmpeax = dwEdx + 1;
    double tmpdblXmm3 = _pow2(dwtmpeax);
    double dblXmm0 = _pow2(dwEdx) * 128.0;
    dblXmm0 += (hleax & 0x7F) * tmpdblXmm3;
    dblXmm4 = dblXmm0;
  } else {
    if (dwEdx >= 0) {
      dblXmm4 = _pow2(dwEdx) * hleax.toDouble();
    } else {
      dblXmm4 = (1.0 / _pow2(-dwEdx)) * hleax.toDouble();
    }
  }

  double dblXmm3 = _pow2(dwEsi) * lheax;
  double dblXmm1 = _pow2(dwEax) * lleax;

  if ((hleax & 0x80) != 0) {
    dblXmm3 *= 2.0;
    dblXmm1 *= 2.0;
  }

  return dblXmm6 + dblXmm4 + dblXmm3 + dblXmm1;
}

double _pow2(int n) {
  if (n < 0) return 1.0 / (1 << -n);
  return (1 << n).toDouble();
}

/// Parse datetime from buffer. Returns (year, month, day, hour, minute, newPos).
(int, int, int, int, int, int) getDateTime(
    int category, Uint8List buffer, int pos) {
  int minute = 0;
  int hour = 15;

  if (category < 4 || category == 7 || category == 8) {
    int zipDay = buffer.buffer.asByteData().getUint16(pos, Endian.little);
    int minutes = buffer.buffer.asByteData().getUint16(pos + 2, Endian.little);
    int month = ((zipDay % 2048) ~/ 100);
    int year = (zipDay >> 11) + 2004;
    int day = (zipDay % 2048) % 100;
    minute = minutes % 60;
    hour = minutes ~/ 60;
    pos += 4;
    return (year, month, day, hour, minute, pos);
  } else {
    int zipDay = buffer.buffer.asByteData().getUint32(pos, Endian.little);
    int month = ((zipDay % 10000) ~/ 100);
    int year = zipDay ~/ 10000;
    int day = zipDay % 100;
    pos += 4;
    return (year, month, day, hour, minute, pos);
  }
}

/// Parse time from buffer.
(int, int, int) getTime(Uint8List buffer, int pos) {
  int minutes = buffer.buffer.asByteData().getUint16(pos, Endian.little);
  int hour = minutes ~/ 60;
  int minute = minutes % 60;
  pos += 2;
  return (hour, minute, pos);
}
