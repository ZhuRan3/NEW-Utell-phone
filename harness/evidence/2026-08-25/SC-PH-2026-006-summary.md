# SC-PH-2026-006 Card Command 版本冲突

日期：2026-08-25（Asia/Shanghai）
状态：Harness 语义检查通过；不代表公开契约 approved 或生产实现完成。

## 范围

- 验证 `expectedVersion` 与权威版本一致时允许写入。
- 验证过期版本使用既有 `VERSION_CONFLICT` 拒绝写入，刷新最新 Projection 后要求用户重新确认。
- 验证命令回执前断线显示未知结果，恢复 READY 后刷新 Projection，且不自动重发。
- 仅使用合成版本和布尔观察值，不包含业务正文、真实标识或私钥。

## 命令

```text
harness/scripts/verify_contract_gate.sh
ruby harness/scripts/verify_card_command_version_conflict_semantics.rb harness/fixtures/card_command_version_conflict.json
```

## 结果

```text
card_command_version_conflict_semantics=passed
cases=3
business_data=false
```

## 负向结果

将过期版本案例篡改为 `authority_write_performed=true` 时，runner 拒绝该 fixture。

## 证据文件

- Fixture：`harness/fixtures/card_command_version_conflict.json`
- Runner：`harness/scripts/verify_card_command_version_conflict_semantics.rb`
- 场景登记：`harness/scenarios/catalog.yaml` / `SC-PH-2026-006`
