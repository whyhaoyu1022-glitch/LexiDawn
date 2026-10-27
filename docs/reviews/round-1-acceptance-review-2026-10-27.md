# LexiDawn 第一轮开发验收与代码审查报告

- 审查日期：2026-10-27
- 审查对象：Round 1 — Daily Study Cycle, Persistence, Today Dashboard
- 仓库：https://github.com/whyhaoyu1022-glitch/LexiDawn
- 被审查分支：`round1-daily-cycle`
- 被审查代码 HEAD：`c13906ae66515c29cb9a602da061caf810a62ade`
- PR：https://github.com/whyhaoyu1022-glitch/LexiDawn/pull/1
- 审查时 main HEAD：`c9f9cdd47cfc117ee342b1700ddca5373eb7842a`
- 结论：**验收不通过；不建议在当前状态下合并第一轮功能代码。**
- 审查边界：已检查分支源码、Xcode 工程配置、测试代码、需求追踪、开发日志、CI workflow 和 GitHub Actions 实际日志。当前审查环境不能运行本地 Xcode，也未进行真实 iPhone 手动测试；凡无实测证据的项目均标为未验证，不推断通过。

---

## 1. 总结

第一轮确实交付了有价值的工程基础：每日学习周期领域模型、状态枚举、跨日续接服务、SwiftData 模型、Repository、共享 ModelContainer、数据驱动的今日首页、13 项新增业务单元测试，以及首页空状态 UI 测试。CI 已经能够在 iOS 26.5 兼容模拟器目标上执行构建和测试。

但目前发现的核心问题影响产品不变量和真实用户流程。最重要的两个问题是：

1. 领域层允许把必做文章任务标记为 deferred，并将其视为完成，绕过了必须完成阅读的规则。
2. 今日页的“开始阅读/开始复习/开始练习”按钮只把任务状态改成 inProgress，没有进入实际功能页，也没有完成或恢复流程；用户操作后会进入无法从当前 UI 继续完成的状态。

因此，**CI 绿色只证明当前被执行的构建与测试通过，不代表每日学习周期在所有业务场景下正确。** 目前测试没有覆盖上述两个关键缺陷。

### 1.1 优先级定义

- **P0 — 阻断验收：** 违反核心产品不变量，或使主要流程进入无法继续的状态。
- **P1 — 必须修复：** 数据一致性、关键测试覆盖或需求实现不完整；修复前不应认定该功能交付完整。
- **P2 — 质量/后续风险：** 代码质量、可维护性、验证范围或非当前主流程缺陷，需要明确记录并按优先级处理。

### 1.2 发现项总览

| 编号 | 优先级 | 问题 | 结论 |
|---|---|---|---|
| R1-001 | P0 | 必做文章可以 deferred 并完成整个周期 | 不通过 |
| R1-002 | P0 | 首页任务按钮将任务置为 inProgress 后无可用完成路径 | 不通过 |
| R1-003 | P1 | isCurrent 未保持唯一，缺少 completionReason | 不完整 |
| R1-004 | P1 | 周期创建未实现数据库层唯一约束/原子事务 | 不完整 |
| R1-005 | P1 | 保存失败后的“重试”没有重试失败操作 | 不通过 |
| R1-006 | P1 | 持久化测试只使用内存容器，未验证真正的磁盘恢复 | 未验证 |
| R1-007 | P1 | 文章模型字段缺失，候选文章没有许可/可读性门禁 | 不完整 |
| R1-008 | P1 | 业务与 UI 测试没有覆盖上一轮计划要求的多项边界 | 不完整 |
| R1-009 | P1 | CI/架构文档与实际 Xcode 配置不一致 | 不通过 |
| R1-010 | P1 | 状态、日志、追踪矩阵未反映最新绿色 CI | 文档不准确 |
| R1-011 | P2 | 跨时区回拨时可能错误增加 carryOverCount | 逻辑风险 |
| R1-012 | P2 | 文章去重、候选校验和编译警告仍有改进空间 | 质量风险 |
| R1-013 | P2 | ModelContainer 创建失败会直接 fatalError | 恢复能力不足 |
| R1-014 | P2 | 分支提交历史可追踪性差；真实设备/无障碍仍未验收 | 过程与验证风险 |

---

## 2. GitHub 分支、PR 与提交历史核查

### 2.1 分支状态

审查时 GitHub 返回：

- 默认分支：main
- 功能分支：round1-daily-cycle
- PR #1 状态：open，尚未合并
- PR base：main
- PR head：round1-daily-cycle
- 比较结果：功能分支相对 main ahead 33 commits，behind 0
- 功能分支 HEAD：c13906ae66515c29cb9a602da061caf810a62ade

链接：

- [PR #1](https://github.com/whyhaoyu1022-glitch/LexiDawn/pull/1)
- [round1-daily-cycle 分支](https://github.com/whyhaoyu1022-glitch/LexiDawn/tree/round1-daily-cycle)
- [main 分支](https://github.com/whyhaoyu1022-glitch/LexiDawn/tree/main)
- [分支差异](https://github.com/whyhaoyu1022-glitch/LexiDawn/compare/main...round1-daily-cycle)

**重要：第一轮实现尚未进入 main。** 不能把 PR 创建或功能分支 CI 通过视为 main 已经获得这些功能。

### 2.2 提交历史质量

功能分支相对 main 有 33 个提交。第一轮初始功能实现阶段出现了多条连续提交，使用完全相同的提交说明 “feat: implement Round 1 daily study cycle and today dashboard”；之后也有重复的修复说明。重复提交说明本身不能证明代码有缺陷，但降低了审查时对每个提交意图和变更范围的可追踪性。

建议以后每个有意义的功能切片使用准确的提交说明，避免为同一项实现连续产生大量同义提交。按用户要求，**本次没有合并 PR、删除分支或更改分支结构**；第二轮计划必须明确处理现有分支并回到单一 main 工作流。

---

## 3. GitHub Actions / CI 验收

### 3.1 第一轮分支最新检查

最新可查的 PR 检查：

[Actions run 40416668214 — Round 1 PR head](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/40416668214)

检查到的 job 为 build-and-test，结论 success。各步骤均为成功：

- 检查工具链与目标版本
- 安装并验证 iOS 26.5 Simulator runtime
- 在 runner checkout 中应用兼容 Deployment Target
- 未签名模拟器构建
- 创建、启动并验证 scheme 接受的具体 iOS Simulator
- 单元测试
- UI 测试

从该 job 日志可核实：

- 单元测试：15 tests，0 failures
- UI 测试：2 tests，0 failures
- 日志出现 TEST SUCCEEDED
- UI 测试实际执行了五个主导航入口的切换检查，以及首页无候选文章状态检查

较早的前一次绿色运行：[Actions run 40416653830](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/40416653830)。

### 3.2 历史失败及修复情况

本轮期间存在多次失败，后续修复后才出现绿色结果：

- [run 40337877307](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/40337877307)：构建通过，但 Xcode 没有列出具体 iOS Simulator 目的地，测试未启动。
- [run 40415631070](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/40415631070)：单元测试编译失败，错误涉及测试闭包中隐式使用 self；UI 测试因前一步失败而被跳过。
- [run 40416668214](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/40416668214)：后续修复后，构建、单元测试和 UI 测试全部通过。

因此，当前分支 CI 结果可以判定为**通过**；历史失败已经有后续绿色运行覆盖。但这不代表真实设备、iOS 27 产品目标或未覆盖的业务边界已通过验收。

### 3.3 main 的 CI 状态必须单独看待

审查时 main 最近一次可查的运行仍为失败：

[main Actions run 40184339319](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/40184339319)

当时未签名模拟器构建通过，但测试阶段因 Xcode 不接受脚本选择的模拟器目的地而失败。由于 Round 1 仍在功能分支，分支上的修复尚未进入 main。

**结论：第一轮分支 CI 通过；main 的已知 CI 状态仍失败。** 这两个结论不能混为一谈。

### 3.4 CI 验收范围限制

当前 workflow 使用 Xcode 26.6 与 iOS 26.5 兼容模拟器目标。常规工程配置仍声明 iOS 27.0，但这次绿色测试并不是 iOS 27.0 SDK/运行时验收，也不证明最终 IPA 可安装。

此外，最新测试日志中出现 CoreData/SwiftData 持久化存储创建失败（NSCocoaErrorDomain Code 512、Sandbox access to file-write-create denied）的日志，随后 CoreData 报告 recovery attempt successful，UI 测试继续通过。当前证据不足以断定它是产品代码缺陷还是模拟器环境问题，但不能把这段日志忽略：应在后续测试中确认真实磁盘存储创建、关闭和重开是否稳定。

日志还出现模拟器 Accessibility bundle 重复类和 app launch measurement 事件失败等系统环境警告；这些不应直接归因于应用代码。源码仍存在一处可消除的 Swift 编译警告：DailyTasks.swift 中 usedArticleIDs 声明为 var 但未被修改。

### 3.5 CI 工作流与文档不一致

实际检查：

- [workflow 文件](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/.github/workflows/ios-ci.yml)
- [Xcode project 文件](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn.xcodeproj/project.pbxproj)

workflow 第 40–50 行通过 Python 在 runner 的 checkout 中把 project.pbxproj 内的 iOS 27.0 Deployment Target 文本替换为 26.5；后续 build/test 命令使用 Debug configuration。实际提交的 project.pbxproj 中只有 Debug/Release 配置，没有名为 CI 的独立 build configuration。

但以下文档都声称存在独立 CI configuration：

- README.md
- CHANGELOG.md
- STATUS.md
- docs/architecture.md

这是事实描述不一致。CI 在 checkout 中临时改文件，与工程内有独立 CI configuration 是两件不同的事。文档必须改为准确描述实际实现，或者工程真正增加并使用独立 CI configuration。

另外，workflow 的 push 触发器仅包含 main，pull_request 触发器面向 main；STATUS/CHANGELOG 所说“直接 push 到 round1-daily-cycle 也会运行 CI”并不符合当前 YAML 的 push 分支配置。当前分支有开放 PR，因此分支更新会触发 PR 检查，但这不等于独立 push 触发器包含该分支。

workflow 也没有设置 resultBundlePath 或上传 xcresult artifact 的步骤。GitHub Actions 控制台日志可查看，但测试结果包不会作为 workflow artifact 保存，降低了事后复核完整测试详情的便利性。

---

## 4. P0 阻断问题：必须先修复

### R1-001 — 必做文章任务可以被 deferred，从而错误完成周期

代码证据：

- [DailyTasks.swift 第 26 行](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L26)：TaskStatus.isSatisfied 将 completed 与 deferred 都视为满足条件。
- [DailyTasks.swift 第 167–175 行](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L167)：DailyStudyCycle.isComplete 对文章、复习和两个阶段统一使用 isSatisfied。
- [DailyTasks.swift 第 178–205 行](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L178)：update(task:to:reason:at:) 没有针对不同任务限制 deferred 的合法性。

问题原因：

当前状态迁移允许 ready → deferred，只要求提供原因；DailyStudyCycle.update 没有禁止 article 任务进入 deferred。因此，只要调用领域服务把文章标记为 deferred，且其他任务也都 completed/deferred，isComplete 就会返回 true，并设置 completedAtUTC。

这直接违反 SPEC §2.1 的每日必做文章规则，以及 §2.5 的阅读完成定义。阅读任务必须真实完成，不能因“无需执行”而略过。

**必须修复：**

1. 周期完成规则必须明确区分任务类型：文章任务必须为 completed；只有按产品规则确实无需执行的复习任务/阶段才可以 deferred。
2. 在领域服务或领域模型中拒绝 article → deferred，不应只依赖 UI 不显示这个按钮。
3. 为文章 deferred 的非法操作添加单元测试。
4. 添加回归测试证明文章未完成时，即使复习任务和两个阶段都 deferred，整个周期仍然未完成。
5. 检查 completedAtUTC 只能在满足真实完成条件时设置。

**验收判定：不通过，阻断合并。**

### R1-002 — 首页开始任务后进入 inProgress，但没有任何完成路径

代码证据：

- [TodayFeature.swift 第 53 行](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/Features/Today/TodayFeature.swift#L53)：retry() 只调用 load()。
- [TodayFeature.swift 第 55–76 行](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/Features/Today/TodayFeature.swift#L55)：start(task:) 只调用 updateTask(..., to: .inProgress)，然后重新加载首页状态。
- [TodayFeature.swift 第 174–194 行](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/Features/Today/TodayFeature.swift#L174)：“开始阅读”“开始复习”“开始连线阶段”“开始拼写补全”都只调用 start(task:)。
- [TodayFeature.swift 第 177 行](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/Features/Today/TodayFeature.swift#L177)：阅读进入 inProgress 后只显示“阅读器尚未接入；当前状态已保存为进行中。”

问题原因：

用户点击“开始阅读”后，任务状态被持久化为 inProgress，但没有打开阅读器，也没有阅读进度、完成确认或恢复操作。其他三个任务按钮同样只把对应状态改成 inProgress，点击后按钮只在 ready 状态显示，因此当前 UI 不再提供任何继续操作。

后果是：一旦用户点击这些按钮，当前任务会被留在进行中状态；当前页面无法将其完成或合法 deferred。由于旧周期优先，周期可能长期无法清空，后续每日必做周期也无法创建。

这不是“暂时没有阅读器”本身的问题，而是 UI 先改变了持久化业务状态，却没有提供对应的真实流程。它违背了本轮计划“不能用无真实行为的按钮假装功能已经接通”的要求，也不符合 SPEC §25 对真实行为和失败路径的验收标准。

**必须修复：**

- 若阅读器/复习题流程尚未实现，按钮不得把任务永久置为 inProgress。可以显示明确的未接入状态，但不得制造一个无法继续的业务状态。
- 或者提供真实可运行的任务流程，包括进入、完成、失败/阻塞恢复以及返回首页后的状态更新。
- 每个开始按钮都必须有对应的 UI 自动化测试。
- 必须证明用户可以从 ready → inProgress → completed 的真实流程完成任务，并且跨页面返回后状态一致。
- 还需验证复习空队列时，系统如何合法标记 deferred 并完成周期。

**验收判定：不通过，阻断合并。**

---

## 5. P1 问题：数据模型与业务一致性

### R1-003 — isCurrent 没有唯一性维护，且缺少 completionReason

证据：

- [SPEC.md §19.3](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/SPEC.md)：isCurrent 当前周期标识需保持唯一；同时定义 completionReason。
- [DailyTasks.swift 第 118–159 行](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L118)：DailyStudyCycle 的 isCurrent 默认值为 true。
- [DailyTasks.swift 第 247 行起](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L247)：ensureCurrentCycle 创建新周期时没有把旧周期 isCurrent 设为 false。
- [PersistenceModels.swift 第 63–90 行](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/Data/PersistenceModels.swift#L63)：isCurrent 只是普通 Bool，没有唯一性约束或维护逻辑；模型没有 completionReason 字段。

问题原因：

当前创建的周期默认 isCurrent=true，旧周期完成后不会被设置为 false；新周期创建后，数据库中可能存在多个 isCurrent=true 的记录。虽然当前 Repository 暂时不使用 isCurrent 查询，但 SPEC 明确要求该标记保持唯一，不能留到未来页面才发现历史数据不一致。

DailyStudyCycle 还缺少规格中的 completionReason。任务阶段 reason 字段不能完全替代“周期为什么完成”的周期级记录。

**必须修复：**

- 在创建/完成周期时维护唯一的当前周期标记，或使用明确且一致的等价设计。
- 增加测试：完成旧周期并创建新周期后，数据库中最多只有一个当前周期。
- 增加 completionReason，或先记录与规格的正式差异并说明替代方案。
- 迁移/默认值策略需要与模型变更一起记录。

### R1-004 — 周期创建没有数据库层唯一约束和原子事务

证据：

- [SPEC.md §2.3](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/SPEC.md)：明确要求周期创建使用数据库事务和幂等约束。
- [Repositories.swift 第 27–40 行](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/Data/Repositories.swift#L27)：周期记录只按 cycleID upsert，没有 assignedLocalDate 唯一约束。
- [Repositories.swift 第 47–75 行](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/Data/Repositories.swift#L47)：文章记录保存会单独执行 context.save()。
- [DailyTasks.swift 第 247–292 行](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L247)：ensureCurrentCycle 先查询，再选择候选，再保存文章和周期。

现状：

同一日期的顺序重复调用测试通过，但“先查无记录，再创建”的幂等性主要由服务层查询保证。数据库没有按日期限制重复周期，也没有原子地保证两个同时发起的请求不能创建两条相同日期记录。

此外，文章先保存、周期后保存，是两次分开的保存操作。如果文章保存成功而周期保存失败，就可能留下孤立的 ArticleRecord。虽然当前主 UI 调用在主线程同步执行，但领域/Repository 层没有落实规格要求的数据库级不变量。

**必须修复：**

- 用数据库约束、事务性 Repository 操作或等价的可靠机制保证同一安装实例/本地学习日期不会重复建立必做周期。
- 把文章记录与周期记录的创建纳入一致的保存边界，避免部分成功。
- 增加重复/并发创建和保存失败测试；测试必须检查数据库最终记录数量，而不只是检查服务返回值。

### R1-005 — 保存失败后“重试”没有重试原操作

证据：

- [TodayFeature.swift 第 53 行](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/Features/Today/TodayFeature.swift#L53)：retry() 只调用 load()。
- [TodayFeature.swift 第 122–126 行](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/Features/Today/TodayFeature.swift#L122)：saveFailed 状态展示“重试”按钮，但 action 是 viewModel.retry()。

问题原因：

当 start(task:) 保存失败时，状态切换为 saveFailed。用户点击“重试”只重新加载数据，不会重试之前失败的 updateTask。因此按钮标签与真实行为不一致，用户无法通过该按钮重试失败的写操作。

**必须修复：**

- 保存失败状态必须保留失败操作所需的上下文，或者让用户重新发起同一操作。
- “重试”必须真正重试失败的写入；“重新读取”则应使用不同标签。
- 使用可注入的失败 Repository/Store 测试失败、重试成功和状态恢复。

### R1-006 — 持久化测试没有验证磁盘数据库重开

证据：

- [LexiDawnTests.swift 第 158–180 行](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawnTests/LexiDawnTests.swift#L158)：测试使用 ModelConfiguration(isStoredInMemoryOnly: true)，随后仅重建 ModelContext，仍复用同一个 ModelContainer。

该测试可以证明同一内存容器内不同 ModelContext 可以重新读取数据，但不能证明真正的磁盘存储在容器关闭、重新创建或应用重启后仍可恢复。

本轮计划明确要求使用临时磁盘数据库重开容器，验证关键数据恢复；当前测试未满足这一项。

**必须补测：**

1. 使用临时磁盘 URL 创建 ModelContainer。
2. 写入 ArticleRecord、DailyStudyCycleRecord 和 UserPreferencesRecord。
3. 释放原 Repository/ModelContext/容器。
4. 用同一临时存储重新创建容器并读取。
5. 验证周期状态、日期、时区、文章关联、偏好和时间戳仍一致。
6. 清理临时数据库，确保测试之间互不污染。

当前只能判定为“内存容器恢复测试通过”，不能判定“应用重启后磁盘数据恢复已通过”。

### R1-007 — ArticleRecord 不完整，候选文章缺少许可与可用性门禁

证据：

- [SPEC.md §19.1](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/SPEC.md) 定义了 displayTitle、difficulty、imageURL、imageAttribution 等文章字段。
- [PersistenceModels.swift 第 1–40 行](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/Data/PersistenceModels.swift#L1) 当前 ArticleRecord 缺少 displayTitle、difficulty、imageURL、imageAttribution。
- [PersistenceModels.swift 第 19 行](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/Data/PersistenceModels.swift#L19)：contentStatus 使用任意 String，而非受约束的状态类型。
- [Repositories.swift 第 47–75 行](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/Data/Repositories.swift#L47)：候选保存时使用 ArticleRecord 默认值，licenseVerified 默认 false、contentStatus 默认 unavailable、bodyText 默认 nil。
- [DailyTasks.swift 第 247–292 行](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L247)：周期服务没有验证候选文章是否已核验许可或有可读内容，就可以分配周期。

说明：

当前生产 provider 是 EmptyArticleCandidateProvider，因此生产首页会诚实显示无候选状态，不会立即把虚构文章当作真实文章。这一点是正确的。

但是当前候选协议只包含 id、URL、标题和 sourceID；一旦后续只把真实来源接入这个 provider，服务仍可能分配一个没有许可核验、正文不可用的 ArticleRecord。也就是说，“生产当前没有假文章”是通过 provider 为空实现的，尚未形成可安全接入真实文章来源的完整数据契约。

**必须在文章源接入前修复：**

- 补齐规格要求的 Article 元数据字段，或在追踪矩阵记录明确的分阶段实现。
- 候选对象/服务必须能验证规范化 URL、标题、来源以及许可核验状态。
- 不能把 licenseVerified=false 或 contentStatus=unavailable 的文章分配为可阅读任务。
- 为缺正文、未核验许可、无效 URL、重复 canonicalURL 等情况添加测试。
- contentStatus 应使用明确的状态枚举或等价的严格校验，避免任意字符串。

### R1-008 — 测试虽全绿，但没有覆盖本轮计划要求的关键场景

最新 CI 的 15 项单元测试和 2 项 UI 测试都通过。问题不是测试失败，而是覆盖面不足。

现有测试覆盖了：

- 首次建立周期
- 同日顺序重复调用
- 无候选不建立伪周期
- 同一天已完成后不重复建立周期
- 旧未完成周期优先
- 同一天重复刷新不重复增加 carry-over
- 文章与复习状态独立
- 一部分合法/非法状态迁移
- deferred 原因检查
- blocked/failed 不算完成
- 一个跨时区场景
- 同一内存 ModelContainer 内重建 Repository
- ViewModel 的无候选状态与 Fixture 周期状态
- 原有 Design Token 与导航测试
- 五入口 UI 切换和无候选 UI

仍缺少或没有真正验证的场景：

1. 文章 deferred 不得完成周期。
2. 复习完成但文章未完成，跨日仍保留原周期。
3. 连线完成但拼写阶段未完成，跨日仍保留原周期。
4. 旧周期完成后，下一符合条件的本地日期能建立新周期并选择未使用文章。
5. 连续多日跨日后，最早未完成周期仍被优先恢复。
6. 时区变化使本地日期回拨时 carry-over 计数正确。
7. 夏令时变化和不同本地日期边界。
8. 磁盘数据库在容器关闭后重新打开仍能恢复。
9. 周期创建过程的部分保存失败与数据库重复约束。
10. 首页加载真实周期时，真实 UI 显示文章标题、日期、逾期状态和四个子任务状态。
11. UI 点击任务按钮后有真实导航/完成路径，而不是只变为 inProgress。
12. UI 重试按钮被实际点击，并验证重试的真实效果。
13. 保存失败后真正重试同一写操作。
14. 无效候选文章、未核验许可、缺少正文和重复 canonicalURL。
15. 数据模型迁移/旧数据兼容。

其中部分测试未覆盖项是 R1-001、R1-002 等已确认缺陷的直接原因。必须先修复业务逻辑，再新增回归测试，不能只增加测试数量。

---

## 6. P2 问题：日期逻辑、Repository 与启动恢复能力

### R1-011 — 时区回拨时可能错误增加 carryOverCount

证据：

- [DailyTasks.swift 第 206–214 行](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L206)

markCarryOverIfNeeded 的条件判断 assignedLocalDate != localDate。只要当前本地日期与原分配日期不同就可能计数，而不是确认当前日期晚于原分配日期。

用户跨时区旅行、时区配置变化导致本地日期回拨时，周期可能尚未逾期，却错误增加 carryOverCount。现有跨时区测试只覆盖了日期向前变化的一个场景。

建议以经过验证的本地日期顺序判断是否真正跨到后续学习日期，并添加回拨、前进、重复刷新和夏令时边界测试。

### R1-012 — ArticleRepository 去重和候选验证不充分，存在编译警告

证据：

- [Repositories.swift 第 43–75 行](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/Data/Repositories.swift#L43)：ArticleRepository 主要按 articleID upsert，未按 canonicalURL 去重。
- [DailyTasks.swift 第 268 行](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L268)：usedArticleIDs 声明为 var，但没有修改；CI 编译日志出现“variable was never mutated”的警告。

建议：

- 为 canonicalURL 建立规范化和去重策略，防止同一原文以不同 ID 重复进入候选池。
- 对 ArticleCandidate 做字段校验，避免空标题、空来源和无效 URL 进入周期。
- 清理未使用的 allArticleIDs/无效错误类型等死代码，或让它们承担明确职责。
- 将不需要变更的 var 改为 let，减少可消除的编译警告。

### R1-013 — ModelContainer 创建失败时应用直接崩溃

证据：

- [LexiDawnApp.swift](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/LexiDawnApp.swift)

应用初始化中，如果 ModelContainer 创建失败，catch 会调用 fatalError。对于依赖本地数据库的应用，这会导致启动阶段直接崩溃，没有可理解的错误说明或恢复路径。

建议在产品化之前提供可观察的启动错误处理策略，例如显示存储不可用页面、提供安全恢复说明，或在确认数据安全的前提下进行受控恢复。不能静默清空已有用户数据来绕过错误。

---

## 7. 文档、追踪矩阵与实际状态核查

### R1-010 — 文档未更新到最新真实 CI 结果

当前分支的以下文件仍记录“修复后的 Actions 结果待确认”或把相关需求标为“待 CI/未确认”：

- [STATUS.md](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/STATUS.md)
- [CHANGELOG.md](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/CHANGELOG.md)
- [docs/daily/2026-10-26.md](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/docs/daily/2026-10-26.md)
- [docs/requirements-traceability.md](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/docs/requirements-traceability.md)
- [docs/test-plan.md](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/docs/test-plan.md)

但在这些文件对应的后续提交之后，已经有 run 40416653830 和 run 40416668214 两次绿色 CI。文档没有记录最新通过的测试数量、运行链接和最终状态。

这属于实际证据与交付报告不同步。不能把“本地没有 Xcode、未运行本地测试”写成“CI 结果尚未确认”；两者应分别记录。

### 7.1 仍未完成的产品模块必须继续保持未完成状态

本轮诚实保留了探索、词汇、复习、我的页面的占位说明，生产候选文章 provider 为空，没有使用虚构文章填充首页。这一点符合“不能把 Fixture 冒充真实数据”的要求。

但以下功能仍未完成，不应因为本轮 CI 通过而标记为完成：

- 真实文章来源、许可核验、文章正文缓存和阅读器
- 阅读进度保存/恢复及阅读完成确认
- 词义浮窗、详细词典页、生词本
- 真正的复习队列、连线题和拼写补全题
- 探索/词汇推荐的锁定与解锁规则
- 设置界面、偏好与实际通知安排的连接
- 无障碍、动态字体、深色模式和真实设备验收
- iOS 27 产品目标的构建验证
- 签名 IPA 和真实安装路径

这些是后续模块，不应伪装成 Round 1 已完成的能力。

---

## 8. 对上一轮开发计划逐项验收

| 上一轮验收要求 | 当前证据 | 判定 |
|---|---|---|
| TaskStatus 状态枚举 | 已实现七种状态 | 通过（但任务类型约束缺失） |
| 非法状态迁移有明确错误 | 有基础迁移校验测试 | 部分通过 |
| 文章任务与复习任务独立 | 有单元测试 | 部分通过 |
| 文章必须真实完成，复习空队列可合法 deferred | 文章也能 deferred 并满足周期 | 不通过 |
| 同日重复调用不重复创建 | 顺序调用测试通过 | 部分通过（缺数据库约束/原子性） |
| 未完成旧周期优先 | 基础场景测试通过 | 部分通过（缺多种部分完成状态） |
| 跨时区不覆盖原任务 | 有一个跨时区测试 | 部分通过 |
| carry-over 重复刷新幂等 | 有测试 | 部分通过（时区回拨未覆盖） |
| ArticleRecord 字段完整且候选有效 | 缺少多个规格字段，缺许可/可用性门禁 | 不通过/不完整 |
| DailyStudyCycle 当前周期唯一 | isCurrent 没有维护唯一性 | 不通过 |
| Preferences 默认值 | 06:20、21:20、自动加入有测试 | 部分通过 |
| 应用重启后磁盘数据恢复 | 仅内存容器 + 新 ModelContext 测试 | 未验证 |
| 今日首页读取真实 Repository 数据 | ViewModel 测试覆盖 Fixture | 部分通过 |
| 首页开始任务后能真实继续/完成 | 只更新 inProgress，无目标页面 | 不通过 |
| 空候选状态真实且无假文章 | 生产空 provider + UI 测试 | 通过 |
| 错误状态有真实重试 | 保存失败重试实际只是 reload | 不通过 |
| 五个主导航保持顺序和可操作 | UI 测试通过 | 通过 |
| 所有核心 UI 状态都有测试 | 仅导航和空状态 UI 测试 | 不完整 |
| CI 构建和单元/UI 测试通过 | 最新 PR run 全部通过 | 通过（iOS 26.5 兼容目标） |
| CI 与文档状态同步 | 文档仍写待确认，且声称不存在的 CI configuration | 不通过 |
| 保存完整测试结果证据 | Actions 控制台日志可看，未上传 xcresult artifact | 部分通过 |
| 不因为 CI 未结束提前结束开发 | 本轮有多个连续提交与失败后修复，最新运行通过 | 结果通过，但提交/状态记录质量需改善 |

---

## 9. 必须完成的整改清单

在把第一轮标记为合格之前，至少需要以下整改：

### P0：必须先完成

- [ ] 修复文章任务 deferred 可以满足周期完成条件的问题。
- [ ] 修复首页开始任务后无真实目标/完成路径的问题；不能只把状态改为 inProgress。
- [ ] 为以上两项分别新增回归测试，并在 CI 中真实运行。

### P1：数据正确性与测试

- [ ] 维护唯一的 isCurrent，并补齐/说明 completionReason。
- [ ] 建立同一学习日期的数据库级唯一性和事务/原子保存策略。
- [ ] 修复保存失败后“重试”只重新加载的问题。
- [ ] 增加真正的磁盘数据库重开测试。
- [ ] 增加“复习完成、文章未完成”“连线完成、拼写未完成”“旧周期完成后下一日期创建新周期”等场景。
- [ ] 补齐 ArticleRecord 规格字段，或在追踪矩阵中明确阶段化范围。
- [ ] 在候选进入周期前验证内容许可和可用性。
- [ ] 增加首页真实周期 UI 测试与开始/完成操作测试。
- [ ] 修正文档中对 CI configuration、触发分支和最新测试结果的不准确描述。

### P2：代码质量与可验证性

- [ ] 修复跨时区回拨时 carryOverCount 可能误增的问题。
- [ ] 补充 canonicalURL 去重和候选字段校验。
- [ ] 清理可消除的 Swift 编译警告。
- [ ] 为 ModelContainer 创建失败提供可理解的启动错误处理。
- [ ] 后续完成无障碍、动态字体、深色模式和真实设备验收。
- [ ] 改善提交说明，使每个提交意图和变更范围可追踪。

---

## 10. 下一轮分支策略要求（本次不执行分支操作）

用户已明确要求以后只保留 main 作为开发主线。本次不合并、不删除 round1-daily-cycle；但第二轮计划必须写明：

1. 开始第二轮前先核对 main、round1-daily-cycle 与 PR #1 的最新 SHA，确保第一轮代码不会丢失。
2. 先修复本报告的 P0 问题；不能为了“合并进 main”而直接合并有阻断缺陷的代码。
3. 在把通过整改的第一轮成果纳入 main 时，保留本审查报告，并核对 main 上的所有变更。
4. 确认第一轮所需提交已经完整进入 main、main 上的构建和测试证据已记录之后，再删除 round1-daily-cycle。
5. 后续开发直接在 main 上进行；不要创建 round2 或其他新的开发分支，不要再用 PR 分支作为日常开发主线。
6. 不要因为提交后 CI 还在运行就停止实际开发；必须完成所有计划中的功能、测试和审查。未完成的 CI 只能如实标为运行中/未确认，不能写成通过。

---

## 11. 最终验收结论

**Round 1 当前结论：不通过，暂不建议合并当前功能分支。**

通过项：

- CI 最新分支检查成功；
- 15 项单元测试与 2 项 UI 测试通过；
- 基础状态模型、跨日恢复的部分逻辑、SwiftData 模型/Repository、共享容器和首页空状态已经有实际实现；
- 没有在本轮生产流程中用虚构文章伪装真实候选。

阻断项：

- 必做文章可以被 deferred 后错误完成；
- 首页任务操作进入 inProgress 后没有真实完成路径。

其他必须整改/补证据的事项包括当前周期唯一性、事务与幂等约束、保存失败重试、磁盘持久化验证、文章许可/可用性门禁、测试覆盖和文档一致性。

本报告仅是验收记录，不代表这些缺陷已修复。只有整改代码和新增回归测试都进入可审查的仓库状态，并由后续 CI 与代码复核提供证据后，才能重新判定通过。

---

## 12. 证据索引

- [PR #1](https://github.com/whyhaoyu1022-glitch/LexiDawn/pull/1)
- [最新第一轮绿色 CI run 40416668214](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/40416668214)
- [此前绿色 CI run 40416653830](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/40416653830)
- [此前单元测试失败 run 40415631070](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/40415631070)
- [此前模拟器目的地失败 run 40337877307](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/40337877307)
- [main 最近已知失败 run 40184339319](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/40184339319)
- [SPEC.md](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/SPEC.md)
- [DailyTasks.swift](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/Domain/DailyTasks/DailyTasks.swift)
- [PersistenceModels.swift](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/Data/PersistenceModels.swift)
- [Repositories.swift](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/Data/Repositories.swift)
- [TodayFeature.swift](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn/Features/Today/TodayFeature.swift)
- [单元测试](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawnTests/LexiDawnTests.swift)
- [UI 测试](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawnUITests/LexiDawnUITests.swift)
- [CI workflow](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/.github/workflows/ios-ci.yml)
- [Xcode project](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/LexiDawn.xcodeproj/project.pbxproj)
- [需求追踪矩阵](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/docs/requirements-traceability.md)
- [测试计划](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/round1-daily-cycle/docs/test-plan.md)
