# Scripts

脚本必须可重复执行、参数显式、失败时返回非零状态，不依赖开发者本机私有路径。脚本不得读取真实用户数据或写入生产服务。

当前脚本：

- `verify_contract_gate.sh`：校验两端 `integration-profile` 逐字节一致、契约状态、Harness required scenarios、场景目录和契约 section 依赖。
- `run_ready_scenarios.rb`：先执行契约门禁，再按目录自动运行全部 `ready` fixture/runner。
- `verify_pairing_invalid_semantics.rb`：执行 `pairing_invalid` 脱敏语义检查。
- `verify_ready_gate_semantics.rb`：执行 `ready_gate` 脱敏语义检查。
- `verify_projection_version_ordering_semantics.rb`：执行 `projection_version_ordering` 脱敏语义检查。
- `verify_card_command_version_conflict_semantics.rb`：执行 `card_command_version_conflict` 脱敏语义检查。
- `verify_ack_receipt_semantics.rb`：执行 `ack_vs_persistent_receipt` 脱敏语义检查。
- `verify_unknown_result_semantics.rb`：执行 `unknown_result` 脱敏语义检查。

脚本执行结果必须按 `开发规则规范/07-人类可读进度与技术沟通规范.md` 登记到测试站证据：记录实际命令、退出码、环境、通过范围、未覆盖范围和证据位置。脚本通过不等于契约批准或生产就绪。
