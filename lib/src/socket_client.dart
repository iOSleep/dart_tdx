import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';


/// Traffic statistics.
class TrafficStats {
  int sendPkgNum = 0;
  int recvPkgNum = 0;
  int sendPkgBytes = 0;
  int recvPkgBytes = 0;
  DateTime? firstPkgSendTime;
  int lastApiSendBytes = 0;
  int lastApiRecvBytes = 0;

  Map<String, dynamic> toMap() {
    int? totalSeconds;
    double? sendBytesPerSecond;
    double? recvBytesPerSecond;

    if (firstPkgSendTime != null) {
      final ts = DateTime.now().difference(firstPkgSendTime!).inSeconds;
      totalSeconds = ts;
      if (ts != 0) {
        sendBytesPerSecond = sendPkgBytes / ts;
        recvBytesPerSecond = recvPkgBytes / ts;
      }
    }

    return {
      'send_pkg_num': sendPkgNum,
      'recv_pkg_num': recvPkgNum,
      'send_pkg_bytes': sendPkgBytes,
      'recv_pkg_bytes': recvPkgBytes,
      'first_pkg_send_time': firstPkgSendTime?.toIso8601String(),
      'total_seconds': totalSeconds,
      'send_bytes_per_second': sendBytesPerSecond,
      'recv_bytes_per_second': recvBytesPerSecond,
      'last_api_send_bytes': lastApiSendBytes,
      'last_api_recv_bytes': lastApiRecvBytes,
    };
  }
}

/// TDX socket client for communicating with TDX servers.
class TdxSocketClient {
  Socket? _socket;
  bool _closed = true;
  String? _ip;
  int? _port;
  StreamSubscription<Uint8List>? _subscription;
  final _dataController = StreamController<Uint8List>.broadcast();
  final List<int> _buffer = [];

  final TrafficStats stats = TrafficStats();
  final bool autoRetry;
  final bool raiseException;
  final Duration timeout;

  Timer? _heartbeatTimer;

  TdxSocketClient({
    this.autoRetry = true,
    this.raiseException = false,
    this.timeout = const Duration(seconds: 15),
  });

  bool get isClosed => _closed;
  String? get ip => _ip;
  int? get port => _port;

  /// Connect to TDX server.
  Future<bool> connect(String ip, int port) async {
    _ip = ip;
    _port = port;

    try {
      _socket = await Socket.connect(
        ip,
        port,
        timeout: timeout,
      );
      _closed = false;
      _buffer.clear();

      _subscription = _socket!.listen(
        (data) {
          _buffer.addAll(data);
          _dataController.add(Uint8List.fromList(data));
        },
        onError: (e) {
          _closed = true;
          _dataController.addError(e);
        },
        onDone: () {
          _closed = true;
        },
      );

      return true;
    } on SocketException {
      _closed = true;
      if (raiseException) rethrow;
      return false;
    } on TimeoutException {
      _closed = true;
      if (raiseException) {
        throw SocketException('Connection timeout');
      }
      return false;
    }
  }

  /// Disconnect from server.
  void disconnect() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _subscription?.cancel();
    _subscription = null;

    try {
      _socket?.destroy();
    } catch (_) {}
    _socket = null;
    _buffer.clear();
    _closed = true;
  }

  void close() => disconnect();

  /// Reconnect to the server.
  Future<bool> reconnect() async {
    if (!_closed || _ip == null || _port == null) return false;
    return connect(_ip!, _port!);
  }

  /// Start sending heartbeat packets.
  void startHeartbeat(Duration interval) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(interval, (_) {
      _sendHeartbeat();
    });
  }

  void _sendHeartbeat() {
    try {
      getSecurityCount(Random().nextInt(1));
    } catch (_) {}
  }

  /// Read exactly [length] bytes from the socket buffer.
  Future<Uint8List> _readExactly(int length) async {
    if (_socket == null || _closed) {
      throw SocketException('Socket not connected');
    }

    while (_buffer.length < length) {
      final completer = Completer<void>();
      late StreamSubscription<Uint8List> sub;
      sub = _dataController.stream.listen(
        (_) {
          if (_buffer.length >= length && !completer.isCompleted) {
            completer.complete();
            sub.cancel();
          }
        },
        onError: (e) {
          if (!completer.isCompleted) {
            completer.completeError(e);
            sub.cancel();
          }
        },
      );

      if (_buffer.length >= length && !completer.isCompleted) {
        completer.complete();
        sub.cancel();
      }

      try {
        await completer.future.timeout(timeout);
      } on TimeoutException {
        sub.cancel();
        throw SocketException('Read timeout');
      }
    }

    final result = Uint8List.fromList(_buffer.sublist(0, length));
    _buffer.removeRange(0, length);
    return result;
  }

  /// Call API: sends a request and receives the response.
  Future<Uint8List> callApi(Uint8List sendPkg) async {
    return _callApiInternal(sendPkg, 0);
  }

  Future<Uint8List> _callApiInternal(
      Uint8List sendPkg, int retryCount) async {
    if (_socket == null || _closed) {
      if (autoRetry && retryCount < 3) {
        if (await reconnect()) {
          return _callApiInternal(sendPkg, retryCount + 1);
        }
      }
      if (raiseException) {
        throw SocketException('Socket client not ready');
      }
      return Uint8List(0);
    }

    try {
      _socket!.add(sendPkg);
      await _socket!.flush();

      stats.sendPkgNum++;
      stats.sendPkgBytes += sendPkg.length;
      stats.lastApiSendBytes = sendPkg.length;
      stats.firstPkgSendTime ??= DateTime.now();

      // Receive header (16 bytes)
      const headerLen = 0x10;
      final headBuf = await _readExactly(headerLen);

      stats.recvPkgNum++;
      stats.recvPkgBytes += headerLen;

      // Parse header: <IIIHH (4+4+4+2+2 = 16)
      final bd = headBuf.buffer.asByteData();
      final zipSize = bd.getUint16(12, Endian.little);
      final unzipSize = bd.getUint16(14, Endian.little);

      Uint8List bodyBuf;
      if (zipSize > 0) {
        bodyBuf = await _readExactly(zipSize);
        stats.recvPkgNum++;
        stats.recvPkgBytes += bodyBuf.length;
        stats.lastApiRecvBytes = headerLen + bodyBuf.length;

        if (zipSize != unzipSize) {
          bodyBuf = Uint8List.fromList(
              _zlibDecompress(bodyBuf));
        }
      } else {
        bodyBuf = Uint8List(0);
        stats.lastApiRecvBytes = headerLen;
      }

      return bodyBuf;
    } on SocketException {
      if (autoRetry && retryCount < 3) {
        await Future.delayed(Duration(milliseconds: 500 * (retryCount + 1)));
        if (await reconnect()) {
          return _callApiInternal(sendPkg, retryCount + 1);
        }
      }
      if (raiseException) rethrow;
      return Uint8List(0);
    }
  }

  /// Decompress zlib data.
  List<int> _zlibDecompress(Uint8List data) {
    try {
      final decompressed = ZLibDecoder().convert(data);
      return decompressed;
    } catch (_) {
      // Try raw deflate (no zlib header)
      try {
        final decompressed =
            ZLibDecoder(raw: true).convert(data);
        return decompressed;
      } catch (_) {
        return data.toList();
      }
    }
  }

  // ---- API Commands ----

  /// Setup commands (handshake).
  Future<void> setup() async {
    await callApi(Uint8List.fromList([
      0x0c, 0x02, 0x18, 0x93, 0x00, 0x01, 0x03, 0x00,
      0x03, 0x00, 0x0d, 0x00, 0x01
    ]));
    await callApi(Uint8List.fromList([
      0x0c, 0x02, 0x18, 0x94, 0x00, 0x01, 0x03, 0x00,
      0x03, 0x00, 0x0d, 0x00, 0x02
    ]));
    await callApi(Uint8List.fromList([
      0x0c, 0x03, 0x18, 0x99, 0x00, 0x01, 0x20, 0x00,
      0x20, 0x00, 0xdb, 0x0f, 0xd5, 0xd0, 0xc9, 0xcc,
      0xd6, 0xa4, 0xa8, 0xaf, 0x00, 0x00, 0x00, 0x8f,
      0xc2, 0x25, 0x40, 0x13, 0x00, 0x00, 0xd5, 0x00,
      0xc9, 0xcc, 0xbd, 0xf0, 0xd7, 0xea, 0x00, 0x00,
      0x00, 0x02
    ]));
  }

  /// Get security K-line bars.
  Future<Uint8List> getSecurityBars(
      int category, int market, String code, int start, int count) {
    final codeBytes = utf8.encode(code);
    final pkg = ByteData(38);
    int o = 0;

    pkg.setUint16(o, 0x010C, Endian.little); o += 2;
    pkg.setUint32(o, 0x01016408, Endian.little); o += 4;
    pkg.setUint16(o, 0x001C, Endian.little); o += 2;
    pkg.setUint16(o, 0x001C, Endian.little); o += 2;
    pkg.setUint16(o, 0x052D, Endian.little); o += 2;
    pkg.setUint16(o, market, Endian.little); o += 2;

    for (int i = 0; i < 6; i++) {
      pkg.setUint8(o + i, i < codeBytes.length ? codeBytes[i] : 0);
    }
    o += 6;

    pkg.setUint16(o, category, Endian.little); o += 2;
    pkg.setUint16(o, 1, Endian.little); o += 2;
    pkg.setUint16(o, start, Endian.little); o += 2;
    pkg.setUint16(o, count, Endian.little); o += 2;
    pkg.setUint32(o, 0, Endian.little); o += 4;
    pkg.setUint32(o, 0, Endian.little); o += 4;
    pkg.setUint16(o, 0, Endian.little); o += 2;

    return callApi(Uint8List.view(pkg.buffer, 0, o));
  }

  /// Get security quotes (real-time).
  Future<Uint8List> getSecurityQuotes(List<(int, String)> stocks) {
    final stockLen = stocks.length;
    final pkgDataLen = stockLen * 7 + 12;

    final pkg = ByteData(pkgDataLen);
    int o = 0;

    pkg.setUint16(o, 0x010C, Endian.little); o += 2;
    pkg.setUint32(o, 0x02006320, Endian.little); o += 4;
    pkg.setUint16(o, pkgDataLen, Endian.little); o += 2;
    pkg.setUint16(o, pkgDataLen, Endian.little); o += 2;
    pkg.setUint32(o, 0x0005053E, Endian.little); o += 4;
    o += 4;
    pkg.setUint16(o, stockLen, Endian.little); o += 2;

    for (final stock in stocks) {
      final (market, code) = stock;
      final codeBytes = utf8.encode(code);
      pkg.setUint8(o, market); o += 1;
      for (int i = 0; i < 6; i++) {
        pkg.setUint8(o + i, i < codeBytes.length ? codeBytes[i] : 0);
      }
      o += 6;
    }

    return callApi(Uint8List.view(pkg.buffer, 0, pkgDataLen));
  }

  /// Get security count.
  Future<Uint8List> getSecurityCount(int market) {
    final pkg = ByteData(18);
    int o = 0;

    pkg.setUint16(o, 0x010C, Endian.little); o += 2;
    pkg.setUint32(o, 0x01016408, Endian.little); o += 4;
    pkg.setUint16(o, 0x0006, Endian.little); o += 2;
    pkg.setUint16(o, 0x0006, Endian.little); o += 2;
    pkg.setUint32(o, 0x00045068, Endian.little); o += 4;
    pkg.setUint16(o, market, Endian.little); o += 2;

    return callApi(Uint8List.view(pkg.buffer, 0, o));
  }

  /// Get security list.
  Future<Uint8List> getSecurityList(int market, int start) {
    final base = Uint8List.fromList(
        [0x0c, 0x01, 0x18, 0x64, 0x01, 0x01, 0x06, 0x00, 0x06, 0x00, 0x50, 0x04]);
    final extra = ByteData(4);
    extra.setUint16(0, market, Endian.little);
    extra.setUint16(2, start, Endian.little);

    final pkg = Uint8List(base.length + 4);
    pkg.setAll(0, base);
    pkg.setAll(base.length, Uint8List.view(extra.buffer));
    return callApi(pkg);
  }

  /// Get minute time data.
  Future<Uint8List> getMinuteTimeData(int market, String code) {
    final codeBytes = utf8.encode(code);
    final pkg = ByteData(26);
    int o = 0;

    pkg.setUint16(o, 0x010C, Endian.little); o += 2;
    pkg.setUint32(o, 0x01016408, Endian.little); o += 4;
    pkg.setUint16(o, 0x000E, Endian.little); o += 2;
    pkg.setUint16(o, 0x000E, Endian.little); o += 2;
    pkg.setUint32(o, 0x0001505C, Endian.little); o += 4;
    pkg.setUint16(o, market, Endian.little); o += 2;

    for (int i = 0; i < 6; i++) {
      pkg.setUint8(o + i, i < codeBytes.length ? codeBytes[i] : 0);
    }
    o += 6;

    return callApi(Uint8List.view(pkg.buffer, 0, o));
  }

  /// Get history minute time data.
  Future<Uint8List> getHistoryMinuteTimeData(
      int market, String code, int date) {
    final codeBytes = utf8.encode(code);
    final pkg = ByteData(28);
    int o = 0;

    pkg.setUint16(o, 0x010C, Endian.little); o += 2;
    pkg.setUint32(o, 0x01016408, Endian.little); o += 4;
    pkg.setUint16(o, 0x0012, Endian.little); o += 2;
    pkg.setUint16(o, 0x0012, Endian.little); o += 2;
    pkg.setUint32(o, 0x0002505C, Endian.little); o += 4;
    pkg.setUint16(o, market, Endian.little); o += 2;

    for (int i = 0; i < 6; i++) {
      pkg.setUint8(o + i, i < codeBytes.length ? codeBytes[i] : 0);
    }
    o += 6;

    pkg.setUint16(o, date, Endian.little); o += 2;

    return callApi(Uint8List.view(pkg.buffer, 0, o));
  }

  /// Get transaction data.
  Future<Uint8List> getTransactionData(
      int market, String code, int start, int count) {
    final codeBytes = utf8.encode(code);
    final pkg = ByteData(32);
    int o = 0;

    pkg.setUint16(o, 0x010C, Endian.little); o += 2;
    pkg.setUint32(o, 0x01016408, Endian.little); o += 4;
    pkg.setUint16(o, 0x0014, Endian.little); o += 2;
    pkg.setUint16(o, 0x0014, Endian.little); o += 2;
    pkg.setUint32(o, 0x0000506C, Endian.little); o += 4;
    pkg.setUint16(o, market, Endian.little); o += 2;

    for (int i = 0; i < 6; i++) {
      pkg.setUint8(o + i, i < codeBytes.length ? codeBytes[i] : 0);
    }
    o += 6;

    pkg.setUint16(o, start, Endian.little); o += 2;
    pkg.setUint16(o, count, Endian.little); o += 2;

    return callApi(Uint8List.view(pkg.buffer, 0, o));
  }

  /// Get history transaction data.
  Future<Uint8List> getHistoryTransactionData(
      int market, String code, int start, int count, int date) {
    final codeBytes = utf8.encode(code);
    final pkg = ByteData(34);
    int o = 0;

    pkg.setUint16(o, 0x010C, Endian.little); o += 2;
    pkg.setUint32(o, 0x01016408, Endian.little); o += 4;
    pkg.setUint16(o, 0x0016, Endian.little); o += 2;
    pkg.setUint16(o, 0x0016, Endian.little); o += 2;
    pkg.setUint32(o, 0x0001506C, Endian.little); o += 4;
    pkg.setUint16(o, market, Endian.little); o += 2;

    for (int i = 0; i < 6; i++) {
      pkg.setUint8(o + i, i < codeBytes.length ? codeBytes[i] : 0);
    }
    o += 6;

    pkg.setUint16(o, start, Endian.little); o += 2;
    pkg.setUint16(o, count, Endian.little); o += 2;
    pkg.setUint16(o, date, Endian.little); o += 2;

    return callApi(Uint8List.view(pkg.buffer, 0, o));
  }

  /// Get index bars.
  Future<Uint8List> getIndexBars(
      int category, int market, String code, int start, int count) {
    final codeBytes = utf8.encode(code);
    final pkg = ByteData(38);
    int o = 0;

    pkg.setUint16(o, 0x010C, Endian.little); o += 2;
    pkg.setUint32(o, 0x01016408, Endian.little); o += 4;
    pkg.setUint16(o, 0x001C, Endian.little); o += 2;
    pkg.setUint16(o, 0x001C, Endian.little); o += 2;
    pkg.setUint32(o, 0x0005505C, Endian.little); o += 4;
    pkg.setUint16(o, market, Endian.little); o += 2;

    for (int i = 0; i < 6; i++) {
      pkg.setUint8(o + i, i < codeBytes.length ? codeBytes[i] : 0);
    }
    o += 6;

    pkg.setUint16(o, category, Endian.little); o += 2;
    pkg.setUint16(o, 1, Endian.little); o += 2;
    pkg.setUint16(o, start, Endian.little); o += 2;
    pkg.setUint16(o, count, Endian.little); o += 2;
    pkg.setUint32(o, 0, Endian.little); o += 4;
    pkg.setUint16(o, 0, Endian.little); o += 2;

    return callApi(Uint8List.view(pkg.buffer, 0, o));
  }

  /// Get company info category.
  Future<Uint8List> getCompanyInfoCategory(int market, String code) {
    final codeBytes = utf8.encode(code);
    final pkg = ByteData(26);
    int o = 0;

    pkg.setUint16(o, 0x010C, Endian.little); o += 2;
    pkg.setUint32(o, 0x01016408, Endian.little); o += 4;
    pkg.setUint16(o, 0x000E, Endian.little); o += 2;
    pkg.setUint16(o, 0x000E, Endian.little); o += 2;
    pkg.setUint32(o, 0x0001506E, Endian.little); o += 4;
    pkg.setUint16(o, market, Endian.little); o += 2;

    for (int i = 0; i < 6; i++) {
      pkg.setUint8(o + i, i < codeBytes.length ? codeBytes[i] : 0);
    }
    o += 6;

    return callApi(Uint8List.view(pkg.buffer, 0, o));
  }

  /// Get company info content.
  Future<Uint8List> getCompanyInfoContent(
      int market, String code, String filename, int start, int length) {
    final codeBytes = utf8.encode(code);
    final filenameBytes = utf8.encode(filename);

    final headerLen = 2 + 4 + 2 + 2 + 4 + 2 + 6 + 80 + 2 + 2;
    final pkg = ByteData(headerLen);
    int o = 0;

    pkg.setUint16(o, 0x010C, Endian.little); o += 2;
    pkg.setUint32(o, 0x01016408, Endian.little); o += 4;
    pkg.setUint16(o, headerLen - 10, Endian.little); o += 2;
    pkg.setUint16(o, headerLen - 10, Endian.little); o += 2;
    pkg.setUint32(o, 0x0002506E, Endian.little); o += 4;
    pkg.setUint16(o, market, Endian.little); o += 2;

    for (int i = 0; i < 6; i++) {
      pkg.setUint8(o + i, i < codeBytes.length ? codeBytes[i] : 0);
    }
    o += 6;

    for (int i = 0; i < 80; i++) {
      pkg.setUint8(o + i, i < filenameBytes.length ? filenameBytes[i] : 0);
    }
    o += 80;

    pkg.setUint16(o, start, Endian.little); o += 2;
    pkg.setUint16(o, length, Endian.little); o += 2;

    return callApi(Uint8List.view(pkg.buffer, 0, o));
  }

  /// Get XDXR (除息除权) info.
  Future<Uint8List> getXdXrInfo(int market, String code) {
    final codeBytes = utf8.encode(code);
    final pkg = ByteData(26);
    int o = 0;

    pkg.setUint16(o, 0x010C, Endian.little); o += 2;
    pkg.setUint32(o, 0x01016408, Endian.little); o += 4;
    pkg.setUint16(o, 0x000E, Endian.little); o += 2;
    pkg.setUint16(o, 0x000E, Endian.little); o += 2;
    pkg.setUint32(o, 0x0002506C, Endian.little); o += 4;
    pkg.setUint16(o, market, Endian.little); o += 2;

    for (int i = 0; i < 6; i++) {
      pkg.setUint8(o + i, i < codeBytes.length ? codeBytes[i] : 0);
    }
    o += 6;

    return callApi(Uint8List.view(pkg.buffer, 0, o));
  }

  /// Get finance info.
  Future<Uint8List> getFinanceInfo(int market, String code) {
    final codeBytes = utf8.encode(code);
    final pkg = ByteData(26);
    int o = 0;

    pkg.setUint16(o, 0x010C, Endian.little); o += 2;
    pkg.setUint32(o, 0x01016408, Endian.little); o += 4;
    pkg.setUint16(o, 0x000E, Endian.little); o += 2;
    pkg.setUint16(o, 0x000E, Endian.little); o += 2;
    pkg.setUint32(o, 0x0003506C, Endian.little); o += 4;
    pkg.setUint16(o, market, Endian.little); o += 2;

    for (int i = 0; i < 6; i++) {
      pkg.setUint8(o + i, i < codeBytes.length ? codeBytes[i] : 0);
    }
    o += 6;

    return callApi(Uint8List.view(pkg.buffer, 0, o));
  }

  /// Get block info meta.
  Future<Uint8List> getBlockInfoMeta(String blockFile) {
    final blockBytes = utf8.encode(blockFile);
    final dataLen = 8 + blockBytes.length + 1;
    final pkgDataLen = 10 + dataLen;

    final pkg = ByteData(pkgDataLen);
    int o = 0;

    pkg.setUint16(o, 0x010C, Endian.little); o += 2;
    pkg.setUint32(o, 0x01016408, Endian.little); o += 4;
    pkg.setUint16(o, dataLen, Endian.little); o += 2;
    pkg.setUint16(o, dataLen, Endian.little); o += 2;
    pkg.setUint32(o, 0x0100506C, Endian.little); o += 4;
    o += 2;
    for (int i = 0; i < blockBytes.length; i++) {
      pkg.setUint8(o + i, blockBytes[i]);
    }
    o += blockBytes.length;
    pkg.setUint8(o, 0); o += 1;

    return callApi(Uint8List.view(pkg.buffer, 0, o));
  }

  /// Get block info data.
  Future<Uint8List> getBlockInfo(String blockFile, int start, int size) {
    final blockBytes = utf8.encode(blockFile);
    final dataLen = 8 + blockBytes.length + 1;
    final pkgDataLen = 10 + dataLen;

    final pkg = ByteData(pkgDataLen);
    int o = 0;

    pkg.setUint16(o, 0x010C, Endian.little); o += 2;
    pkg.setUint32(o, 0x01016408, Endian.little); o += 4;
    pkg.setUint16(o, dataLen, Endian.little); o += 2;
    pkg.setUint16(o, dataLen, Endian.little); o += 2;
    pkg.setUint32(o, 0x0200506C, Endian.little); o += 4;
    o += 2;
    for (int i = 0; i < blockBytes.length; i++) {
      pkg.setUint8(o + i, blockBytes[i]);
    }
    o += blockBytes.length;
    pkg.setUint8(o, 0); o += 1;

    return callApi(Uint8List.view(pkg.buffer, 0, o));
  }

  /// Get report file (financial data download).
  Future<Uint8List> getReportFile(String filename, int offset) {
    final fnBytes = utf8.encode(filename);
    final pkgLen = 2 + 4 + 2 + 2 + 4 + 80 + 2 + 2;
    final pkg = ByteData(pkgLen);
    int o = 0;

    pkg.setUint16(o, 0x010C, Endian.little); o += 2;
    pkg.setUint32(o, 0x01016408, Endian.little); o += 4;
    pkg.setUint16(o, pkgLen, Endian.little); o += 2;
    pkg.setUint16(o, pkgLen, Endian.little); o += 2;
    pkg.setUint32(o, 0x0000506D, Endian.little); o += 4;

    for (int i = 0; i < 80; i++) {
      pkg.setUint8(o + i, i < fnBytes.length ? fnBytes[i] : 0);
    }
    o += 80;

    pkg.setUint16(o, offset, Endian.little); o += 2;
    pkg.setUint16(o, 0, Endian.little); o += 2;

    return callApi(Uint8List.view(pkg.buffer, 0, o));
  }
}
