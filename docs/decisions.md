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

## ADR-009 失败写上下文必须隔离并弃用
- 真实证据：run41164982359中只读磁盘save抛NSCocoaErrorDomain513；rollback之后hasChanges=false，但同context仍查到未落盘Article。新容器查询为空。这说明不能把“hasChanges=false”扩大为“此context可安全复用”。
- 决策：每个Repository写操作建立专属ModelContext；文章/周期仍同一save；失败rollback并永久丢弃context。每次公开读取使用新context，避免失败或其他context的缓存残留。Preferences编辑跨边界为完整detached快照，原编辑context回滚；不能把托管对象直接跨context保存。
- 保留原失败测试的同context查询空断言，另增强同Repository重读、恢复可写后的真实重试及已有周期update失败回归。不是把数据库失败测试改成Fake或删掉assert。

## ADR-010 原生窗口与有界UI定位
- 实测artifact13029591495的ActionDeviceRecord为iPhone17Pro/iOS26.5，AX窗口320x480、按钮在Y604.67，滚动无进展。手工工程缺少标准Launch Screen/Scene Manifest生成，按[Apple Build Settings Reference](https://developer.apple.com/documentation/xcode/build-settings-reference)配置两项生成开关，并在CI验证产物Info.plist；是否恢复现代全屏以新增真实UI窗口断言为准。
- UI测试只在指定ScrollView向目标方向滚动，检查窗口/导航/标签栏裁剪后的实际viewport。到边界/无进展立即红灯并附诊断，绝不删除visible或disabled断言。固定重复滑动不是有效证明，取消这些动作不会减少业务验收要求。

### ADR-008 补充：复习结果历史边界
- 复习源事件recordedAt相对上一个结果单调；已完成的reviewProgress整体不可替换，即使文章尚未完成。Domain和Repository均校验，精确相同结果仍幂等。初次延迟恢复可早于周期updatedAt高水位，不能用“请求时间”改写学习事件。真实内存SwiftData回归为 `testSwiftDataReviewResultsRejectStaleSnapshotsAndTerminalEvidenceReplacement`，执行证据见本轮报告。

- ADR-010实测结论：最终代码run41170754181的窗口尺寸回归通过，原始PNG为1206×2622；完整UI日志仅3次定向上滑/0次下滑，8个UI用例321.466秒。保留5个keepAlways截图作为用户审阅证据，不降低业务断言。

## Round 2 当前交付范围（2026-10-31）

生产入口现使用真实 LearningServices；此前“生产未接入”的 Round 1 文字仅说明历史状态。已提供：合法粘贴导入、随附 RFC 8890 原文与官方刷新、原生词级点击阅读器、节流进度和重启恢复、明确阅读确认、CC-CEDICT 本地反向查词与详情、生词搜索/笔记/安全撤销/确认删除、持久化连线与拼写、确定性基础排程、真实设置、事件统计、文章库/历史和探索门禁。

来源的全文/缓存权利以 IETF TLP 5 §3(c)(i) 为依据，原文完整保留并核对 SHA-256。词典派生索引使用 CC BY-SA 4.0，可能对应词不冒称已消歧的语境义；来源不提供英语音标、词性或例句时如实说明。用户导入仅限本地，不代表取得公开版权。探索与每日指派分离；文章库保留历史与授权失效元数据。

排程为 `lexidawn-basic-1`，不是 FSRS。M4 的语境消歧、丰富短语、可靠英语词性/IPA，M5 的额外复习、M6 的高级词汇推荐和 M7/M9 尚未交付。没有通知/AI/账号/上传/付费服务或签名 IPA。iOS 27 产品目标保留；CI 仅验证已批准 iOS 26.5 模拟器。

本批功能及验证状态以 [Round 2 开发交付自述](reviews/round-2-development-delivery.md) 为准；独立验收尚未执行。

## ADR-011 Round 2 本地内容与词典数据

- 本轮直接 main 开发，不变更 SPEC；当前用户要求优先于旧 AGENTS 的“不检查 CI”，逐次核对最终运行。
- 官方 RFC 8890 是完整、不改正文的法律许可快照；随附版权声明/署名，在线获取须匹配同一 SHA。失效正文仅允许由同一已核验原文恢复，不覆盖任何学习关系。用户正文是本地导入声明，使用私有 URI，原 URL 用于归因和去重；不自动抓取。
- CC-CEDICT 是中英词典的反向词目索引，不是英语语境消歧。保留完整源行并标可能对应；无词性/英语IPA时不编造。派生 JSON 同 CC BY-SA 4.0，应用不联网查询 MDBG 网页。
- ReadableArticle 是正文展示出口；metadata/library 不包含 body。读取与保存检查授权，高水位阻止已观察到的到期被时钟回拨复活。设备没有可信时间源，无法判断从未观察到的时间变化；前台到期定时检查与前后台重开用于及时撤回正文，不能声称密码学安全时钟。
- 统计有效学习日定义为明确阅读完成或整次非空复习完成；按事件时间及周期时区记日。复习空队列并非实际学习行为。探索完成按用户当前学习时区计算；后续事件表会固定探索事件时区，避免旅行后历史重算。
- 当前 deterministic basic 排程：Again 1天，Hard max(2,前间隔+2)，Good max(4,前间隔×2)，上限3650天；是基础版而非FSRS。保留不可变日志、旧状态时间和版本，未来迁移不能改写历史日志或删除词条。
- 详细页英文点击最多嵌套3层，之后明确提示返回；避免无限堆叠。当前无自动短语消歧、商业词典、AI解释或付费服务。
