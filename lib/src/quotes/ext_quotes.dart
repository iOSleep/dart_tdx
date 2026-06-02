
import '../constants.dart';
import '../socket_client.dart';

/// Extended market quotes (扩展市场实时行情 - futures, etc).
class ExtQuotes {
  final TdxSocketClient _client;
  bool _connected = false;

  ExtQuotes({
    String? host,
    int? port,
    bool autoRetry = true,
    Duration timeout = const Duration(seconds: 15),
  }) : _client = TdxSocketClient(
          autoRetry: autoRetry,
          timeout: timeout,
        );

  /// Factory to create and connect (uses first server, matching Python).
  static Future<ExtQuotes> connect({
    String? host,
    int? port,
    bool autoRetry = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final quotes = ExtQuotes(autoRetry: autoRetry, timeout: timeout);

    if (host != null && port != null) {
      await quotes._connectTo(host, port);
    } else {
      // Use first server from exHosts (matching Python: config.get('SERVER').get('EX')[0])
      final server = exHosts.first;
      await quotes._connectTo(server.host, server.port);
    }

    return quotes;
  }

  Future<bool> _connectTo(String host, int port) async {
    final ok = await _client.connect(host, port);
    if (ok) {
      _connected = true;
    }
    return ok;
  }

  TrafficStats get traffic => _client.stats;

  bool get isConnected => _connected && !_client.isClosed;

  void close() {
    _client.disconnect();
    _connected = false;
  }

  /// Get instrument count.
  Future<int> instrumentCount() async {
    return 0; // stub - extended market protocol differs
  }
}
