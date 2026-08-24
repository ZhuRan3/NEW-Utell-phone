# 手机端 Harness

harness 用于在不依赖真实 Relay、Connector 或 Pi 的情况下验证手机端公开行为。它不是生产代码，不收集真实业务内容。

跨端契约入口是 `契约/integration-profile.yaml`；两端文件必须逐字节一致。契约治理、版本、同步、审批、时间盒和新会话交接规则见 `文档/架构与契约/跨端公开契约治理规范.md`。

## 运行结构

- `契约/`：Relay Transport、Connector Service、错误码和版本说明。
- `fixtures/`：最小脱敏输入、Projection、回执和错误样本。
- `mocks/`：mock Relay、fake Connector 和测试密钥替身。
- `scenarios/`：Given/When/Then 场景与故障注入。
- `evidence/`：按日期保存测试摘要、截图、脱敏日志和校验和。
- `scripts/`：可重复命令；不含凭据和环境私有路径。

## 最小验收集

配对成功/过期/撤销、READY 门禁、Relay ACK 与持久接收区分、未知结果、版本乱序、确认/纠正、VERSION_CONFLICT、重启清空内存业务视图、无原文残留和诊断脱敏。
