/// TDX market constants
class Market {
  static const int sz = 0; // 深圳
  static const int sh = 1; // 上海
  static const int bj = 2; // 北京

  static String name(int market) {
    switch (market) {
      case sz:
        return 'sz';
      case sh:
        return 'sh';
      case bj:
        return 'bj';
      default:
        return 'unknown';
    }
  }
}

/// K-line type constants
class KLineType {
  static const int min5 = 0;
  static const int min15 = 1;
  static const int min30 = 2;
  static const int hour1 = 3;
  static const int day = 4;
  static const int week = 5;
  static const int month = 6;
  static const int exMin1 = 7;
  static const int min1 = 8;
  static const int riK = 9;
  static const int month3 = 10;
  static const int year = 11;
}

/// Frequency string list (matching Python mootdx FREQUENCY constant).
const List<String> FREQUENCY = [
  '5m', '15m', '30m', '1h', 'day', 'week', 'mon',
  'ex_1m', '1m', 'dk', '3mon', 'year'
];

/// Max transaction / K-line counts
class Limits {
  static const int maxTransactionCount = 2000;
  static const int maxKLineCount = 800;
}

/// Block files
class BlockFiles {
  static const String sz = 'block_zs.dat';
  static const String fg = 'block_fg.dat';
  static const String gn = 'block_gn.dat';
  static const String defaultBlock = 'block.dat';
}

/// TDX server hosts for standard market (股票市场)
const List<({String name, String host, int port})> hqHosts = [
  (name: '深圳双线主站1', host: '110.41.147.114', port: 7709),
  (name: '深圳双线主站2', host: '8.129.13.54', port: 7709),
  (name: '深圳双线主站3', host: '120.24.149.49', port: 7709),
  (name: '深圳双线主站4', host: '47.113.94.204', port: 7709),
  (name: '深圳双线主站5', host: '8.129.174.169', port: 7709),
  (name: '深圳双线主站6', host: '110.41.154.219', port: 7709),
  (name: '上海双线主站1', host: '124.70.176.52', port: 7709),
  (name: '上海双线主站2', host: '47.100.236.28', port: 7709),
  (name: '上海双线主站3', host: '101.133.214.242', port: 7709),
  (name: '上海双线主站4', host: '47.116.21.80', port: 7709),
  (name: '上海双线主站5', host: '47.116.105.28', port: 7709),
  (name: '上海双线主站6', host: '124.70.199.56', port: 7709),
  (name: '北京双线主站1', host: '121.36.54.217', port: 7709),
  (name: '北京双线主站2', host: '121.36.81.195', port: 7709),
  (name: '北京双线主站3', host: '123.249.15.60', port: 7709),
  (name: '广州双线主站1', host: '124.71.85.110', port: 7709),
  (name: '广州双线主站2', host: '139.9.51.18', port: 7709),
  (name: '广州双线主站3', host: '139.159.239.163', port: 7709),
  (name: '上海双线主站7', host: '106.14.201.131', port: 7709),
  (name: '上海双线主站8', host: '106.14.190.242', port: 7709),
  (name: '上海双线主站9', host: '121.36.225.169', port: 7709),
  (name: '上海双线主站10', host: '123.60.70.228', port: 7709),
  (name: '上海双线主站11', host: '123.60.73.44', port: 7709),
  (name: '上海双线主站12', host: '124.70.133.119', port: 7709),
  (name: '上海双线主站13', host: '124.71.187.72', port: 7709),
  (name: '上海双线主站14', host: '124.71.187.122', port: 7709),
  (name: '武汉电信主站1', host: '119.97.185.59', port: 7709),
  (name: '深圳双线主站7', host: '47.107.64.168', port: 7709),
  (name: '北京双线主站4', host: '124.70.75.113', port: 7709),
  (name: '广州双线主站4', host: '124.71.9.153', port: 7709),
  (name: '上海双线主站15', host: '123.60.84.66', port: 7709),
  (name: '深圳双线主站8', host: '47.107.228.47', port: 7719),
  (name: '北京双线主站5', host: '120.46.186.223', port: 7709),
  (name: '北京双线主站6', host: '124.70.22.210', port: 7709),
  (name: '北京双线主站7', host: '139.9.133.247', port: 7709),
  (name: '广州双线主站5', host: '116.205.163.254', port: 7709),
  (name: '广州双线主站6', host: '116.205.171.132', port: 7709),
  (name: '广州双线主站7', host: '116.205.183.150', port: 7709),
];

/// TDX server hosts for extended market (扩展市场)
const List<({String name, String host, int port})> exHosts = [
  (name: '银河阿里云扩展行情', host: '47.112.95.207', port: 7720),
  (name: '银河杭州电信扩展行情', host: '218.75.75.18', port: 7720),
  (name: '银河武汉电信扩展行情', host: '58.49.110.76', port: 7720),
];

/// TDX server hosts for financial data (财务数据)
const List<({String name, String host, int port})> gpHosts = [
  (name: '默认财务数据线路', host: '120.76.152.87', port: 7709),
];

/// Security coefficient map
const Map<String, List<double>> securityCoefficient = {
  'SH_A_STOCK': [0.01, 0.01],
  'SH_B_STOCK': [0.001, 0.01],
  'SH_INDEX': [0.01, 1.0],
  'SH_FUND': [0.001, 1.0],
  'SH_BOND': [0.0001, 1.0],
  'SZ_A_STOCK': [0.01, 0.01],
  'SZ_B_STOCK': [0.01, 0.01],
  'SZ_INDEX': [0.01, 1.0],
  'SZ_FUND': [0.001, 0.01],
  'SZ_BOND': [0.0001, 0.01],
  'BJ_A_STOCK': [0.01, 0.01],
};
