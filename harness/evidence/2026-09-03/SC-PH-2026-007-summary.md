# SC-PH-2026-007 撤销配对

日期：2026-09-03（Asia/Shanghai）
状态：Harness 语义检查通过；不代表公开契约 approved 或生产实现完成。

## 范围

- 验证用户撤销且 Connector 确认后：手机进入 `UNPAIRED`、禁用输入并展示配对入口、Relay 拒绝后续路由、权威历史数据保留（PRD AC-018）。
- 验证已撤销设备重新认证/建连被拒绝并映射为 `PAIRING_INVALID`，不建立会话（PRD AC-002）。
- 验证撤销请求失败（Connector 未确认）时保留原配对状态并提示重试（PRD FR-007 异常路径）。
- 仅使用合成布尔条件和端点可见状态，不包含业务正文、真实标识或私钥。

## 命令

```text
harness/scripts/verify_contract_gate.sh
ruby harness/scripts/verify_pairing_revocation_semantics.rb harness/fixtures/pairing_revocation.json
```

## 结果

```text
pairing_revocation_semantics=passed
cases=3
business_data=false
```

## 负向结果

- 将 `revoke_confirmed` 篡改为 `pairing_remains_active=true` 时，runner 拒绝该 fixture（exit=1）。

## 证据文件

- Fixture：`harness/fixtures/pairing_revocation.json`
- Runner：`harness/scripts/verify_pairing_revocation_semantics.rb`
- 场景登记：`harness/scenarios/catalog.yaml` / `SC-PH-2026-007`
