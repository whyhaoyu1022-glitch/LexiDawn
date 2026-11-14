# 架构与仓库目录

## 仓库目录

| 路径 | 职责 |
|---|---|
| `LexiDawn.xcodeproj/`、`Package.swift` | Xcode 工程、共享 scheme 和 SwiftPM 清单 |
| `LexiDawn/AppCore/` | 初始化持久化容器，装配依赖与学习服务 |
| `LexiDawn/Domain/` | 学习状态机、来源准入、词形与词义、组题、FSRS 规则 |
| `LexiDawn/Data/` | SwiftData 记录、事务与迁移，文章获取、MDX 和各 Repository |
| `LexiDawn/Features/`、`LexiDawn/DesignSystem/` | 原生页面、视图模型和共用样式 |
| `LexiDawn/Resources/` | 运行资源与原生资产。根目录的 `assets/` 放设计概念 |
| `LexiDawnTests/`、`LexiDawnUITests/` | 单元、真实磁盘迁移、网络、兼容和原生交互验证 |
| `Dictionary Data/` | 两份原始 MDX 分包、验证恢复工具和使用说明 |
| `scripts/`、`.github/workflows/` | 构建、分组、验证、打包和采集证据 |
| `docs/`、`artifacts/` | 现行文档、历史归档、机器清单及运行证据 |

路径是接口的一部分。打包把 `docs/signing.md` 作为安装说明复制到 IPA 的外层 ZIP。截图脚本读取 `docs/reviews/round-4-feedback-manifest.json`、其内三张参考图的 `repositoryFile`、`artifacts/round-4/original-image-recheck.json` 和 `artifacts/round-3/screenshots/coverage-requirements.json`。这些路径变动需要与调用者同步。

## 层与事务

SwiftUI 及 UIKit 控件提供呈现和交互。ViewModel/Service 管理请求与取消、校验输入和调用 Repository。Domain 定义状态、身份和门禁。Repository 拥有 SwiftData 写入、事务和重新读取。应用运行时由 `DependencyContainer` 组装 `LearningServices`。

`RepositoryWriter` 在 MainActor 上为每次写入创建独立 `ModelContext`，关闭自动保存。成功后才发布结果。失败回滚并弃用该上下文，新读操作用独立上下文。跨模型同一业务动作需在同一事务提交。当前受支持的是单应用、单容器、串行写入。早期版本的旧 schema 在冷启动前保留原 store/WAL/SHM，在不改写正文的前提下迁移并留历史快照。真实历史 schema 用冻结夹具建库后再升级。细节见[数据决策](decisions.md)。

## 发现与阅读

`ArticleDiscoveryService` 统一协调今日、书库和探索。来源注册区分 RSS/API/列表和准入依据。HTML 提取器产生结构化块，`ContentRepository` 验证并提交正文和证据。失败留可诊断结果，部分成功已提交的数据保留。完整文章范围见[文章规范](spec-addendum-content-and-dictionary.md)。

`ArticleLearningAccess` 统一处理周期、读者路径、书库标记和历史的阅读门禁。原生 TextKit 渲染文章，`ReaderTextProjection` 维护展示到原文 UTF-16 偏移。词元辅助功能由原生桥接提供。短的词典英文例句使用 SwiftUI 富文本点击，复用同一分词和查词模型。

## 词典与生词

`DictionaryLookupService` 调用 `BundledMDXDictionaryProvider` actor。C 读引擎和 zlib 按需读取记录块，系统 libxml2 解析 HTML 字段。Swift 首次查询校验 SHA 并建立索引，内存缓存最多 128 个查询词。缓存绑定 MDX SHA 和 HTML 解析版本（当前 `html-9`）。同 SHA 的旧派生记录号可帮助定位，显示数据须经当前解析版本读取。支持范围见[实际文件格式](<../Dictionary Data/README.md>)。

详情、简明浮层、生词、推荐和复习共享词义身份。领域策略、服务和 Repository 同时审核个人中文写入资格。变更义项会保存修订历史，笔记独立保存。旧第三方缓存与旧个人文本留历史。原有解析或故障夹具属于测试路径，Release 的词典查询指向内置 MDX。

## 复习

`ReviewEntryCoordinator` 统一预检，`ReviewRepository` 保存题组与冻结答案，`MatchingBoard` 负责真实连线布局，`FSRSScheduler` 保存算法版本 `fsrs-4.5-lexidawn-1` 和可重放的评分证据。一次提交包含答题、日志、排程和关联周期变化。事件重复提交幂等，已完成会话不能被较旧的结果覆盖。额外复习使用自己的会话 ID 和事件域。

## 验证入口

原生测试和 Release 核验在 macOS Actions 执行。产品目标最低 iOS 27.0，当前 Xcode 26.6 / iOS 26.5 Simulator 仅用于兼容验证。按[测试计划](test-plan.md)区分仓库检查、宿主 MDX 检查、原生测试、真机与独立实拍审阅。
