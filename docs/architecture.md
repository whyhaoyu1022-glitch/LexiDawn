# 架构

依据 SPEC §15.3：“数据修改通过 Repository / Use Case 统一执行。”保留 SwiftUI / Domain / Repository / SwiftData 分层，领域与 Repository 写入在 MainActor；Round 2 词典资源由独立 actor 加载。

- Domain：`DailyStudyCycle` 可抛错初始化、只读对外状态和统一 `validate()`。通用更新不能 completed/deferred。阅读完成需文章 ID、内容哈希、有效进度及明确确认；手动确认允许低进度，不增加查词要求。复习空队列只由完整可复习集合的 reader 生成绑定 cycleID/版本/时间的证据，三个复习状态一次性解析；不可用 reader 抛错。正常/部分复习结果由 reader 读取固定已保存会话、题目与已答 ID 的结构化结果约束，源事件时间保持不变。生产未实现这些模块，不产生伪结果。
- Data：新增字段均可选，保留原有字段/实体。Record.domain() 走同一领域验证。已知旧 deferred/无证据完成状态在显式恢复事务中存档全部原标量与证据后变成说明清楚的 blocked；无法辨认的状态或关联异常终止恢复，不删除或合并数据。
- Repository：`RepositoryWriter` 关闭 autosave，每次同步写入使用专属ModelContext，统一save/catch/rollback，失败上下文直接弃用，不复用其缓存；读取使用新context。真只读磁盘测试证实仅rollback不足以清除注册幽灵对象。创建必须同一上下文写文章和周期；移除非原子 fallback。普通保存验证文章存在、身份不变、日期/文章指派唯一、状态不回退、完成证据和内容版本匹配。current 总是最早未完成周期；历史多个未完成记录保留。文章相同 ID 仅接受完全相同快照重试，不覆盖已分配正文。
- Article：Candidate 负责许可/缓存期限、来源与图片署名、HTTP(S) URL、正文/主题门禁；正文 SHA-256、英文词数和按 200 词/分钟估算阅读时间由正文计算。所有 Repository 文章入口复用门禁。历史缺少缓存权利的文章不推断获得许可，后续阅读器必须重新核验。
- AppCore：生产打开原默认数据库 URL，先创建父目录并保留一次升级前数据库/WAL/SHM 冷启动备份；自动轻量迁移仅新增可选列。不支持活动外部写入下文件备份；当前无 extension/后台独立写进程。打开失败提供真实重试，无删除重建分支。
- Today：读取偏好固定/设备时区；统一使用 Gregorian yyyy-MM-dd 学习日期。显示四任务原因；未接入操作 disabled，说明当前尚不能恢复学习。“重新读取已保存状态”只重读/执行安全恢复；启动“重新打开存储”重新执行初始化。

保障范围：同一应用单一容器、串行 MainActor Repository 是受支持写入口。不同 context 的顺序读取有测试；没有对多容器/跨进程竞争作数据库唯一约束承诺。唯一性使用同一同步 unit of work 的事务性去重，不能把主线程串行解释成跨进程锁。Preferences返回用于编辑的托管记录，save先捕获完整独立快照、回滚编辑context，再在专属写context应用。调用者不要跨await悬置编辑；UI保存后重新load。

迁移支持范围与计数语义见 ADR-004–007；实际升级成功必须以两个历史 schema 磁盘测试为准，当前模型重开测试不能替代迁移测试。

原生窗口和CI定位：App Debug/Release均启用标准UILaunchScreen与UIApplicationSceneManifest生成，CI读取真实产物plist校验；XCUITest实际验证现代窗口尺寸。UI定位仅操作标识today-scroll，按可用viewport和目标方向滚动，无进展附截图/层级失败；不通过跳过点击来隐藏不可见控件。固定iPhone17Pro/iOS26.5兼容环境，共享derivedData但不跳过target。详见ADR-010及本轮报告。

实际验证：代码 `309afe81aecfbfd84e5a9f52251c59f8e32c0575` 的 [run 41170754181](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41170754181) **success**：XCTest 61/0、XCUITest 8/0；UI用例合计 321.466 秒。artifact [13031277540](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41170754181/artifacts/13031277540)。

复习源结果的recordedAt相对上一个已保存会话结果不可回退；复习已完成时，其完整结果凭据即保持不变，即使文章仍未完成。领域命令与直接Repository更新都执行该检查；初次延迟结果仍可早于周期updatedAt高水位，保留源事件时间。

## Round 2 当前交付范围（2026-10-31）

生产入口现使用真实 LearningServices；此前“生产未接入”的 Round 1 文字仅说明历史状态。已提供：合法粘贴导入、随附 RFC 8890 原文与官方刷新、原生词级点击阅读器、节流进度和重启恢复、明确阅读确认、CC-CEDICT 本地反向查词与详情、生词搜索/笔记/安全撤销/确认删除、持久化连线与拼写、确定性基础排程、真实设置、事件统计、文章库/历史和探索门禁。

来源的全文/缓存权利以 IETF TLP 5 §3(c)(i) 为依据，原文完整保留并核对 SHA-256。词典派生索引使用 CC BY-SA 4.0，可能对应词不冒称已消歧的语境义；来源不提供英语音标、词性或例句时如实说明。用户导入仅限本地，不代表取得公开版权。探索与每日指派分离；文章库保留历史与授权失效元数据。

排程为 `lexidawn-basic-1`，不是 FSRS。M4 的语境消歧、丰富短语、可靠英语词性/IPA，M5 的额外复习、M6 的高级词汇推荐和 M7/M9 尚未交付。没有通知/AI/账号/上传/付费服务或签名 IPA。iOS 27 产品目标保留；CI 仅验证已批准 iOS 26.5 模拟器。

本批功能及验证状态以 [Round 2 开发交付自述](reviews/round-2-development-delivery.md) 为准；独立验收尚未执行。

### Round 2 实际层级

`LearningRootView → ViewModel/意图 → Content/Reader/Vocabulary/Review 服务 → RepositoryWriter → SwiftData`。Today 仍通过原 DailyCycleService 获取最早周期；复习和阅读在同一 context 内调用原 StudyCycleRepository.applyInTransaction，不建立第二套任务状态。UI 仅保存页面选择与输入草稿，持久化真值在 Repository。

正文入口与元数据分开：ContentRepository.read 返回 ReadableArticle，library 仅返回不含正文的 ArticleLibraryItem；授权失效时保留 hash/关联，阻止展示并提供原文入口。探索路由与 ReaderProgressService 写入口均有门禁；已指派文章只能沿原周期继续。统计从完成证据/进度/会话结果重建，不维护多个页面计数器。

词典数据加载在 actor 内，主线程只提交必要缓存实体；TextKit 按正文版本解析token，点击二分命中；不在每帧重新hash/分词。进度2秒节流，离开/后台刷写。短英文详情复用同一命中组件；动态高度与嵌套深度受控。


## Round 2 已核验的应用代码结果

应用代码 `fcac01b3d40b311b51c7a0fea4e6329d0300ca92` 的 [Actions 41194434948](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41194434948) 已结束 **success**：**93 XCTest/0失败、13 UI/0失败**，逐项匹配106个测试方法，无遗漏。artifact [13040631627](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41194434948/artifacts/13040631627) 包含unit/UI xcresult、完整日志及原生截图。最小“真实文章→阅读→查词→生词→连线→拼写→周期完成→探索解锁”场景已通过模拟器UI；磁盘重开与两版旧schema升级在同一套回归中通过。UI共615.006秒，3504词微基准平均0.024秒，波动较大，不能作为真机帧率承诺。

后续测试定位增强提交 `1b2e26b39c33aff434298ab141eff426725caf24` 仅增加重启后foreground/hittable等待和一次真实坐标触摸，保留恢复百分比与可见词元位置断言。最终文档提交的SHA/Actions以GitHub History和交付答复为准；本节不冒用应用代码的绿色运行作为其他SHA的证明。

这是 iOS26.5兼容模拟器/Xcode26.6 结果，不代表iOS27、真机、签名IPA、全量无障碍或独立验收通过。详细范围、全部失败及未完成项见 Round 2 开发交付自述。
