import 'dart:math';
import 'package:dart_tdx/dart_tdx.dart';

void main() async {
  print('=== dart_tdx Example ===\n');

  // Example 1: Connect and get stock count
  print('1. Connecting to TDX server...');
  try {
    final quotes = await Quotes.factory(
      market: 'std',
      timeout: const Duration(seconds: 10),
    );

    if (quotes is StdQuotes) {
      print('   Connected successfully!');

      // Get stock count for Shanghai market
      final count = await quotes.stockCount(Market.sh);
      print('   Shanghai market stock count: $count');

      // Get K-line data for 平安银行
      print('\n2. Fetching K-line data for 000001 (平安银行)...');
      final bars = await quotes.bars('000001',
          frequency: KLineType.day, start: 0, offset: 5);

      for (final bar in bars) {
        print('   ${bar.datetime} O:${bar.open} C:${bar.close} '
            'H:${bar.high} L:${bar.low} V:${bar.vol}');
      }

      // Get real-time quotes
      print('\n3. Fetching real-time quotes...');
      final quotesList = await quotes.quotes(['000001', '600036']);
      for (final q in quotesList) {
        print('   ${q.code} Price:${q.price} Open:${q.open} '
            'High:${q.high} Low:${q.low} Vol:${q.vol}');
      }

      // Get security list
      print('\n4. Fetching security list (first 10)...');
      final stocks = await quotes.securityList(Market.sz, 0);
      for (int i = 0; i < min(10, stocks.length); i++) {
        print('   ${stocks[i].code} ${stocks[i].name}');
      }

      quotes.close();
    }
  } catch (e) {
    print('   Error: $e');
    print('   (This is expected if no TDX server is reachable)');
  }

  print('\n=== Done ===');
}
