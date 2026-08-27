# SC-PH-2026-002 READY 门禁

日期：2026-08-24（Asia/Shanghai）
状态：Harness 语义检查通过；不代表公开契约 approved 或生产实现完成。

## 范围

- 验证 Relay 连接、Connector 在线、能力兼容、权威库可接收和最近 30 秒健康检查共同构成 READY 门禁。
- 验证任一门禁失败时手机使用既有链路状态并禁用输入；健康信息超过 30 秒时进入 `UNKNOWN`。
- 仅使用合成布尔条件和健康年龄，不包含业务正文、真实标识或私钥。

## 命令

```text
harness/scripts/verify_contract_gate.sh
ruby harness/scripts/verify_ready_gate_semantics.rb harness/fixtures/ready_gate.json
```

## 结果

```text
ready_gate_semantics=passed
cases=6
business_data=false
```

## 负向结果

将健康过期案例篡改为 `input_enabled=true` 时，runner 拒绝该 fixture。

## 证据文件

- Fixture：`harness/fixtures/ready_gate.json`
- Runner：`harness/scripts/verify_ready_gate_semantics.rb`
- 场景登记：`harness/scenarios/catalog.yaml` / `SC-PH-2026-002`
