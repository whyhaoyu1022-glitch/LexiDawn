# 2026-11-20 全量 CI 后的专项修复

负责人要求：先修复已报告的失败，只跑受影响专项；全部通过后再提交一次全量 CI，确认触发后停下，由负责人反馈结果。

## 已完成的全量运行

提交 `86593be52aff9e2b169c35e000366a788b9a5340`，[运行 44542739409](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/44542739409)。Xcode 26.6、iOS 26.5 Simulator 兼容环境，不是 iOS 27 真机结果。

- 全部目标编译、Release、246/246 XCTest 和未签名 IPA 构建通过。
- UI 共 74/77 次执行通过，失败 3 次，均在 iPhone 17 Pro。SE 7/7、Pro Max 3/3、生产首启通过。
- 截图汇总缺 `dictionary-07/10/17`、`vocabulary-review-03/06/08/09`；这是实测失败，不能将产物标记为最终通过包。

| 失败方法 | 日志与实际录屏 | 本批处理 |
|---|---|---|
| `testRound2SettingsPersistAndDisabledAutoAddRequiresManualAdd` | 行 318 等不到撤销。F32 及失败前录屏仍显示“查词中”，加入按钮禁用。 | 等待真实启用且可命中后再手动加入；完成查询后再次检查没有自动加入，保留写入成功和安全撤销断言。 |
| `testGalleryRealRFCVocabularySearchNotesAndRemove` | 行 537 报搜索框没有键盘焦点。原生搜索激活时字段移入导航栏。 | 原生搜索绑定显式焦点及展示状态；测试待键盘出现再输入，并断言实际搜索值。后续笔记、删除和取消流程保留。 |
| `testComplexFormsAndFourContextPhrasesUseNestedLookupAndReturn` | 行 808 在第二个词形 taken 等不到详情启用，录屏仍在查词中。 | 排序原来逐义项重复编码相同原句，跨查询也重算原释义。改为 actor 内有界向量缓存；通过真实 MDX 连续查询和原 UI 时限验证，不用空词义替代加载。 |

两个原始诊断 ZIP 已下载并校验 SHA-256，再读取对应原生录屏和附件：

| 产物 | SHA-256 |
|---|---|
| `14543816562` · full-2 | `0a7eb42b661fa8eabe7fdb427ae995f873af176e1666aeca6eae6151a5181ef4` |
| `14543042477` · full-4 | `f2b63e649130791945f0c63ab8dfcdc0829c73d890df55b43a9a0328568f07b9` |

## 修改与验证边界

- 词典排序以 actor 独占系统 NLEmbedding，最多缓存 256 条截断至 1200 字符的本地派生向量。保留余弦距离、原有词汇和语法权重、MDX 义项与排序标识。向量不写入用户数据库，也不是词典来源。
- 不改变 MDX 文件或解析版本，不更换中文释义来源，不删库或迁移用户学习数据。
- 新增 2 项 XCTest：系统余弦距离对照/缓存边界；真实 MDX 的 took、taken、look、carry、account、role 连续查询与语境身份，保留逐次实际耗时附件。系统句向量不可用时明确记录词汇排序降级，不能伪称进行了原生距离对照。
- 专项再运行现有 `testContextRankingUsesRealExistingDefinitions`，共 3 项 XCTest。UI 只选择表中 3 个失败方法，分别隔离分组。全量 67 个主设备方法和两个设备专项保持完整。
- 专项、全量和最终交付结果待实际执行后分别登记。目前尚未宣称这些修复通过验证。
