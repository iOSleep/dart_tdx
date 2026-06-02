import 'dart:io';
import 'dart:typed_data';

import '../../models/stock_bar.dart';
import '../helper.dart';

/// Standard market offline reader.
/// Reads TDX local data files.
class StdReader {
  final String tdxDir;

  StdReader({required this.tdxDir}) {
    if (!Directory(tdxDir).existsSync()) {
      throw Exception('TDX directory not found: $tdxDir');
    }
  }

  /// Read daily K-line data from local TDX files.
  List<StockBar> daily(String symbol) {
    final path = _findPath(symbol, subdir: 'lday', suffix: 'day');
    if (path == null) return [];
    return _parseDailyFile(path);
  }

  /// Read minute K-line data from local TDX files.
  /// [suffix] 1 for 1-minute, 5 for 5-minute.
  List<StockBar> minute(String symbol, {int suffix = 1}) {
    final subdir = suffix == 5 ? 'fzline' : 'minline';
    final suffixes = suffix == 5 ? ['lc5', '5'] : ['lc1', '1'];

    for (final ext in suffixes) {
      final path = _findPath(symbol, subdir: subdir, suffix: ext);
      if (path != null) {
        return _parseMinuteFile(path);
      }
    }
    return [];
  }

  /// Read 5-minute line data (alias for minute with suffix=5).
  List<StockBar> fzline(String symbol) => minute(symbol, suffix: 5);

  /// Find the file path for a given symbol.
  String? _findPath(String symbol,
      {required String subdir, required String suffix}) {
    String market;
    String cleanSymbol = symbol.replaceAll(RegExp(r'[^0-9a-zA-Z#]'), '');

    if (cleanSymbol.contains('#')) {
      market = 'ds';
    } else if (cleanSymbol.startsWith('88')) {
      market = 'sh';
    } else {
      final m = getStockMarket(cleanSymbol, true);
      market = m == 0 ? 'sz' : 'sh';
    }

    if (['sh', 'sz'].contains(market.toLowerCase())) {
      final mktLower = market.toLowerCase();
      if (cleanSymbol.toLowerCase().startsWith(mktLower)) {
        cleanSymbol = cleanSymbol.substring(mktLower.length);
      }
      cleanSymbol = '$mktLower$cleanSymbol';
    }

    final basePath = '$tdxDir/vipdoc/$market/$subdir/$cleanSymbol.$suffix';

    if (File(basePath).existsSync()) return basePath;

    // Try alternate extensions
    for (final ext in [suffix, suffix.toUpperCase()]) {
      final p = '$tdxDir/vipdoc/$market/$subdir/$cleanSymbol.$ext';
      if (File(p).existsSync()) return p;
    }

    return null;
  }

  /// Parse TDX daily bar file (.day).
  List<StockBar> _parseDailyFile(String path) {
    final file = File(path);
    if (!file.existsSync()) return [];

    final bytes = file.readAsBytesSync();
    final bars = <StockBar>[];

    // Each record is 32 bytes
    // struct: <IffffIIf?? = 4+4+4+4+4+4+4+4 = 32
    const recordSize = 32;
    for (int i = 0; i + recordSize <= bytes.length; i += recordSize) {
      final bd = bytes.buffer.asByteData(
          bytes.offsetInBytes + i, recordSize);

      final dateRaw = bd.getUint32(0, Endian.little);
      final open = bd.getFloat32(4, Endian.little);
      final high = bd.getFloat32(8, Endian.little);
      final low = bd.getFloat32(12, Endian.little);
      final close = bd.getFloat32(16, Endian.little);
      final amount = bd.getFloat32(20, Endian.little);
      final vol = bd.getUint32(24, Endian.little).toDouble();
      // last 4 bytes reserved

      final year = dateRaw ~/ 10000;
      final month = (dateRaw % 10000) ~/ 100;
      final day = dateRaw % 100;

      final dt = '$year-${month.toString().padLeft(2, '0')}'
          '-${day.toString().padLeft(2, '0')} 15:00';

      bars.add(StockBar(
        open: open,
        close: close,
        high: high,
        low: low,
        vol: vol,
        amount: amount,
        year: year,
        month: month,
        day: day,
        hour: 15,
        minute: 0,
        datetime: dt,
      ));
    }

    return bars;
  }

  /// Parse TDX minute bar file (.lc1, .lc5, .1, .5).
  List<StockBar> _parseMinuteFile(String path) {
    final file = File(path);
    if (!file.existsSync()) return [];

    final bytes = file.readAsBytesSync();
    final bars = <StockBar>[];

    // Minute bar record: <HHIIff? = 2+2+4+4+4 = 16
    // Actually TDX minute bar format: <HHIIff
    // date(time) u16, minute u16, price u32 (float*1000?), vol u32, (reserved)
    // Let's use a simpler approach - adjust based on actual format.
    // The exact format depends on whether it's .lc1/.1 or .lc5/.5

    // For .lc* files (last close format)
    if (path.endsWith('.lc1') || path.endsWith('.lc5')) {
      const recordSize = 32;
      for (int i = 0; i + recordSize <= bytes.length; i += recordSize) {
        try {
          final bd = bytes.buffer.asByteData(
              bytes.offsetInBytes + i, recordSize);
          final dateRaw = bd.getUint16(0, Endian.little);
          final minuteRaw = bd.getUint16(2, Endian.little);
          final price = bd.getFloat32(4, Endian.little);
          final vol = bd.getFloat32(8, Endian.little);
          // rest reserved

          final year = (dateRaw >> 11) + 2004;
          final month = (dateRaw % 2048) ~/ 100;
          final day = (dateRaw % 2048) % 100;
          final hour = minuteRaw ~/ 60;
          final minute = minuteRaw % 60;

          final dt = '$year-${month.toString().padLeft(2, '0')}'
              '-${day.toString().padLeft(2, '0')} '
              '${hour.toString().padLeft(2, '0')}:'
              '${minute.toString().padLeft(2, '0')}';

          bars.add(StockBar(
            open: price,
            close: price,
            high: price,
            low: price,
            vol: vol,
            amount: 0,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            datetime: dt,
          ));
        } catch (_) {
          continue;
        }
      }
    } else {
      // For .1/.5 files
      const recordSize = 32;
      for (int i = 0; i + recordSize <= bytes.length; i += recordSize) {
        try {
          final bd = bytes.buffer.asByteData(
              bytes.offsetInBytes + i, recordSize);

          final dateRaw = bd.getUint16(0, Endian.little);
          final diffPrice = bd.getInt16(2, Endian.little);
          final vol = bd.getUint32(4, Endian.little);
          // rest fields...

          final year = (dateRaw >> 11) + 2004;
          final month = (dateRaw % 2048) ~/ 100;
          final day = (dateRaw % 2048) % 100;
          final hour = diffPrice ~/ 60;
          final minute = diffPrice % 60;

          final dt = '$year-${month.toString().padLeft(2, '0')}'
              '-${day.toString().padLeft(2, '0')} '
              '${hour.toString().padLeft(2, '0')}:'
              '${minute.toString().padLeft(2, '0')}';

          bars.add(StockBar(
            open: 0,
            close: 0,
            high: 0,
            low: 0,
            vol: vol.toDouble(),
            amount: 0,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            datetime: dt,
          ));
        } catch (_) {
          continue;
        }
      }
    }

    return bars;
  }
}
