# 架构

依据 SPEC §15.3：“数据修改通过 Repository / Use Case 统一执行。”保留 SwiftUI / Domain / Repository / SwiftData 分层，所有服务和 Repository 在 MainActor 同步调用。

- Domain：`DailyStudyCycle` 可抛错初始化、只读对外状态和统一 `validate()`。通用更新不能 completed/deferred。阅读完成需文章 ID、内容哈希、有效进度及明确确认；手动确认允许低进度，不增加查词要求。复习空队列只由完整可复习集合的 reader 生成绑定 cycleID/版本/时间的证据，三个复习状态一次性解析；不可用 reader 抛错。正常/部分复习结果由 reader 读取固定已保存会话、题目与已答 ID 的结构化结果约束，源事件时间保持不变。生产未实现这些模块，不产生伪结果。
- Data：新增字段均可选，保留原有字段/实体。Record.domain() 走同一领域验证。已知旧 deferred/无证据完成状态在显式恢复事务中存档全部原标量与证据后变成说明清楚的 blocked；无法辨认的状态或关联异常终止恢复，不删除或合并数据。
- Repository：`RepositoryWriter` 关闭 autosave，每次同步写入使用专属ModelContext，统一save/catch/rollback，失败上下文直接弃用，不复用其缓存；读取使用新context。真只读磁盘测试证实仅rollback不足以清除注册幽灵对象。创建必须同一上下文写文章和周期；移除非原子 fallback。普通保存验证文章存在、身份不变、日期/文章指派唯一、状态不回退、完成证据和内容版本匹配。current 总是最早未完成周期；历史多个未完成记录保留。文章相同 ID 仅接受完全相同快照重试，不覆盖已分配正文。
- Article：Candidate 负责许可/缓存期限、来源与图片署名、HTTP(S) URL、正文/主题门禁；正文 SHA-256、英文词数和按 200 词/分钟估算阅读时间由正文计算。所有 Repository 文章入口复用门禁。历史缺少缓存权利的文章不推断获得许可，后续阅读器必须重新核验。
- AppCore：生产打开原默认数据库 URL，先创建父目录并保留一次升级前数据库/WAL/SHM 冷启动备份；自动轻量迁移仅新增可选列。不支持活动外部写入下文件备份；当前无 extension/后台独立写进程。打开失败提供真实重试，无删除重建分支。
- Today：读取偏好固定/设备时区；统一使用 Gregorian yyyy-MM-dd 学习日期。显示四任务原因；未接入操作 disabled，说明当前尚不能恢复学习。“重新读取已保存状态”只重读/执行安全恢复；启动“重新打开存储”重新执行初始化。

保障范围：同一应用单一容器、串行 MainActor Repository 是受支持写入口。不同 context 的顺序读取有测试；没有对多容器/跨进程竞争作数据库唯一约束承诺。唯一性使用同一同步 unit of work 的事务性去重，不能把主线程串行解释成跨进程锁。Preferences返回用于编辑的托管记录，save先捕获完整独立快照、回滚编辑context，再在专属写context应用。调用者不要跨await悬置编辑；UI保存后重新load。

迁移支持范围与计数语义见 ADR-004–007；实际升级成功必须以两个历史 schema 磁盘测试为准，当前模型重开测试不能替代迁移测试。
