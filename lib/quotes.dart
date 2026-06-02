import 'src/quotes/ext_quotes.dart';
import 'src/quotes/std_quotes.dart';

/// Quotes API factory.
///
/// ```dart
/// // Standard market (股票)
/// final quotes = await Quotes.factory(market: 'std');
///
/// // Extended market (扩展市场)
/// final quotes = await Quotes.factory(market: 'ext');
/// ```
class Quotes {
  Quotes._();

  /// Create a Quotes instance.
  /// [market] - 'std' for standard market (stocks), 'ext' for extended market.
  static Future<dynamic> factory({
    String market = 'std',
    String? host,
    int? port,
    bool autoRetry = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (market == 'ext') {
      return ExtQuotes.connect(
        host: host,
        port: port,
        autoRetry: autoRetry,
        timeout: timeout,
      );
    }

    return StdQuotes.connect(
      host: host,
      port: port,
      autoRetry: autoRetry,
      timeout: timeout,
    );
  }
}
