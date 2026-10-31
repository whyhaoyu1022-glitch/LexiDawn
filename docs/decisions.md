# 技术决策记录

## ADR-001 原生 SwiftUI
- 日期：2026-10-25
- 依据：SPEC.md §15.1、§15.3
- 决策：采用 SwiftUI，必要时以 UIKit 桥接。
- 影响：保持系统组件与无障碍能力；不引入第三方 UI 框架。

## ADR-002 macOS runner 负责 iOS 验证
- 日期：2026-10-25
- 依据：SPEC.md §22
- 决策：Actions 检测实际 Xcode/SDK 后构建测试；本地 Windows/容器不声称完成 iOS 验证。

## ADR-003 M0 工程配置采用规格提案值
- 日期：2026-10-25
- 依据：本日计划、SPEC.md §15.2、§26 M0
- 决策：暂以 `com.lexidawn.app`、`0.1.0 (1)`、iOS 27.0 配置工程；Xcode 27/SDK 可用性由 Actions 实测决定，旧工具链通过不能替代规格验收。
- Apple 依据：Apple 的 [Build Settings Reference](https://developer.apple.com/documentation/xcode/build-settings-reference) 说明 `GENERATE_INFOPLIST_FILE` 会让构建系统根据 build settings 生成并合并信息属性列表内容；本工程采用该设置，最终行为仍以 Actions 实测为准。

## ADR-004 证据边界与未接入模块
- 日期：2026-10-31；依据 SPEC §2.2.1：“因系统明确判定无需执行而略过”；§2.5：“用户手动确认”。
- 决策：废除字符串理由作为完成凭据。空队列 adapter 必须读取包含近期新词的完整 eligible 集合；未接入时抛错。阅读进度为 0–1，常规确认 >=0.9，手动确认不受此阈值约束。结果绑定文章/内容版本或周期/会话，重复同结果幂等、冲突结果拒绝。
- Round 1 不实现阅读器和复习题库；仅建立领域契约和显式 fixture 测试。结构化凭据验证并不替代未来 adapter 对真实持久化进度/会话的核对。

## ADR-005 历史无依据终态的保守恢复
- 依据 SPEC §19.10：“迁移前备份或至少保证数据库可恢复。”
- 决策：不把历史字符串 deferred 当作真实空队列，不凭历史 completed 反推阅读进度/确认。保存原始周期快照后，将无法验证的已知终态置为 blocked；原日期、时区、文章、carry-over 和正文保留。用户进度原值在审计快照/升级前备份中保留，不冒充已确认结果。
- 未识别的状态、重复指派、孤立周期不静默修复；显示一致性错误，需核对数据再提供专门修复，当前不支持自动删除/合并。功能接入前 blocked 只能查看与重读，不能宣称学习已能继续。

## ADR-006 carryOverCount 是跨过的民用学习日期数
- 依据 SPEC §19.3：“跨日次数”；§18.5：“处理夏令时变化和用户旅行”。规格未明确观察次数与经过日期数，选择后者以免使用频率改变计数。
- 用 Gregorian 日期高水位计算日历日差，不用秒数/86400。10-26 到 10-29 加 3；回拨后再到已观察日期不重计。旅行使用新的所选学习时区日期比较，原分配时区不修改；固定时区不跟随旅行。原历史计数保留，从已有高水位继续加，不能声称已重算完整历史统计。

## ADR-007 保留非版本化历史 schema 的轻量升级
- 支持 `c13906ae66515c29cb9a602da061caf810a62ade` 初版和 `b894bdacadbee3a52073f6c300ab043c7e43caa8` 整改版的磁盘模型。测试冻结旧字段，先由旧模型建库，再由新模型打开，验证数据和升级前备份。
- 本次仅加可选字段，不新增会删除/合并旧记录的唯一约束；使用 SwiftData 自动轻量迁移，并在 domain 恢复阶段单独处理语义约束。`UserPreferences.schemaVersion` 仍是偏好格式版本 1，不伪装为 SwiftData store schema 版本。
- 冷启动、尚未打开容器时备份原 store/WAL/SHM，一次成功备份不会覆盖。失败传播到启动页；没有清库 fallback。当前不支持多个进程同时写入。测试是否通过以本次 Actions 日志为准，不能仅凭“可选列”宣称验证通过。

## ADR-008 结果事件时间与展示权利
- 已保存结果使用源事件时间，允许在较晚的跨日/恢复处理之后应用；updatedAtUTC取高水位，completedAtUTC取最后一项有效结果时间，不把请求重试时间当完成时间。普通状态命令仍拒绝时间回退。
- 正文展示许可与缓存permission分开，图片展示核验与imageLicenseID/署名分开；新增布尔权利字段为可选，历史nil按未授权处理。不能把非空许可ID自动理解为所有权利。
- SwiftData事务恢复依据：[Apple ModelContext](https://developer.apple.com/documentation/swiftdata/modelcontext) 对 save、hasChanges、rollback、autosave 的定义；结构升级依据：[Apple Schema](https://developer.apple.com/documentation/swiftdata/schema)。文档能力仍以本次实际编译/运行验证为准。
