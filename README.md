# dart_tdx

通达信（TDX）股票市场数据接口的 Dart 实现。这是 [mootdx](https://github.com/mootdx/mootdx) 的 Dart 移植版本。

> **郑重声明**: 本项目只作学习交流，不得用于任何商业目的。

## 功能

- ✅ 实时行情数据（五档行情）
- ✅ K线数据（日线、周线、月线、分钟线等）
- ✅ 股票列表查询
- ✅ 财务数据下载
- ✅ 离线数据文件读取（.day, .lc1, .lc5）
- ✅ 板块数据

## 安装

在 `pubspec.yaml` 中添加：

```yaml
dependencies:
  dart_tdx:
    git:
      url: https://github.com/iOSleep/dart_tdx.git
```

然后运行：

```bash
dart pub get
```

## 快速开始

### 在线行情

```dart
import 'package:dart_tdx/dart_tdx.dart';

void main() async {
  // 连接服务器
  final quotes = await Quotes.factory(market: 'std');

  // 获取K线数据
  final bars = await quotes.bars('600036',
      frequency: KLineType.day, offset: 10);
  for (final bar in bars) {
    print('${bar.datetime} O:${bar.open} C:${bar.close}');
  }

  // 获取实时行情
  final quotesList = await quotes.quotes(['000001', '600036']);
  for (final q in quotesList) {
    print('${q.code} 价格:${q.price} 涨幅:${q.speed}%');
  }

  // 获取股票列表
  final stocks = await quotes.securityList(Market.sz, 0);
  for (final s in stocks) {
    print('${s.code} ${s.name}');
  }

  quotes.close();
}
```

### 离线数据读取

```dart
import 'package:dart_tdx/dart_tdx.dart';

void main() {
  final reader = Reader.factory(tdxDir: '/path/to/tdx');

  // 读取日线数据
  final daily = reader.daily('600036');

  // 读取分钟线数据
  final minute1 = reader.minute('600036', suffix: 1);
  final minute5 = reader.fzline('600036');
}
```

### 财务数据

```dart
import 'package:dart_tdx/dart_tdx.dart';

void main() async {
  // 下载单个财务文件
  await Affair.fetch(
    downloadDir: './data',
    filename: 'gpcw19960630.zip',
  );

  // 下载所有财务数据
  await Affair.fetchAll(downloadDir: './data');
}
```

## API 参考

### Quotes

| 方法 | 说明 |
|------|------|
| `bars(symbol, {frequency, start, offset})` | 获取K线数据 |
| `quotes(symbols)` | 获取实时行情 |
| `index(symbol, {frequency})` | 获取指数K线 |
| `stockCount(market)` | 获取市场股票数量 |
| `securityList(market, start)` | 获取股票列表 |
| `minute(symbol)` | 获取分时数据 |

### Reader

| 方法 | 说明 |
|------|------|
| `daily(symbol)` | 读取日线数据 |
| `minute(symbol, {suffix})` | 读取分钟线数据 |
| `fzline(symbol)` | 读取5分钟线数据 |

### Affair

| 方法 | 说明 |
|------|------|
| `files()` | 获取财务文件列表 |
| `fetch({downloadDir, filename})` | 下载单个财务文件 |
| `fetchAll({downloadDir})` | 下载所有财务文件 |

## 市场代码

| 常量 | 值 | 说明 |
|------|-----|------|
| `Market.sz` | 0 | 深圳 |
| `Market.sh` | 1 | 上海 |
| `Market.bj` | 2 | 北京 |

## K线周期

| 常量 | 值 | 说明 |
|------|-----|------|
| `KLineType.min1` | 8 | 1分钟 |
| `KLineType.min5` | 0 | 5分钟 |
| `KLineType.min15` | 1 | 15分钟 |
| `KLineType.min30` | 2 | 30分钟 |
| `KLineType.hour1` | 3 | 1小时 |
| `KLineType.day` | 4 | 日线 |
| `KLineType.week` | 5 | 周线 |
| `KLineType.month` | 6 | 月线 |
| `KLineType.year` | 11 | 年线 |

## 许可证

MIT License
