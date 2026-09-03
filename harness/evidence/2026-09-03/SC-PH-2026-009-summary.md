# SC-PH-2026-009 诊断脱敏导出

日期：2026-09-03（Asia/Shanghai）
状态：Harness 语义检查通过；不代表公开契约 approved 或生产实现完成。

## 范围

- 验证诊断导出必须经用户确认；未确认不得产生导出物（PRD FR-007）。
- 验证导出物仅含脱敏白名单字段（链路状态、错误码、脱敏计数、时延、版本等），不含私钥、Capture 原文、卡片标题/摘要、Pi 完整输出或可还原业务内容的数据（PRD AC-017、7.3）。
- 仅使用合成字段名与占位值，不包含业务正文、真实标识或私钥。

## 命令

```text
harness/scripts/verify_contract_gate.sh
ruby harness/scripts/verify_diagnostic_redaction_semantics.rb harness/fixtures/diagnostic_redaction.json
```

## 结果

```text
diagnostic_redaction_semantics=passed
cases=4
business_data=false
```

## 负向结果

- 在导出物中注入 `raw_text` 字段时，runner 拒绝该 fixture（exit=1）。
- 将未确认用例篡改为 `export_produced=true` 时，runner 拒绝该 fixture（exit=1）。

## 证据文件

- Fixture：`harness/fixtures/diagnostic_redaction.json`
- Runner：`harness/scripts/verify_diagnostic_redaction_semantics.rb`
- 场景登记：`harness/scenarios/catalog.yaml` / `SC-PH-2026-009`
