import 'dart:typed_data';

import '../models/stock_bar.dart';
import '../models/stock_info.dart';
import '../models/stock_quote.dart';
import 'helper.dart';

/// Parse security K-line bars response.
List<StockBar> parseSecurityBars(int category, Uint8List bodyBuf) {
  int pos = 0;
  final retCount = bodyBuf.buffer.asByteData().getUint16(pos, Endian.little);
  pos += 2;

  final klines = <StockBar>[];
  int preDiffBase = 0;

  for (int i = 0; i < retCount; i++) {
    final (year, month, day, hour, minute, newPos) =
        getDateTime(category, bodyBuf, pos);
    pos = newPos;

    final openDiff = getPrice(bodyBuf, pos);
    pos = openDiff.newPos;
    final closeDiff = getPrice(bodyBuf, pos);
    pos = closeDiff.newPos;
    final highDiff = getPrice(bodyBuf, pos);
    pos = highDiff.newPos;
    final lowDiff = getPrice(bodyBuf, pos);
    pos = lowDiff.newPos;

    final volRaw =
        bodyBuf.buffer.asByteData().getUint32(pos, Endian.little);
    final vol = getVolume(volRaw);
    pos += 4;

    final amountRaw =
        bodyBuf.buffer.asByteData().getUint32(pos, Endian.little);
    final amount = getVolume(amountRaw);
    pos += 4;

    final open = (openDiff.value + preDiffBase) / 1000.0;
    final priceOpenDiff = openDiff.value + preDiffBase;
    final close = (priceOpenDiff + closeDiff.value) / 1000.0;
    final high = (priceOpenDiff + highDiff.value) / 1000.0;
    final low = (priceOpenDiff + lowDiff.value) / 1000.0;

    preDiffBase = priceOpenDiff + closeDiff.value;

    final dt = '$year-${month.toString().padLeft(2, '0')}'
        '-${day.toString().padLeft(2, '0')} '
        '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';

    klines.add(StockBar(
      open: open,
      close: close,
      high: high,
      low: low,
      vol: vol,
      amount: amount,
      year: year,
      month: month,
      day: day,
      hour: hour,
      minute: minute,
      datetime: dt,
    ));
  }

  return klines;
}

/// Parse security quotes response.
List<StockQuote> parseSecurityQuotes(Uint8List bodyBuf) {
  int pos = 0;
  pos += 2; // skip b1 cb

  final numStock = bodyBuf.buffer.asByteData().getUint16(pos, Endian.little);
  pos += 2;

  final stocks = <StockQuote>[];

  for (int i = 0; i < numStock; i++) {
    final market = bodyBuf[pos];
    final codeBytes = bodyBuf.sublist(pos + 1, pos + 7);
    final code = String.fromCharCodes(
        codeBytes.where((b) => b != 0));
    final active1 =
        bodyBuf.buffer.asByteData().getUint16(pos + 7, Endian.little);
    pos += 9;

    final priceRes = getPrice(bodyBuf, pos);
    pos = priceRes.newPos;
    final lastCloseRes = getPrice(bodyBuf, pos);
    pos = lastCloseRes.newPos;
    final openRes = getPrice(bodyBuf, pos);
    pos = openRes.newPos;
    final highRes = getPrice(bodyBuf, pos);
    pos = highRes.newPos;
    final lowRes = getPrice(bodyBuf, pos);
    pos = lowRes.newPos;

    final reversed0 = getPrice(bodyBuf, pos);
    pos = reversed0.newPos;
    final reversed1 = getPrice(bodyBuf, pos);
    pos = reversed1.newPos;
    final volRes = getPrice(bodyBuf, pos);
    pos = volRes.newPos;
    final curVolRes = getPrice(bodyBuf, pos);
    pos = curVolRes.newPos;

    final amountRaw =
        bodyBuf.buffer.asByteData().getUint32(pos, Endian.little);
    final amount = getVolume(amountRaw);
    pos += 4;

    final sVol = getPrice(bodyBuf, pos);
    pos = sVol.newPos;
    final bVol = getPrice(bodyBuf, pos);
    pos = bVol.newPos;
    final reversed2 = getPrice(bodyBuf, pos);
    pos = reversed2.newPos;
    final reversed3 = getPrice(bodyBuf, pos);
    pos = reversed3.newPos;

    final bid1 = getPrice(bodyBuf, pos);
    pos = bid1.newPos;
    final ask1 = getPrice(bodyBuf, pos);
    pos = ask1.newPos;
    final bidVol1 = getPrice(bodyBuf, pos);
    pos = bidVol1.newPos;
    final askVol1 = getPrice(bodyBuf, pos);
    pos = askVol1.newPos;

    final bid2 = getPrice(bodyBuf, pos);
    pos = bid2.newPos;
    final ask2 = getPrice(bodyBuf, pos);
    pos = ask2.newPos;
    final bidVol2 = getPrice(bodyBuf, pos);
    pos = bidVol2.newPos;
    final askVol2 = getPrice(bodyBuf, pos);
    pos = askVol2.newPos;

    final bid3 = getPrice(bodyBuf, pos);
    pos = bid3.newPos;
    final ask3 = getPrice(bodyBuf, pos);
    pos = ask3.newPos;
    final bidVol3 = getPrice(bodyBuf, pos);
    pos = bidVol3.newPos;
    final askVol3 = getPrice(bodyBuf, pos);
    pos = askVol3.newPos;

    final bid4 = getPrice(bodyBuf, pos);
    pos = bid4.newPos;
    final ask4 = getPrice(bodyBuf, pos);
    pos = ask4.newPos;
    final bidVol4 = getPrice(bodyBuf, pos);
    pos = bidVol4.newPos;
    final askVol4 = getPrice(bodyBuf, pos);
    pos = askVol4.newPos;

    final bid5 = getPrice(bodyBuf, pos);
    pos = bid5.newPos;
    final ask5 = getPrice(bodyBuf, pos);
    pos = ask5.newPos;
    final bidVol5 = getPrice(bodyBuf, pos);
    pos = bidVol5.newPos;
    final askVol5 = getPrice(bodyBuf, pos);
    pos = askVol5.newPos;

    // reversed_bytes4
    pos += 2;
    // reversed_bytes5,6,7,8
    pos += 4; // skip 4 get_price reads

    // reversed_bytes9 (speed), active2
    final reversed9 =
        bodyBuf.buffer.asByteData().getInt16(pos, Endian.little);
    pos += 2;
    pos += 2; // active2

    final coefficient = getSecurityCoefficient(market, code);

    stocks.add(StockQuote(
      market: market,
      code: code,
      active1: active1,
      price: calPrice(priceRes.value, 0, coefficient),
      lastClose:
          calPrice(priceRes.value, lastCloseRes.value, coefficient),
      open: calPrice(priceRes.value, openRes.value, coefficient),
      high: calPrice(priceRes.value, highRes.value, coefficient),
      low: calPrice(priceRes.value, lowRes.value, coefficient),
      serverTime: _formatTime(reversed0.value.toString()),
      vol: volRes.value.toDouble(),
      curVol: curVolRes.value.toDouble(),
      amount: amount,
      bid1: calPrice(priceRes.value, bid1.value, coefficient),
      ask1: calPrice(priceRes.value, ask1.value, coefficient),
      bidVol1: bidVol1.value.toDouble(),
      askVol1: askVol1.value.toDouble(),
      bid2: calPrice(priceRes.value, bid2.value, coefficient),
      ask2: calPrice(priceRes.value, ask2.value, coefficient),
      bidVol2: bidVol2.value.toDouble(),
      askVol2: askVol2.value.toDouble(),
      bid3: calPrice(priceRes.value, bid3.value, coefficient),
      ask3: calPrice(priceRes.value, ask3.value, coefficient),
      bidVol3: bidVol3.value.toDouble(),
      askVol3: askVol3.value.toDouble(),
      bid4: calPrice(priceRes.value, bid4.value, coefficient),
      ask4: calPrice(priceRes.value, ask4.value, coefficient),
      bidVol4: bidVol4.value.toDouble(),
      askVol4: askVol4.value.toDouble(),
      bid5: calPrice(priceRes.value, bid5.value, coefficient),
      ask5: calPrice(priceRes.value, ask5.value, coefficient),
      bidVol5: bidVol5.value.toDouble(),
      askVol5: askVol5.value.toDouble(),
      speed: reversed9 / 100.0,
    ));
  }

  return stocks;
}

/// Parse security list response.
List<StockInfo> parseSecurityList(Uint8List bodyBuf) {
  int pos = 0;
  final num = bodyBuf.buffer.asByteData().getUint16(pos, Endian.little);
  pos += 2;

  final symbols = <StockInfo>[];

  for (int i = 0; i < num; i++) {
    final oneBytes = bodyBuf.sublist(pos, pos + 29);
    final bd = oneBytes.buffer.asByteData();

    final codeBytes = oneBytes.sublist(0, 6);
    final code = String.fromCharCodes(codeBytes.where((b) => b != 0));
    final volUnit = bd.getUint16(6, Endian.little);
    final nameBytes = oneBytes.sublist(8, 16);
    final name = String.fromCharCodes(nameBytes.where((b) => b != 0));
    final decimalPoint = bd.getUint8(24);
    final preCloseRaw = bd.getUint32(25, Endian.little);
    final preClose = getVolume(preCloseRaw);

    pos += 29;

    symbols.add(StockInfo(
      code: code,
      volUnit: volUnit,
      decimalPoint: decimalPoint,
      name: name,
      preClose: preClose,
    ));
  }

  return symbols;
}

/// Parse security count response.
int parseSecurityCount(Uint8List bodyBuf) {
  if (bodyBuf.length < 2) return 0;
  return bodyBuf.buffer.asByteData().getUint16(0, Endian.little);
}

/// Format time string from server time integer.
String _formatTime(String timeStamp) {
  if (timeStamp.isEmpty || timeStamp == '0') return timeStamp;
  final ts = timeStamp.padLeft(8, '0');

  String time = '${ts.substring(0, 2)}:';

  final last6 = ts.substring(2);
  if (int.parse(last6.substring(0, 2)) < 60) {
    time += '${last6.substring(0, 2)}:';
    time += (int.parse(last6.substring(2)) * 60 / 10000.0)
        .toStringAsFixed(3);
  } else {
    final totalMin = int.parse(last6);
    final h = (totalMin * 60 / 1000000).floor();
    final remain =
        (totalMin * 60 % 1000000) * 60 / 1000000.0;
    time += '${h.toString().padLeft(2, '0')}:';
    time += remain.toStringAsFixed(3).padLeft(6, '0');
  }

  return time;
}
