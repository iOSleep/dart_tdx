/// Real-time stock quote data.
class StockQuote {
  final int market;
  final String code;
  final int active1;
  final double price;
  final double lastClose;
  final double open;
  final double high;
  final double low;
  final String serverTime;
  final double vol;
  final double curVol;
  final double amount;
  final double bid1;
  final double ask1;
  final double bidVol1;
  final double askVol1;
  final double bid2;
  final double ask2;
  final double bidVol2;
  final double askVol2;
  final double bid3;
  final double ask3;
  final double bidVol3;
  final double askVol3;
  final double bid4;
  final double ask4;
  final double bidVol4;
  final double askVol4;
  final double bid5;
  final double ask5;
  final double bidVol5;
  final double askVol5;
  final double speed; // 涨速

  const StockQuote({
    required this.market,
    required this.code,
    required this.active1,
    required this.price,
    required this.lastClose,
    required this.open,
    required this.high,
    required this.low,
    required this.serverTime,
    required this.vol,
    required this.curVol,
    required this.amount,
    required this.bid1,
    required this.ask1,
    required this.bidVol1,
    required this.askVol1,
    required this.bid2,
    required this.ask2,
    required this.bidVol2,
    required this.askVol2,
    required this.bid3,
    required this.ask3,
    required this.bidVol3,
    required this.askVol3,
    required this.bid4,
    required this.ask4,
    required this.bidVol4,
    required this.askVol4,
    required this.bid5,
    required this.ask5,
    required this.bidVol5,
    required this.askVol5,
    required this.speed,
  });

  factory StockQuote.fromJson(Map<String, dynamic> json) => StockQuote(
        market: json['market'] as int,
        code: json['code'] as String,
        active1: json['active1'] as int,
        price: (json['price'] as num).toDouble(),
        lastClose: (json['last_close'] as num).toDouble(),
        open: (json['open'] as num).toDouble(),
        high: (json['high'] as num).toDouble(),
        low: (json['low'] as num).toDouble(),
        serverTime: json['servertime'] as String,
        vol: (json['vol'] as num).toDouble(),
        curVol: (json['cur_vol'] as num).toDouble(),
        amount: (json['amount'] as num).toDouble(),
        bid1: (json['bid1'] as num).toDouble(),
        ask1: (json['ask1'] as num).toDouble(),
        bidVol1: (json['bid_vol1'] as num).toDouble(),
        askVol1: (json['ask_vol1'] as num).toDouble(),
        bid2: (json['bid2'] as num).toDouble(),
        ask2: (json['ask2'] as num).toDouble(),
        bidVol2: (json['bid_vol2'] as num).toDouble(),
        askVol2: (json['ask_vol2'] as num).toDouble(),
        bid3: (json['bid3'] as num).toDouble(),
        ask3: (json['ask3'] as num).toDouble(),
        bidVol3: (json['bid_vol3'] as num).toDouble(),
        askVol3: (json['ask_vol3'] as num).toDouble(),
        bid4: (json['bid4'] as num).toDouble(),
        ask4: (json['ask4'] as num).toDouble(),
        bidVol4: (json['bid_vol4'] as num).toDouble(),
        askVol4: (json['ask_vol4'] as num).toDouble(),
        bid5: (json['bid5'] as num).toDouble(),
        ask5: (json['ask5'] as num).toDouble(),
        bidVol5: (json['bid_vol5'] as num).toDouble(),
        askVol5: (json['ask_vol5'] as num).toDouble(),
        speed: (json['speed'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'market': market,
        'code': code,
        'active1': active1,
        'price': price,
        'last_close': lastClose,
        'open': open,
        'high': high,
        'low': low,
        'servertime': serverTime,
        'vol': vol,
        'cur_vol': curVol,
        'amount': amount,
        'bid1': bid1,
        'ask1': ask1,
        'bid_vol1': bidVol1,
        'ask_vol1': askVol1,
        'bid2': bid2,
        'ask2': ask2,
        'bid_vol2': bidVol2,
        'ask_vol2': askVol2,
        'bid3': bid3,
        'ask3': ask3,
        'bid_vol3': bidVol3,
        'ask_vol3': askVol3,
        'bid4': bid4,
        'ask4': ask4,
        'bid_vol4': bidVol4,
        'ask_vol4': askVol4,
        'bid5': bid5,
        'ask5': ask5,
        'bid_vol5': bidVol5,
        'ask_vol5': askVol5,
        'speed': speed,
      };

  @override
  String toString() => 'StockQuote($code P:$price O:$open H:$high L:$low)';
}
