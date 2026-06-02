import 'src/reader/std_reader.dart';

/// Reader API factory for offline TDX data files.
///
/// ```dart
/// final reader = Reader.factory(market: 'std', tdxDir: '/path/to/tdx');
/// final bars = reader.daily('600036');
/// ```
class Reader {
  Reader._();

  /// Create a Reader instance.
  /// [market] - 'std' for standard market, 'ext' for extended market.
  /// [tdxDir] - path to TDX installation directory.
  static dynamic factory({
    String market = 'std',
    required String tdxDir,
  }) {
    if (market == 'ext') {
      return StdReader(tdxDir: tdxDir); // Extended reader is same format
    }
    return StdReader(tdxDir: tdxDir);
  }
}
