# SC-PH-2026-001 配对失败

日期：2026-08-24（Asia/Shanghai）
状态：Harness 语义检查通过；不代表公开契约 approved 或生产实现完成。

## 范围

- 验证 token 过期、token 已使用、指纹不匹配和设备撤销都拒绝建立 pairing。
- 验证上述失败统一使用既有 `PAIRING_INVALID`，手机保持 `UNPAIRED`，不启动会话。
- 仅使用合成布尔条件和端点可见状态，不包含 token、业务正文、真实标识或私钥。

## 命令

```text
harness/scripts/verify_contract_gate.sh
ruby harness/scripts/verify_pairing_invalid_semantics.rb harness/fixtures/pairing_invalid.json
```

## 结果

```text
pairing_invalid_semantics=passed
cases=4
business_data=false
```

## 负向结果

将一个拒绝条件篡改为 `pairing_established=true` 时，runner 拒绝该 fixture。

## 证据文件

- Fixture：`harness/fixtures/pairing_invalid.json`
- Runner：`harness/scripts/verify_pairing_invalid_semantics.rb`
- 场景登记：`harness/scenarios/catalog.yaml` / `SC-PH-2026-001`
