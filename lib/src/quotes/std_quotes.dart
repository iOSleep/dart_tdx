import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import '../../models/stock_bar.dart';
import '../../models/stock_info.dart';
import '../../models/stock_quote.dart';
import '../constants.dart';
import '../helper.dart';
import '../parser.dart';
import '../socket_client.dart';

/// Standard market quotes (股票市场实时行情).
class StdQuotes {
  final TdxSocketClient _client;
  bool _connected = false;

  StdQuotes({
    String? host,
    int? port,
    bool autoRetry = true,
    bool raiseException = false,
    Duration timeout = const Duration(seconds: 15),
  }) : _client = TdxSocketClient(
          autoRetry: autoRetry,
          raiseException: raiseException,
          timeout: timeout,
        ) {
    if (host != null && port != null) {
      // Connecting later
    }
  }

  /// 已探测到的最佳 host（进程内缓存，避免每次新建连接都全量扫描）。
  static ({String host, int port})? _cachedBest;
  /// 正在进行的 host 扫描（去重：多个并发连接共享同一次扫描结果）。
  static Future<({String host, int port})>? _scanFuture;

  /// Factory to create and connect.
  ///
  /// 若不指定 [host]/[port]，则自动从 [hqHosts] 中选择可用节点：
  /// 优先复用缓存的最佳节点；若缓存节点已失效，则扫描列表直到找到
  /// 「能连接且能正常返回数据」的节点（不再写死第一个，避免踩中坏节点）。
  static Future<StdQuotes> connect({
    String? host,
    int? port,
    bool autoRetry = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final quotes = StdQuotes(
      autoRetry: autoRetry,
      timeout: timeout,
    );

    if (host != null && port != null) {
      await quotes._connectTo(host, port);
      return quotes;
    }

    var best = _cachedBest ?? await _scanHostsDedup();
    var ok = await quotes._connectTo(best.host, best.port);
    if (!ok) {
      // 缓存节点已不可用，强制重新扫描一次
      _cachedBest = null;
      best = await _scanHostsDedup();
      ok = await quotes._connectTo(best.host, best.port);
    }
    if (ok) _cachedBest = best;
    return quotes;
  }

  /// 扫描 [hqHosts]，返回首个「能连接且能正常返回数据」的节点。
  /// 用较短超时，使不可用节点快速跳过；并发调用去重，共享同一次扫描。
  static Future<({String host, int port})> _scanHostsDedup() {
    if (_scanFuture != null) return _scanFuture!;
    final completer = Completer<({String host, int port})>();
    _scanFuture = completer.future;
    _doScan().then((v) {
      _scanFuture = null;
      completer.complete(v);
    }).catchError((e) {
      _scanFuture = null;
      completer.completeError(e);
    });
    return completer.future;
  }

  static Future<({String host, int port})> _doScan() async {
    const scanTimeout = Duration(seconds: 3);
    const batchSize = 8;
    const probeSymbol = '510300';

    final orderedHosts = <({String name, String host, int port})>[];
    final seen = <String>{};
    for (final server in [...preferredHqHosts, ...hqHosts]) {
      if (seen.add('${server.host}:${server.port}')) {
        orderedHosts.add(server);
      }
    }

    final errors = <String>[];
    for (var start = 0; start < orderedHosts.length; start += batchSize) {
      final end = min(start + batchSize, orderedHosts.length);
      final batch = orderedHosts.sublist(start, end);
      final results = await Future.wait(
        batch.map((server) => _probeHost(server, scanTimeout, probeSymbol)),
      );

      for (var i = 0; i < results.length; i++) {
        final error = results[i];
        if (error == null) {
          final server = batch[i];
          return (host: server.host, port: server.port);
        }
        errors.add('${batch[i].host}: $error');
      }
    }

    final detail = errors.isEmpty ? '' : ' (${errors.take(3).join('; ')})';
    throw Exception('No available TDX host found$detail');
  }

  /// 探测单个节点。返回 `null` 表示节点可用；否则返回失败原因。
  static Future<String?> _probeHost(
    ({String name, String host, int port}) server,
    Duration timeout,
    String probeSymbol,
  ) async {
    StdQuotes? probe;
    try {
      probe = StdQuotes(autoRetry: false, timeout: timeout);
      final ok = await probe._connectTo(server.host, server.port);
      if (!ok) return '连接失败';

      // ETF 是本库的主要使用场景；验证目标品种可避免选中仅个股可用的节点。
      final bars = await probe.bars(
        probeSymbol,
        frequency: KLineType.day,
        offset: 1,
      );
      if (bars.isEmpty) return 'bars 为空';
      return null;
    } catch (e) {
      return '$e';
    } finally {
      probe?.close();
    }
  }

  Future<bool> _connectTo(String host, int port) async {
    final ok = await _client.connect(host, port);
    if (ok) {
      await _client.setup();
      _connected = true;
    }
    return ok;
  }

  TrafficStats get traffic => _client.stats;

  bool get isConnected => _connected && !_client.isClosed;

  /// Close the connection.
  void close() {
    _client.disconnect();
    _connected = false;
  }

  /// Get real-time quotes for one or more stocks.
  /// [symbols] can be a single stock code string or a list.
  Future<List<StockQuote>> quotes(dynamic symbols) async {
    if (symbols == null) return [];
    if (symbols is! List) symbols = [symbols];

    try {
      final markets = getStockMarkets(
          symbols.map<String>((s) => s.toString()).toList());

      final result = await _client.getSecurityQuotes(markets);
      if (result.isEmpty) return [];

      return parseSecurityQuotes(result);
    } catch (_) {
      return [];
    }
  }

  /// Get K-line bars.
  Future<List<StockBar>> bars(
    String symbol, {
    dynamic frequency = KLineType.day,
    int start = 0,
    int offset = 800,
  }) async {
    final freq = getFrequency(frequency);
    final market = getStockMarket(symbol);
    final count = min(offset, Limits.maxKLineCount);

    final result =
        await _client.getSecurityBars(freq, market, symbol, start, count);
    if (result.isEmpty) return [];

    return parseSecurityBars(freq, result);
  }

  /// Get index K-line bars.
  Future<List<StockBar>> index(
    String symbol, {
    dynamic frequency = KLineType.day,
    int start = 0,
    int offset = 800,
  }) async {
    final freq = getFrequency(frequency);
    // Python: market = (MARKET_SZ, MARKET_SH)[symbol[:2] in ['00', '88', '99']]
    final clean = symbol.replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');
    final code2 = clean.length >= 2 ? clean.substring(0, 2) : '';
    final market = ['00', '88', '99'].contains(code2) ? 1 : 0;
    final count = min(offset, Limits.maxKLineCount);

    final result =
        await _client.getIndexBars(freq, market, symbol, start, count);
    if (result.isEmpty) return [];

    return parseSecurityBars(freq, result);
  }

  /// Get stock count in market.
  Future<int> stockCount(int market) async {
    if (![0, 1, 2].contains(market)) {
      throw ArgumentError('Market code must be 0 (SZ), 1 (SH), or 2 (BJ)');
    }
    final result = await _client.getSecurityCount(market);
    return parseSecurityCount(result);
  }

  /// Get security list (paginated).
  Future<List<StockInfo>> securityList(int market, int start) async {
    final result = await _client.getSecurityList(market, start);
    if (result.isEmpty) return [];
    return parseSecurityList(result);
  }

  /// Get minute time data (today).
  Future<Uint8List> minute(String symbol) async {
    final market = getStockMarket(symbol);
    return _client.getMinuteTimeData(market, symbol);
  }

  /// Get history minute time data.
  Future<Uint8List> historyMinute(String symbol, int date) async {
    final market = getStockMarket(symbol);
    return _client.getHistoryMinuteTimeData(market, symbol, date);
  }

  /// Get transaction data (today, during trading hours).
  Future<Uint8List> transaction(String symbol,
      {int start = 0, int count = 2000}) async {
    final market = getStockMarket(symbol);
    final c = min(count, Limits.maxTransactionCount);
    return _client.getTransactionData(market, symbol, start, c);
  }

  /// Get company info category.
  Future<Uint8List> companyInfoCategory(int market, String code) async {
    return _client.getCompanyInfoCategory(market, code);
  }

  /// Get company info content.
  Future<Uint8List> companyInfoContent(
      int market, String code, String filename, int start, int length) async {
    return _client.getCompanyInfoContent(
        market, code, filename, start, length);
  }

  /// Get XDXR (除息除权) info.
  Future<Uint8List> xdxrInfo(int market, String code) async {
    return _client.getXdXrInfo(market, code);
  }

  /// Get finance info.
  Future<Uint8List> financeInfo(int market, String code) async {
    return _client.getFinanceInfo(market, code);
  }

  /// Get block info meta.
  Future<Uint8List> blockInfoMeta(String blockFile) async {
    return _client.getBlockInfoMeta(blockFile);
  }

  /// Get block info.
  Future<Uint8List> blockInfo(String blockFile, int start, int size) async {
    return _client.getBlockInfo(blockFile, start, size);
  }
}
