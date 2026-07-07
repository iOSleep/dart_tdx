## 1.0.1

- **修复**: socket 读取层改用 FIFO 唤醒队列，消除 setup 大响应分片到达时的漏唤醒/响应头错位问题
- **修复**: 服务器列表替换为 tdxpy 权威节点（103 个去重节点），移除已失效的坏节点
- **修复**: 新增带缓存的 host 自动回退，冷启动扫描可用节点并缓存最优连接
- **修复**: 全部命令包协议对齐 tdxpy（getSecurityQuotes/getMinuteTimeData/getHistoryMinuteTimeData/getTransactionData/getHistoryTransactionData/getIndexBars/getCompanyInfoCategory/getCompanyInfoContent/getXdXrInfo/getFinanceInfo/getBlockInfoMeta/getBlockInfo/getReportFile）
- **修复**: getSecurityCount 协议错误（命令码和尾随字节不正确）

## 1.0.0

- 首个正式版本
- 对齐 Python mootdx 市场判定逻辑
- 通達信 (TDX) 标准行情、扩展行情、财务数据接口
- 离线数据文件读取
- 实时行情、K线、分时、分笔成交数据
