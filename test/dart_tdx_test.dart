import 'package:dart_tdx/dart_tdx.dart';
import 'package:test/test.dart';

void main() {
  group('Constants', () {
    test('Market constants', () {
      expect(Market.sz, 0);
      expect(Market.sh, 1);
      expect(Market.bj, 2);
    });

    test('KLineType constants', () {
      expect(KLineType.day, 4);
      expect(KLineType.week, 5);
      expect(KLineType.month, 6);
    });

    test('Server hosts available', () {
      expect(hqHosts.isNotEmpty, true);
      expect(exHosts.isNotEmpty, true);
      expect(gpHosts.isNotEmpty, true);
    });
  });

  group('Helper functions', () {
    test('getStockMarket', () {
      expect(getStockMarket('600036'), 1);
      expect(getStockMarket('000001'), 0);
      expect(getStockMarket('688001'), 1);
      expect(getStockMarket('300001'), 0);
    });

    test('getFrequency', () {
      expect(getFrequency('day'), KLineType.day);
      expect(getFrequency('1m'), KLineType.min1);
      expect(getFrequency('5m'), KLineType.min5);
      expect(getFrequency(4), KLineType.day);
    });
  });

  group('Models', () {
    test('StockBar serialization', () {
      final bar = StockBar(
        open: 10.5,
        close: 11.2,
        high: 11.5,
        low: 10.0,
        vol: 100000,
        amount: 1050000,
        year: 2024,
        month: 1,
        day: 15,
        hour: 15,
        minute: 0,
        datetime: '2024-01-15 15:00',
      );
      final json = bar.toJson();
      expect(json['open'], 10.5);
      expect(json['close'], 11.2);
    });

    test('StockQuote serialization', () {
      final quote = StockQuote(
        market: 1,
        code: '600036',
        active1: 0,
        price: 35.5,
        lastClose: 35.0,
        open: 35.1,
        high: 35.8,
        low: 34.9,
        serverTime: '09:30:00',
        vol: 500000,
        curVol: 10000,
        amount: 17750000,
        bid1: 35.4,
        ask1: 35.6,
        bidVol1: 1000,
        askVol1: 800,
        bid2: 35.3,
        ask2: 35.7,
        bidVol2: 2000,
        askVol2: 1500,
        bid3: 35.2,
        ask3: 35.8,
        bidVol3: 3000,
        askVol3: 2000,
        bid4: 35.1,
        ask4: 35.9,
        bidVol4: 4000,
        askVol4: 2500,
        bid5: 35.0,
        ask5: 36.0,
        bidVol5: 5000,
        askVol5: 3000,
        speed: 0.5,
      );
      final json = quote.toJson();
      expect(json['code'], '600036');
      expect(json['price'], 35.5);
    });
  });
}
