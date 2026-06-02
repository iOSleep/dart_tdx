/// A single K-line bar data.
class StockBar {
  final double open;
  final double close;
  final double high;
  final double low;
  final double vol;
  final double amount;
  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;
  final String datetime;

  const StockBar({
    required this.open,
    required this.close,
    required this.high,
    required this.low,
    required this.vol,
    required this.amount,
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    required this.datetime,
  });

  factory StockBar.fromJson(Map<String, dynamic> json) => StockBar(
        open: (json['open'] as num).toDouble(),
        close: (json['close'] as num).toDouble(),
        high: (json['high'] as num).toDouble(),
        low: (json['low'] as num).toDouble(),
        vol: (json['vol'] as num).toDouble(),
        amount: (json['amount'] as num).toDouble(),
        year: json['year'] as int,
        month: json['month'] as int,
        day: json['day'] as int,
        hour: json['hour'] as int,
        minute: json['minute'] as int,
        datetime: json['datetime'] as String,
      );

  Map<String, dynamic> toJson() => {
        'open': open,
        'close': close,
        'high': high,
        'low': low,
        'vol': vol,
        'amount': amount,
        'year': year,
        'month': month,
        'day': day,
        'hour': hour,
        'minute': minute,
        'datetime': datetime,
      };

  @override
  String toString() => 'StockBar($datetime O:$open C:$close H:$high L:$low V:$vol)';
}
