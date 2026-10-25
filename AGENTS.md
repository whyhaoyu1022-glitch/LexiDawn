# LexiDawn 开发规则

- `SPEC.md` 是产品行为和架构的权威来源；实现必须引用规格章节和逐字原文。
- 严禁擅自增加功能、改变逻辑或架构、删减需求；冲突先记录，只有核心行为、隐私、安全、付费服务或签名路线实质变化时询问。
- 每个目标必须进入 `docs/requirements-traceability.md`，包含原文依据、范围、依赖、验收和证据。
- 每次开发批次必须推进一个有意义的功能切片，并同步文档、矩阵、STATUS、日志和 CHANGELOG。
- 每个适用行为覆盖正常、边界、错误、持久化/恢复和安全场景；不得伪造测试、设备、签名、SHA 或 CI 结果。
- GitHub Actions 每次 push 自动运行；不等待或轮询 CI。明确区分本地测试、未运行测试和未检查的 Actions。
- 不提交 API Key、证书私钥、profile 密码、令牌或敏感个人数据。
- Apple/Xcode/SDK/签名/AltServer 信息必须以官方文档和 runner 实测为准；当前环境不能运行 Xcode 时如实记录。
