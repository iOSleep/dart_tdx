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

/// 近期实测可优先探测的行情节点。
/// 节点会随时间失效，因此只用于缩短首次扫描路径；全部失败时仍会回退扫描 [hqHosts]。
const List<({String name, String host, int port})> preferredHqHosts = [
  (name: '国泰君安_18', host: '117.34.114.18', port: 7709),
  (name: '国泰君安_27', host: '117.34.114.27', port: 7709),
  (name: '国泰君安_14', host: '117.34.114.14', port: 7709),
  (name: '国泰君安_20', host: '117.34.114.20', port: 7709),
  (name: '国泰君安_17', host: '117.34.114.17', port: 7709),
  (name: '国泰君安_16', host: '117.34.114.16', port: 7709),
  (name: '国泰君安_15', host: '117.34.114.15', port: 7709),
  (name: '安信_11', host: '59.36.5.11', port: 7709),
];

/// TDX server hosts for standard market (股票市场)
const List<({String name, String host, int port})> hqHosts = [
(name: 'hq_0', host: '218.85.139.19', port: 7709),
  (name: 'hq_1', host: '218.85.139.20', port: 7709),
  (name: 'hq_2', host: '58.23.131.163', port: 7709),
  (name: 'hq_3', host: '218.6.170.47', port: 7709),
  (name: 'hq_4', host: '123.125.108.14', port: 7709),
  (name: 'hq_5', host: '180.153.18.170', port: 7709),
  (name: 'hq_6', host: '180.153.18.171', port: 7709),
  (name: 'hq_7', host: '180.153.18.172', port: 80),
  (name: 'hq_8', host: '202.108.253.130', port: 7709),
  (name: 'hq_9', host: '202.108.253.131', port: 7709),
  (name: 'hq_10', host: '202.108.253.139', port: 80),
  (name: 'hq_11', host: '60.191.117.167', port: 7709),
  (name: 'hq_12', host: '115.238.56.198', port: 7709),
  (name: 'hq_13', host: '218.75.126.9', port: 7709),
  (name: 'hq_14', host: '115.238.90.165', port: 7709),
  (name: 'hq_15', host: '124.160.88.183', port: 7709),
  (name: 'hq_16', host: '60.12.136.250', port: 7709),
  (name: 'hq_17', host: '218.108.98.244', port: 7709),
  (name: 'hq_18', host: '218.108.47.69', port: 7709),
  (name: 'hq_19', host: '223.94.89.115', port: 7709),
  (name: 'hq_20', host: '218.57.11.101', port: 7709),
  (name: 'hq_21', host: '58.58.33.123', port: 7709),
  (name: 'hq_22', host: '14.17.75.71', port: 7709),
  (name: 'hq_23', host: '114.80.63.12', port: 7709),
  (name: 'hq_24', host: '114.80.63.35', port: 7709),
  (name: 'hq_25', host: '180.153.39.51', port: 7709),
  (name: 'hq_26', host: '119.147.212.81', port: 7709),
  (name: 'hq_27', host: '221.231.141.60', port: 7709),
  (name: 'hq_28', host: '101.227.73.20', port: 7709),
  (name: 'hq_29', host: '101.227.77.254', port: 7709),
  (name: 'hq_30', host: '14.215.128.18', port: 7709),
  (name: 'hq_31', host: '59.173.18.140', port: 7709),
  (name: 'hq_32', host: '60.28.23.80', port: 7709),
  (name: 'hq_33', host: '218.60.29.136', port: 7709),
  (name: 'hq_34', host: '122.192.35.44', port: 7709),
  (name: 'hq_35', host: '112.95.140.74', port: 7709),
  (name: 'hq_36', host: '112.95.140.92', port: 7709),
  (name: 'hq_37', host: '112.95.140.93', port: 7709),
  (name: 'hq_38', host: '114.80.149.19', port: 7709),
  (name: 'hq_39', host: '114.80.149.21', port: 7709),
  (name: 'hq_40', host: '114.80.149.22', port: 7709),
  (name: 'hq_41', host: '114.80.149.91', port: 7709),
  (name: 'hq_42', host: '114.80.149.92', port: 7709),
  (name: 'hq_43', host: '121.14.104.60', port: 7709),
  (name: 'hq_44', host: '121.14.104.66', port: 7709),
  (name: 'hq_45', host: '123.126.133.13', port: 7709),
  (name: 'hq_46', host: '123.126.133.14', port: 7709),
  (name: 'hq_47', host: '123.126.133.21', port: 7709),
  (name: 'hq_48', host: '211.139.150.61', port: 7709),
  (name: 'hq_49', host: '59.36.5.11', port: 7709),
  (name: 'hq_50', host: '119.29.19.242', port: 7709),
  (name: 'hq_51', host: '123.138.29.107', port: 7709),
  (name: 'hq_52', host: '123.138.29.108', port: 7709),
  (name: 'hq_53', host: '124.232.142.29', port: 7709),
  (name: 'hq_54', host: '183.57.72.11', port: 7709),
  (name: 'hq_55', host: '183.57.72.12', port: 7709),
  (name: 'hq_56', host: '183.57.72.13', port: 7709),
  (name: 'hq_57', host: '183.57.72.15', port: 7709),
  (name: 'hq_58', host: '183.57.72.21', port: 7709),
  (name: 'hq_59', host: '183.57.72.22', port: 7709),
  (name: 'hq_60', host: '183.57.72.23', port: 7709),
  (name: 'hq_61', host: '183.57.72.24', port: 7709),
  (name: 'hq_62', host: '183.60.224.177', port: 7709),
  (name: 'hq_63', host: '183.60.224.178', port: 7709),
  (name: 'hq_64', host: '113.105.92.100', port: 7709),
  (name: 'hq_65', host: '113.105.92.101', port: 7709),
  (name: 'hq_66', host: '113.105.92.102', port: 7709),
  (name: 'hq_67', host: '113.105.92.103', port: 7709),
  (name: 'hq_68', host: '113.105.92.104', port: 7709),
  (name: 'hq_69', host: '113.105.92.99', port: 7709),
  (name: 'hq_70', host: '117.34.114.13', port: 7709),
  (name: 'hq_71', host: '117.34.114.14', port: 7709),
  (name: 'hq_72', host: '117.34.114.15', port: 7709),
  (name: 'hq_73', host: '117.34.114.16', port: 7709),
  (name: 'hq_74', host: '117.34.114.17', port: 7709),
  (name: 'hq_75', host: '117.34.114.18', port: 7709),
  (name: 'hq_76', host: '117.34.114.20', port: 7709),
  (name: 'hq_77', host: '117.34.114.27', port: 7709),
  (name: 'hq_78', host: '117.34.114.30', port: 7709),
  (name: 'hq_79', host: '117.34.114.31', port: 7709),
  (name: 'hq_80', host: '182.131.3.252', port: 7709),
  (name: 'hq_81', host: '183.60.224.11', port: 7709),
  (name: 'hq_82', host: '58.210.106.91', port: 7709),
  (name: 'hq_83', host: '58.63.254.216', port: 7709),
  (name: 'hq_84', host: '58.63.254.219', port: 7709),
  (name: 'hq_85', host: '58.63.254.247', port: 7709),
  (name: 'hq_86', host: '123.125.108.90', port: 7709),
  (name: 'hq_87', host: '175.6.5.153', port: 7709),
  (name: 'hq_88', host: '182.118.47.151', port: 7709),
  (name: 'hq_89', host: '182.131.3.245', port: 7709),
  (name: 'hq_90', host: '202.100.166.27', port: 7709),
  (name: 'hq_91', host: '222.161.249.156', port: 7709),
  (name: 'hq_92', host: '42.123.69.62', port: 7709),
  (name: 'hq_93', host: '58.63.254.191', port: 7709),
  (name: 'hq_94', host: '58.63.254.217', port: 7709),
  (name: 'hq_95', host: '120.55.172.97', port: 7709),
  (name: 'hq_96', host: '139.217.20.27', port: 7709),
  (name: 'hq_97', host: '202.100.166.21', port: 7709),
  (name: 'hq_98', host: '202.96.138.90', port: 7709),
  (name: 'hq_99', host: '218.106.92.182', port: 7709),
  (name: 'hq_100', host: '218.106.92.183', port: 7709),
  (name: 'hq_101', host: '220.178.55.71', port: 7709),
  (name: 'hq_102', host: '220.178.55.86', port: 7709),
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
