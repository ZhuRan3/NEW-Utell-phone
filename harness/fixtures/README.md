# Fixtures

只保存最小、合成、脱敏的输入输出。禁止真实 Capture 原文、标题、摘要、私钥、账号标识和完整 Pi 输出。每个 fixture 必须注明契约版本、场景编号和预期结果。

当前 fixture：

- `pairing_invalid.json`：只表达过期/已使用 token、指纹不匹配和设备撤销的拒绝结果，不包含业务正文或内部标识。
- `ready_gate.json`：只表达 Relay、Connector、能力、权威库和 30 秒健康门禁，不包含业务正文或内部标识。
- `projection_version_ordering.json`：只表达当前会话内 Projection 版本去重和单调更新，不包含业务正文或内部标识。
- `card_command_version_conflict.json`：只表达 Card Command 版本匹配、`VERSION_CONFLICT` 和断线未知结果，不包含业务正文或内部标识。
- `ack_vs_persistent_receipt.json`：只表达 Relay ACK、Connector 持久接收回执和端点可见状态的关系，不包含业务正文或内部标识。
- `unknown_result.json`：只表达提交后断线、当前会话查询和 App 退出后的清理约束，不包含业务正文或内部标识。
