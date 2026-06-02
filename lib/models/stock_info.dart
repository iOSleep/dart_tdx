/// Basic stock information.
class StockInfo {
  final String code;
  final int volUnit;
  final int decimalPoint;
  final String name;
  final double preClose;

  const StockInfo({
    required this.code,
    required this.volUnit,
    required this.decimalPoint,
    required this.name,
    required this.preClose,
  });

  factory StockInfo.fromJson(Map<String, dynamic> json) => StockInfo(
        code: json['code'] as String,
        volUnit: json['volunit'] as int,
        decimalPoint: json['decimal_point'] as int,
        name: json['name'] as String,
        preClose: (json['pre_close'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'volunit': volUnit,
        'decimal_point': decimalPoint,
        'name': name,
        'pre_close': preClose,
      };

  @override
  String toString() => 'StockInfo($code $name)';
}

/// Minute transaction data.
class MinuteData {
  final double price;
  final double vol;
  final int hour;
  final int minute;

  const MinuteData({
    required this.price,
    required this.vol,
    required this.hour,
    required this.minute,
  });

  factory MinuteData.fromJson(Map<String, dynamic> json) => MinuteData(
        price: (json['price'] as num).toDouble(),
        vol: (json['vol'] as num).toDouble(),
        hour: json['hour'] as int,
        minute: json['minute'] as int,
      );

  Map<String, dynamic> toJson() => {
        'price': price,
        'vol': vol,
        'hour': hour,
        'minute': minute,
      };
}

/// Transaction tick data.
class TransactionData {
  final String time;
  final double price;
  final double vol;
  final double amount;
  final int buySell; // 0=sell, 1=buy

  const TransactionData({
    required this.time,
    required this.price,
    required this.vol,
    required this.amount,
    required this.buySell,
  });

  factory TransactionData.fromJson(Map<String, dynamic> json) =>
      TransactionData(
        time: json['time'] as String,
        price: (json['price'] as num).toDouble(),
        vol: (json['vol'] as num).toDouble(),
        amount: (json['amount'] as num).toDouble(),
        buySell: json['buy_sell'] as int,
      );

  Map<String, dynamic> toJson() => {
        'time': time,
        'price': price,
        'vol': vol,
        'amount': amount,
        'buy_sell': buySell,
      };
}

/// Block data.
class BlockData {
  final String name;
  final List<String> codes;

  const BlockData({required this.name, required this.codes});

  Map<String, dynamic> toJson() => {
        'name': name,
        'codes': codes,
      };
}
