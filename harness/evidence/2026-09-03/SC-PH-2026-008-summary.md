# SC-PH-2026-008 会话内存清空

日期：2026-09-03（Asia/Shanghai）
状态：Harness 语义检查通过；不代表公开契约 approved 或生产实现完成。

## 范围

- 验证 App 重启/冷启动/被回收后清空内存业务视图，必须向 Connector 请求权威快照而非增量同步（PRD AC-010、5.5）。
- 验证同步游标不持久化、退出即失效（PRD 5.5）。
- 验证后台恢复 READY 时发起一次 Projection 同步，可使用当前会话内存游标增量同步（PRD 5.5）。
- 验证原文追溯内容退出后不保留、不自动重试、不恢复（PRD AC-029）；临时草稿不持久化、不可恢复（PRD AC-005）。
- 仅使用合成布尔条件和端点可见状态，不包含业务正文、真实标识或私钥。

## 命令

```text
harness/scripts/verify_contract_gate.sh
ruby harness/scripts/verify_session_memory_reset_semantics.rb harness/fixtures/session_memory_reset.json
```

## 结果

```text
session_memory_reset_semantics=passed
cases=5
business_data=false
```

## 负向结果

- 将 `app_restart_clears_memory` 篡改为 `persistent_business_cache_read=true` 时，runner 拒绝该 fixture（exit=1）。

## 证据文件

- Fixture：`harness/fixtures/session_memory_reset.json`
- Runner：`harness/scripts/verify_session_memory_reset_semantics.rb`
- 场景登记：`harness/scenarios/catalog.yaml` / `SC-PH-2026-008`
