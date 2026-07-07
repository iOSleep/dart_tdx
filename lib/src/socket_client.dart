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
  final List<int> _buffer = [];
  /// FIFO 队列：每个正在等待数据的 [_readExactly] 在队尾入队一个 Completer，
  /// socket 监听器每收到一段数据就唤醒队首（最久等待者）。同一连接内请求虽串行，
  /// 但单段数据可能同时含"后续 header + body"，用队列可避免漏唤醒导致错位。
  final List<Completer<void>> _waiters = [];

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
          if (_waiters.isNotEmpty) {
            _waiters.removeAt(0).complete();
          }
        },
        onError: (e) {
          _closed = true;
          if (_waiters.isNotEmpty) {
            _waiters.removeAt(0).completeError(e);
          }
        },
        onDone: () {
          _closed = true;
          if (_waiters.isNotEmpty) {
            _waiters
                .removeAt(0)
                .completeError(SocketException('Connection closed'));
          }
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
  ///
  /// 采用单一接收缓冲区 [_buffer] + FIFO 唤醒队列 [_waiters] 的方案，忠实对应
  /// tdxpy 的同步 recv 循环。此前基于 `StreamController.broadcast` 的实现在
  /// setup 响应体（压缩、较大）分片到达时会漏唤醒/误消费字节，导致后续响应头
  /// 错位读取（如读到压缩流中间的 2 字节 `20 03`），彻底无法解析。
  Future<Uint8List> _readExactly(int length) async {
    if (_socket == null || _closed) {
      throw SocketException('Socket not connected');
    }

    while (_buffer.length < length) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      try {
        await waiter.future.timeout(timeout);
      } on TimeoutException {
        _waiters.remove(waiter);
        throw SocketException('Read timeout');
      }
      // 数据到达后回到循环顶部重新检查缓冲长度，避免竞态。
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

  // ---- API Commands (aligned to tdxpy protocol) ----

  /// Setup commands (handshake) — identical to tdxpy hq.py setup().
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

  /// Helpers for building packets.
  static Uint8List _hexToBytes(String hex) {
    final clean = hex.replaceAll(' ', '');
    final bytes = <int>[];
    for (int i = 0; i < clean.length; i += 2) {
      bytes.add(int.parse(clean.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  /// Minimal struct.pack in Dart: supports H(2), I(4), B(1), f(4), and s (raw bytes list).
  static Uint8List _pack(String spec, List<dynamic> values) {
    final reg = RegExp(r'(\d*)([sSHhiIbBf])');
    final matches = reg.allMatches(spec);
    final parts = <Uint8List>[];
    int vi = 0;
    for (final m in matches) {
      final cntStr = m.group(1)!;
      final type = m.group(2)!;
      final cnt = cntStr.isEmpty ? 1 : int.parse(cntStr);
      if (type == 's') {
        final val = values[vi++] as List<int>;
        final arr = Uint8List(cnt);
        for (int i = 0; i < cnt && i < val.length; i++) arr[i] = val[i];
        parts.add(arr);
      } else if (type == 'H' || type == 'h') {
        for (int i = 0; i < cnt; i++) {
          final bd = ByteData(2);
          bd.setUint16(0, (values[vi++] as num).toInt(), Endian.little);
          parts.add(Uint8List.view(bd.buffer));
        }
      } else if (type == 'I' || type == 'i') {
        for (int i = 0; i < cnt; i++) {
          final bd = ByteData(4);
          bd.setUint32(0, (values[vi++] as num).toInt(), Endian.little);
          parts.add(Uint8List.view(bd.buffer));
        }
      } else if (type == 'B' || type == 'b') {
        for (int i = 0; i < cnt; i++) {
          parts.add(Uint8List.fromList([(values[vi++] as num).toInt()]));
        }
      } else if (type == 'f') {
        for (int i = 0; i < cnt; i++) {
          final bd = ByteData(4);
          bd.setFloat32(0, (values[vi++] as num).toDouble(), Endian.little);
          parts.add(Uint8List.view(bd.buffer));
        }
      }
    }
    int total = 0;
    for (final p in parts) total += p.length;
    final result = Uint8List(total);
    int off = 0;
    for (final p in parts) {
      result.setAll(off, p);
      off += p.length;
    }
    return result;
  }

  /// Build packet from hex header + struct body.
  static Uint8List _buildPkg(String hexHeader, String spec, List<dynamic> values) {
    final header = _hexToBytes(hexHeader);
    final body = _pack(spec, values);
    final pkg = Uint8List(header.length + body.length);
    pkg.setAll(0, header);
    pkg.setAll(header.length, body);
    return pkg;
  }

  /// Get security K-line bars.
  /// Matches tdxpy GetSecurityBarsCmd: struct.pack("<HIHHHH6sHHHHIIH", ...)
  Future<Uint8List> getSecurityBars(
      int category, int market, String code, int start, int count) {
    final cb = utf8.encode(code);
    final pc = Uint8List(6);
    for (int i = 0; i < 6 && i < cb.length; i++) pc[i] = cb[i];
    return callApi(_pack("<HIHHHH6sHHHHIIH", [
      0x010C, 0x01016408, 0x001C, 0x001C, 0x052D, market,
      pc.toList(), category, 1, start, count, 0, 0, 0
    ]));
  }

  /// Get security quotes (real-time).
  /// Matches tdxpy GetSecurityQuotesCmd:
  ///   struct.pack("<HIHHIIHH", 0x010C, 0x02006320, pkgDataLen, pkgDataLen, 0x05053E, 0, 0, stockLen) + per-stock B6s
  Future<Uint8List> getSecurityQuotes(List<(int, String)> stocks) {
    final stockLen = stocks.length;
    final pkgDataLen = stockLen * 7 + 12;
    // Determine final packet size: header(22) + stockLen*7
    final hdr = _pack("<HIHHIIHH", [
      0x010C, 0x02006320, pkgDataLen, pkgDataLen, 0x0005053E, 0, 0, stockLen
    ]);
    final totalLen = hdr.length + stockLen * 7;
    final pkg = Uint8List(totalLen);
    pkg.setAll(0, hdr);
    int off = hdr.length;
    for (final s in stocks) {
      final (market, code) = s;
      final cb = utf8.encode(code);
      pkg[off] = market; off++;
      for (int i = 0; i < 6 && i < cb.length; i++) { pkg[off] = cb[i]; off++; }
      off += (6 - cb.length).clamp(0, 6); // pad remaining code bytes
    }
    return callApi(pkg);
  }

  /// Get security count.
  /// Matches tdxpy GetSecurityCountCmd:
  ///   bytearray.fromhex("0c 0c 18 6c 00 01 08 00 08 00 4e 04")
  ///   + struct.pack("<H", market) + b"\x75\xc7\x33\x01"
  Future<Uint8List> getSecurityCount(int market) {
    return callApi(_buildPkg("0c 0c 18 6c 00 01 08 00 08 00 4e 04", "<H4s",
        [market, [0x75, 0xc7, 0x33, 0x01]]));
  }

  /// Get security list.
  /// Matches tdxpy GetSecurityList:
  ///   bytearray.fromhex("0c 01 18 64 01 01 06 00 06 00 50 04")
  ///   + struct.pack("<HH", market, start)
  Future<Uint8List> getSecurityList(int market, int start) {
    return callApi(_buildPkg("0c 01 18 64 01 01 06 00 06 00 50 04", "<HH", [market, start]));
  }

  /// Get minute time data.
  /// Matches tdxpy GetMinuteTimeData:
  ///   bytearray.fromhex("0c 1b 08 00 01 01 0e 00 0e 00 1d 05")
  ///   + struct.pack("<H6sI", market, code, 0)
  Future<Uint8List> getMinuteTimeData(int market, String code) {
    final cb = utf8.encode(code);
    final pc = Uint8List(6);
    for (int i = 0; i < 6 && i < cb.length; i++) pc[i] = cb[i];
    return callApi(_buildPkg("0c 1b 08 00 01 01 0e 00 0e 00 1d 05", "<H6sI",
        [market, pc.toList(), 0]));
  }

  /// Get history minute time data.
  /// Matches tdxpy GetHistoryMinuteTimeData:
  ///   bytearray.fromhex("0c 01 30 00 01 01 0d 00 0d 00 b4 0f")
  ///   + struct.pack("<IB6s", date, market, code)
  Future<Uint8List> getHistoryMinuteTimeData(
      int market, String code, int date) {
    final cb = utf8.encode(code);
    final pc = Uint8List(6);
    for (int i = 0; i < 6 && i < cb.length; i++) pc[i] = cb[i];
    return callApi(_buildPkg("0c 01 30 00 01 01 0d 00 0d 00 b4 0f", "<IB6s",
        [date, market, pc.toList()]));
  }

  /// Get transaction data.
  /// Matches tdxpy GetTransactionData:
  ///   bytearray.fromhex("0c 17 08 01 01 01 0e 00 0e 00 c5 0f")
  ///   + struct.pack("<H6sHH", market, code, start, count)
  Future<Uint8List> getTransactionData(
      int market, String code, int start, int count) {
    final cb = utf8.encode(code);
    final pc = Uint8List(6);
    for (int i = 0; i < 6 && i < cb.length; i++) pc[i] = cb[i];
    return callApi(_buildPkg("0c 17 08 01 01 01 0e 00 0e 00 c5 0f", "<H6sHH",
        [market, pc.toList(), start, count]));
  }

  /// Get history transaction data.
  /// Matches tdxpy GetHistoryTransactionData:
  ///   bytearray.fromhex("0c 01 30 01 00 01 12 00 12 00 b5 0f")
  ///   + struct.pack("<IH6sHH", date, market, code, start, count)
  Future<Uint8List> getHistoryTransactionData(
      int market, String code, int start, int count, int date) {
    final cb = utf8.encode(code);
    final pc = Uint8List(6);
    for (int i = 0; i < 6 && i < cb.length; i++) pc[i] = cb[i];
    return callApi(_buildPkg("0c 01 30 01 00 01 12 00 12 00 b5 0f", "<IH6sHH",
        [date, market, pc.toList(), start, count]));
  }

  /// Get index bars (same packet format as getSecurityBars).
  /// Matches tdxpy GetIndexBarsCmd: struct.pack("<HIHHHH6sHHHHIIH", ...)
  Future<Uint8List> getIndexBars(
      int category, int market, String code, int start, int count) {
    final cb = utf8.encode(code);
    final pc = Uint8List(6);
    for (int i = 0; i < 6 && i < cb.length; i++) pc[i] = cb[i];
    return callApi(_pack("<HIHHHH6sHHHHIIH", [
      0x010C, 0x01016408, 0x001C, 0x001C, 0x052D, market,
      pc.toList(), category, 1, start, count, 0, 0, 0
    ]));
  }

  /// Get company info category.
  /// Matches tdxpy GetCompanyInfoCategory:
  ///   bytearray.fromhex("0c 0f 10 9b 00 01 0e 00 0e 00 cf 02")
  ///   + struct.pack("<H6sI", market, code, 0)
  Future<Uint8List> getCompanyInfoCategory(int market, String code) {
    final cb = utf8.encode(code);
    final pc = Uint8List(6);
    for (int i = 0; i < 6 && i < cb.length; i++) pc[i] = cb[i];
    return callApi(_buildPkg("0c 0f 10 9b 00 01 0e 00 0e 00 cf 02", "<H6sI",
        [market, pc.toList(), 0]));
  }

  /// Get company info content.
  /// Matches tdxpy GetCompanyInfoContent:
  ///   bytearray.fromhex("0c 07 10 9c 00 01 68 00 68 00 d0 02")
  ///   + struct.pack("<H6sH80sIII", market, code, 0, filename, start, length, 0)
  Future<Uint8List> getCompanyInfoContent(
      int market, String code, String filename, int start, int length) {
    final cb = utf8.encode(code);
    final pc = Uint8List(6);
    for (int i = 0; i < 6 && i < cb.length; i++) pc[i] = cb[i];
    final fnb = utf8.encode(filename);
    final pfn = Uint8List(80);
    for (int i = 0; i < 80 && i < fnb.length; i++) pfn[i] = fnb[i];
    return callApi(_buildPkg("0c 07 10 9c 00 01 68 00 68 00 d0 02", "<H6sH80sIII",
        [market, pc.toList(), 0, pfn.toList(), start, length, 0]));
  }

  /// Get XDXR (除息除权) info.
  /// Matches tdxpy GetXdXrInfo:
  ///   bytearray.fromhex("0c 1f 18 76 00 01 0b 00 0b 00 0f 00 01 00")
  ///   + struct.pack("<B6s", market, code)
  Future<Uint8List> getXdXrInfo(int market, String code) {
    final cb = utf8.encode(code);
    final pc = Uint8List(6);
    for (int i = 0; i < 6 && i < cb.length; i++) pc[i] = cb[i];
    return callApi(_buildPkg("0c 1f 18 76 00 01 0b 00 0b 00 0f 00 01 00", "<B6s",
        [market, pc.toList()]));
  }

  /// Get finance info.
  /// Matches tdxpy GetFinanceInfo:
  ///   bytearray.fromhex("0c 1f 18 76 00 01 0b 00 0b 00 10 00 01 00")
  ///   + struct.pack("<B6s", market, code)
  Future<Uint8List> getFinanceInfo(int market, String code) {
    final cb = utf8.encode(code);
    final pc = Uint8List(6);
    for (int i = 0; i < 6 && i < cb.length; i++) pc[i] = cb[i];
    return callApi(_buildPkg("0c 1f 18 76 00 01 0b 00 0b 00 10 00 01 00", "<B6s",
        [market, pc.toList()]));
  }

  /// Get block info meta.
  /// Matches tdxpy GetBlockInfoMeta:
  ///   bytearray.fromhex("0C 39 18 69 00 01 2A 00 2A 00 C5 02")
  ///   + struct.pack(f"<{0x2A - 2}s", blockFile)
  Future<Uint8List> getBlockInfoMeta(String blockFile) {
    final bfb = utf8.encode(blockFile);
    final pbf = Uint8List(40);
    for (int i = 0; i < 40 && i < bfb.length; i++) pbf[i] = bfb[i];
    return callApi(_buildPkg("0c 39 18 69 00 01 2a 00 2a 00 c5 02", "40s",
        [pbf.toList()]));
  }

  /// Get block info data.
  /// Matches tdxpy GetBlockInfo:
  ///   bytearray.fromhex("0c 37 18 6a 00 01 6e 00 6e 00 b9 06")
  ///   + struct.pack(f"<II{0x6E - 10}s", start, size, blockFile)
  Future<Uint8List> getBlockInfo(String blockFile, int start, int size) {
    final bfb = utf8.encode(blockFile);
    final pbf = Uint8List(100);
    for (int i = 0; i < 100 && i < bfb.length; i++) pbf[i] = bfb[i];
    return callApi(_buildPkg("0c 37 18 6a 00 01 6e 00 6e 00 b9 06", "<II100s",
        [start, size, pbf.toList()]));
  }

  /// Get report file (financial data download).
  /// Matches tdxpy GetReportFile:
  ///   bytearray.fromhex("0C 12 34 00 00 00")
  ///   + struct.pack(f"<HH{raw_data_len}s", raw_data_len, raw_data_len, raw_data)
  ///   where raw_data = struct.pack(r"<H2I100s", 0x06B9, offset, 0x7530, filename)
  Future<Uint8List> getReportFile(String filename, int offset) {
    final fnb = utf8.encode(filename);
    final pfn = Uint8List(100);
    for (int i = 0; i < 100 && i < fnb.length; i++) pfn[i] = fnb[i];
    const nodeSize = 0x7530;
    final rawData = _pack("<H2I100s", [0x06B9, offset, nodeSize, pfn.toList()]);
    final rawDataLen = rawData.length;
    final bodyHdr = _pack("<HH", [rawDataLen, rawDataLen]);
    final bodyFull = Uint8List(bodyHdr.length + rawData.length);
    bodyFull.setAll(0, bodyHdr);
    bodyFull.setAll(bodyHdr.length, rawData);
    final header = _hexToBytes("0c 12 34 00 00 00");
    final pkg = Uint8List(header.length + bodyFull.length);
    pkg.setAll(0, header);
    pkg.setAll(header.length, bodyFull);
    return callApi(pkg);
  }
}
