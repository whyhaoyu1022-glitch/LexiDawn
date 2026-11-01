# Round 3 开发记录与验收证据

状态：开发与验证尚未完成，不是全量验收通过声明。起点 main 为 `93b4253d5f809d0813508e02d5e6141e8825d37f`。所有远端提交直接进入 main，没有创建其他分支。

实现依据：补充规范 v1.1 F：“丢弃当前候选”；E：“rawContent 和 structuredBody 必须原子写入”；SPEC §10.1：“FSRS（Free Spaced Repetition Scheduler）或经审查的等价间隔复习实现”；§6.3：“找不到时回退到文章开头并提示”；§7.5：“如果词条原本已存在，撤销不得删除原有记录。”本轮保留既有独立写context、rollback、学习周期及撤销机制。

## 实际源码变更

- 文章：来源审查注册、内存候选、RSS/Atom/API JSON、无磁盘HTTP缓存、有限退避、固定revision Wikipedia全文、HTML分块、JSON-LD读取、全文一致性校验、SHA/URL去重、权利证据与双正文同事务保存。失败不替换旧全文，错误不展示候选信息。
- 文章库：标题搜索、分类/来源、时间顺序、收藏、稍后阅读、历史与本地完整状态；收藏只改文章标记，不建立周期。
- 阅读器：压缩横屏头部、正文最小高度和布局优先级；全页主题；移除文章外链；硬换行展示与原始UTF16进度映射分开；旋转恢复；TextKit结构样式及词元无障碍对象复用。
- 词典：Free Dictionary API、Wiktionary及官方Action API路径、CEDICT；来源/词性/IPA/例句/词义关系；按provider/version缓存；本地结果优先；并发请求独立失败、真实义项合并、确定性语境重合排序。短语识别及个人释义保留。
- 复习：真实Canvas贝塞尔线、两端禁用、服务拒绝已消费释义；会话重载清理旧选择/输入/反馈；句子遮空；独立FSRS 4.5公式、固定参数、状态与算法版本、不可变日志、下次日期展示。
- 数据：新增可迁移的可选字段、收藏默认值、provider缓存实体；生产启动前单独before-round3冷备份和幂等回填。没有删除用户周期、进度、生词、个人释义或日志。

## Round 2追踪

| 编号 | 本轮对应工作 | 验收状态 |
|---|---|---|
| R2-A01 | 横屏头部/正文布局、UTF16映射、十次旋转正文/点词UI回归 | 待运行及双尺寸/三主题核验 |
| R2-A02 | Canvas真实连线、双端禁用、重复消费保护、像素检查 | 待UI运行和截图 |
| R2-A03 | 来源准入与Wikipedia全文API，九源审查 | 部分实现；未达五个新源 |
| R2-A04 | 两英语Provider+CEDICT聚合 | 待真实网络测试 |
| R2-A05 | FSRS 4.5 DSR公式、状态及日志 | 新实现待向量/集成测试；不是最新FSRS版本或Anki分钟学习步骤 |
| R2-A06 | 新空库Live全文导入测试；旧UI闭环保留 | 新增空库真实网络UI闭环待运行 |
| R2-A07 | 限制重试、失败不覆盖本地正文、启动检查新鲜度 | 长期/后台/日期变化矩阵未完成 |
| R2-A08 | 勾选、选中、错误反馈、连接线、语境拼写 | 待原生截图审阅 |
| R2-A09 | 全页背景、导航栏、preferredColorScheme | 浮窗/系统混合主题待完整验证 |
| R2-A10 | 原文与分块分离、硬行映射、标题/引用/列表 | 待长文、复杂表格回归 |
| R2-A11 | 主色对比、库筛选和语义反馈 | 其余全局视觉与对比人工审阅未完成 |
| R2-A12 | 阅读/文章库/生词来源移除外部阅读链接，署名展开显示 | 首屏实际密度待截图 |
| R2-A13 | 评分映射说明、日志来源及下次复习日期 | 待Again/Hard/Good完整截图 |
| R2-A14 | 保留20 UI、新增旋转和真实线像素断言 | 大字体/完整VoiceOver/嵌套键盘矩阵未完成 |
| R2-A15 | 明确隔离fixture、真实网络/故障注入命名、截图JSON元数据 | 无fixture冒充生产成功 |
| R2-A16 | STATUS顶端CURRENT与历史分隔 | 文档已改；最终结果待填 |
| R2-A17 | generation、重载重置、后台恢复重读 | 跨周期UI验证未完成 |
| R2-A18 | provider/sourceVersion缓存、过期/失败回退、旧资源版本刷新 | 待缓存升级与离线UI验证 |
| R2-A19 | 词元对象复用；保留微基准 | 没有Instruments/真机帧率或内存证据 |
| R2-A20 | 库/浮窗/复习/错误及阅读细节 | 其余细节与全状态截图未完成 |

## 实际运行记录

| main SHA | Actions | 真实结论 |
|---|---|---|
| 17e2c49042ea81c479b6d8e0033810fee1a50c1f | https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41266228017 | app编译失败：合并声明多个@State；测试未运行，无截图 |
| 4c1eeda4d256071e9ba9e3f873661d0097208f99 | https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41266394553 | app编译失败：catch中error遮蔽；测试未运行，无截图 |
| 3890b64021bdb2299e3e829d4123a797b58e2a5b | https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41266560236 | app编译失败：反馈方法误重复至快照适配器；测试未运行，无截图 |
| f1a7f3ec41bfb0f0cb24b760e9958f907876a86e | https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41266764773 | 构建、测试编译、unit步骤已观察success；UI当时仍运行，最终结果待核对 |
| a05402fc7ef68d371d5ff5af802fcc2e360b8da3 | https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41267424498 | 应用构建通过；新冻结schema测试文件漏@testable import，test编译失败，已定位修正 |

当前源码方法清单为135 XCTest、28 XCUITest，含原93/20；数量不是运行结果。新增真实网络测试与URLProtocol故障/fixture解析严格分开。本地Linux没有Swift/Xcode/Simulator；没有本地iOS编译、真实PNG或xcresult。截图manifest在原生UI附件产生前保持空，不能当截图包交付。

## 尚未完成的硬门槛

1. 最终应用代码的完整构建、XCTest、XCUITest和CI结果。
2. 每项功能及独立失败状态的真实Simulator截图、完整ZIP/CSV/manifest和逐图审阅。
3. 新的真实网络冷启动UI学习全闭环，小/大屏、三主题、最大动态字体和完整VoiceOver。
4. 已新增ArticleHistoryArchiveRecord和生产启动归档迁移，旧周期引用保持且不进入库/推荐；冻结旧schema与归档测试待运行。既有legacy运行时到期处理仍须完整验证，不能清库、破坏引用或删除旧测试断言。
5. 除Wikipedia外的候选仍因权利或逐篇身份核验不足而禁用；没有伪造五源成功。
6. 同义词辨析、完整词形/词源/短语覆盖和语境语义排序仍需扩展；目前语法词性与重合排序不冒称完整语义消歧。
7. Instruments、页面内存、真实设备长文性能和全部异常/重试验证。

手动验证：在对应工具链运行App，从今日进入文章库，点击“发现完整文章”，确认成功入库后离线打开；切换标题/来源/分类、收藏和稍后阅读并重启；阅读中点词查看来源和个人释义；在原周期完成阅读与两阶段复习，确认连线和排程；旧周期未完成时刷新不得覆盖。不能把手动步骤写成已执行证据。
