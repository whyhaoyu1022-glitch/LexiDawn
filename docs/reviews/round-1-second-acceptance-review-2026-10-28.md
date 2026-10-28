# LexiDawn 第一轮整改后的第二次独立验收报告

- 审查日期：2026-10-28
- 审查性质：针对第一轮整改的独立复验；不采信整改报告中的结论，逐项复核代码、测试、CI 和文档
- 仓库：https://github.com/whyhaoyu1022-glitch/LexiDawn
- 本次审查的代码基线：`ee8eee95526d91623ed40803a550b8dfeab55c07`
- 最新代码与文档 CI：[run 40600352579](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/40600352579)
- 被复核的 AI 整改报告：[round-1-remediation-report-2026-10-27.md](round-1-remediation-report-2026-10-27.md)
- 上一份独立验收报告：[round-1-acceptance-review-2026-10-27.md](round-1-acceptance-review-2026-10-27.md)
- **最终结论：第二次验收仍不通过；不建议将本轮标记为完全合格。**
- 本次仅新增本审查报告，没有修改应用源码、测试、工程配置或 CI workflow。

---

## 1. 执行摘要

本轮整改有实质进步，不是简单改文档：第一轮的两个最明显问题得到部分修正，文章任务在领域更新入口不能被标记为 `deferred`，未接入的首页按钮也已禁用且不会再写入 `inProgress`。数据模型和 Repository 扩充了文章字段、周期完成原因、URL 去重、磁盘容器重开测试；CI 也能够完成应用构建、测试 target 编译、单元测试和 UI 测试。

但是，独立复核发现整改仍有未闭环的核心不变量和测试/文档夸大问题。最关键的未解决项是：

1. **复习任务仍可通过任意非空字符串理由被标记为 `deferred`，并因此完成整个周期；代码没有证明复习队列确实为空。** 测试甚至使用 `"test"` 这样的理由将复习阶段 deferred 后视为完成。这仍然绕过了规格中的“只有系统明确判定无需执行才可 deferred”。
2. **领域模型和持久化解码仍能接受不合法状态组合。** 例如 `DailyStudyCycle` 初始化或从 SwiftData 还原时可以出现“文章 deferred、周期永远未完成且 deferred 又不可迁移”的卡死状态；复习阶段 deferred 也不强制要求存在合法原因。
3. **原子保存/失败恢复只在部分代码路径成立。** 生产周期创建路径有同一个 `ModelContext.save()` 和 rollback，但服务仍保留非原子 fallback；普通周期更新和文章/偏好 Repository 的保存失败路径没有统一 rollback。相关测试使用假 Store，没有验证真实 SwiftData 保存失败后的上下文状态。
4. **部分测试与整改报告的描述不一致。** 磁盘重开测试在关闭容器前检查文章正文，重开后没有重新查询 ArticleRecord；“invalid candidate cannot create cycle or article”测试只使用内存 CycleStore，根本没有 ArticleStore；“Repository retry”测试实际使用的是 FailingCycleStore，而不是 SwiftData Repository。
5. **规格字段仍缺失或无法填充。** `ArticleCandidate` 不包含 `bodyHash`、`wordCount`、`estimatedReadMinutes`、`topicTags`；Repository 写入时这些字段只能保留默认值。规格中的 UserPreferences 可选 `ageRange` 字段也未实现。
6. **首页的 blocked/failed 恢复体验不完整。** 文章 blocked 状态有提示文字但没有可执行的恢复操作；复习、连线和拼写阶段进入 blocked/failed 时既没有解释，也没有重试/恢复入口。当前 UI 测试没有验证这些状态或禁用按钮。
7. **整改报告中的 Git 历史与最新 CI 证据不准确。** 报告引用的整合 commit `ab70b5a` 无法从 GitHub 解析；PR #1 仍是 closed/unmerged；当前 main 最新 commit 是 `ee8eee...`、最新 Actions 是 run 40600352579，但整改报告、STATUS 和 CHANGELOG 仍主要引用较早的 run 40597791954/40598844627。

所以，本次结论不是“整改没有价值”，而是：**CI 绿色，但仍有领域层绕过路径、持久化失败风险、测试覆盖缺口和报告证据不一致，不能宣布彻底合格。**

## 2. 当前仓库、分支和 CI 的事实

### 2.1 代码与分支

- 当前 `main` HEAD：`ee8eee95526d91623ed40803a550b8dfeab55c07`
- 旧分支 `round1-daily-cycle` 仍指向：`c13906ae66515c29cb9a602da061caf810a62ade`
- [PR #1](https://github.com/whyhaoyu1022-glitch/LexiDawn/pull/1)：closed，`merged=false`，head 仍是旧分支。
- 当前 main 与旧分支的提交历史已分叉；树比较没有发现仅存在于旧分支的文件，但 main 上同名代码文件的内容已不同，并额外包含两份审查报告和 2026-10-28 开发日志。
- 用户已经明确表示旧分支删除不了可以保留，因此本报告不把“删除旧分支”列为阻断条件，也没有尝试删除它。

注意：代码文件的内容进入 main，不等于 PR #1 已被 GitHub 正式合并。后续开发应以 main 的代码为准，不能把旧分支 SHA 当作当前交付代码。

### 2.2 被审查代码基线的 CI 实际结果

本次审查的应用代码基线是 `ee8eee95526d91623ed40803a550b8dfeab55c07`。该代码基线对应的最新验证为 [Actions run 40600352579](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/40600352579)，结论为 **success**。本报告本身是 docs-only 变更；创建报告的 commit `24375d7b991f3660b5ec91531859620112537e85` 另外触发了 [run 40705493392](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/40705493392)。该报告提交的运行状态以 Actions 页面为准，不应与应用代码基线的测试结果混为一谈。

job 中以下步骤全部成功：

- 工具链与 iOS 26.5 兼容目标检查
- iOS 26.5 Simulator runtime 检查
- runner checkout 中临时调整 Deployment Target
- 未签名模拟器构建
- 在启动 simulator 前编译测试 target（`build-for-testing`）
- 创建并启动具体 iOS Simulator
- 单元测试
- UI 测试
- 上传测试结果包

日志可核实：

- XCTest：**25 tests，0 failures**
- XCUITest：**2 tests，0 failures**
- 两组测试均输出 `TEST SUCCEEDED`
- 最新运行的 xcresult artifact：ID `12777913559`，可从 [run 40600352579 的 Artifacts 区域](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/40600352579)查看。

CI 通过是真实结果；但测试覆盖不完整，所以不能把绿色 CI 等同于所有产品规则已验证。

### 2.3 CI 日志中仍需记录的警告

最新 job 日志包含：

- CoreData/SwiftData 持久化存储初始化时出现 `NSCocoaErrorDomain Code 512`、`Sandbox access to file-write-create denied` 和 Application Support 路径暂不存在的错误日志，随后日志报告 recovery attempt successful，测试继续通过。
- Xcode 输出 `Using the first of multiple matching destinations` 警告；测试最终确实运行并通过，但应继续保持具体 simulator ID 的验证。
- 上传 artifact 时出现 Node.js 20 deprecation / `punycode` deprecation 警告。

这些日志没有使当前 CI 失败，不能简单归因于应用的确定性缺陷；但也不应把日志描述为完全无错误。尤其 CoreData 512 应在可控的模拟器和真实应用启动环境中继续调查。

### 2.4 验证范围边界

CI 通过的是 Xcode runner 上的 iOS 26.5 兼容模拟器构建/测试。工程 Debug/Release 产品配置仍为 iOS 27.0。当前环境没有在真实 iPhone 上验证，也没有验证签名 IPA、VoiceOver、最大动态字体、深色模式或真实数据迁移。这些仍应标为未验证，而不是通过。

---

## 3. 阻断验收的问题

### R2-001 — P0：复习 deferred 仍然没有“系统确认队列为空”的硬性门禁

**结论：不通过，属于核心产品不变量缺陷。**

代码证据：

- [DailyTasks.swift — TaskStatus.isSatisfied(for:)](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L29-L38)
- [DailyTasks.swift — TaskStatus.transitioned(to:reason:)](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L41-L60)
- [DailyTasks.swift — DailyStudyCycle.update](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L246-L299)
- [测试 testDeferredStagesCanSatisfyCycleOnlyWithReasons](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawnTests/LexiDawnTests.swift#L124-L137)
- [测试 helper complete(_:with:at:)](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawnTests/LexiDawnTests.swift#L403-L408)

整改确实修复了文章任务的一个入口：`update(task:to:reason:at:)` 会拒绝 article → deferred。但复习任务、连线阶段和拼写阶段仍然有以下行为：

1. `TaskStatus.transitioned` 只要求 deferred 的 `reason` 是非空字符串，不验证原因的语义。
2. `DailyStudyCycle.update` 对 article 做了专门限制，却没有要求 review/matching/cloze 的 deferred 必须来自真实的空队列判断。
3. `isSatisfied(for:)` 对 review/matching/cloze 无条件将 deferred 视为满足条件。
4. 周期完成后，只要任意一个复习状态是 deferred，`completionReason` 就会被设置为 `completed-with-no-review-items`，即使调用者给出的理由根本不是“没有应复习词条”。
5. 测试 helper 使用 `reason: "test"` 也能将三个复习状态设为 deferred 并完成周期；现有测试证明的是“只要有字符串理由就可以跳过”，而不是“系统确认队列为空才可以跳过”。

这违反 [SPEC §2.2.1 任务状态枚举](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/SPEC.md#L204-L217)：deferred 必须是系统明确判定无需执行的结果；也违反 [SPEC §2.1 每日必做任务组成](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/SPEC.md#L176-L186)。

**必须整改：**

- 不要用任意字符串来代表合法 deferred 原因。采用类型化的原因/决策，例如只允许系统的“当前无到期词条”判定产生 `noDueItems`。
- 在复习队列尚未接入时，不允许调用者仅靠传入非空字符串就完成复习任务；宁可保留未完成/明确未接入，也不要伪造空队列。
- 周期完成原因应由经过验证的业务结果推导，而不是看到任意 deferred 状态就推断“没有复习项”。
- 为“真实空队列可以 deferred”“队列非空不能 deferred”“任意跳过理由被拒绝”“非法状态组合不能完成周期”分别新增回归测试。
- 测试 helper 不应通过 `"test"` 这样的任意理由模拟合法的产品完成流程。

### R2-002 — P1：领域初始化和持久化解码仍允许不可恢复的非法状态

**结论：不通过。**

代码证据：

- [DailyTasks.swift — DailyStudyCycle 初始化与状态属性](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L181-L250)
- [DailyTasks.swift — article deferred 更新限制](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L259-L299)
- [PersistenceModels.swift — DailyStudyCycleRecord.domain()](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawn/Data/PersistenceModels.swift#L140-L170)

当前更新入口禁止文章转为 deferred，这是正确的。但不变量并没有在模型所有入口上成立：

- `DailyStudyCycle.init(... articleTaskStatus:)` 可以直接传入 `.deferred`，因为初始化器不抛错，也没有统一的状态组合验证。
- `DailyStudyCycleRecord.domain()` 只验证 raw value 是否能解码成 `TaskStatus`，没有验证文章不能 deferred，也没有验证 deferred 是否有合法原因。
- article deferred 在 `isComplete` 中不算满足条件，但 `TaskStatus.deferred` 是终态，无法再迁移到 ready、blocked 或 completed。因而一条历史/非法记录一旦被加载，就可能永远成为未完成且不可恢复的周期。
- 同样，review/matching/cloze 可以在没有对应 reason 的情况下通过初始化器或持久化解码进入 deferred；`isComplete` 不检查原因是否存在。

这不仅是测试遗漏，而是“合法状态迁移”只保护了一个更新函数，没有保护模型构造和数据恢复入口。此外，初始化器也允许构造“所有任务状态看起来已满足、但 completedAtUTC/completionReason 仍为空”或“周期已完成但 isCurrent 仍为 true”的组合；`StudyCycleRepository.save(_:)` 不会在保存前统一拒绝/规范化这些矛盾状态。持久化解码同样没有根据任务状态校验 completedAtUTC、completionReason 与 isCurrent 的一致性。

**必须整改：**

- 为领域模型增加统一的合法状态组合校验；不能只依赖 UI 或单个 update 函数。
- 从 SwiftData 解码时验证 deferred 原因和任务类型。对于旧数据中的非法状态，应有明确迁移/修复策略，不能静默把它当作有效状态，也不能让周期永久卡死。
- 增加直接初始化非法状态和从持久化记录恢复非法状态的测试。
- 证明修复逻辑不会丢弃用户的未完成周期或覆盖原文章指派。

---

## 4. P1：数据一致性与 Repository 失败路径仍有缺口

### R2-003 — P1：原子创建只保护部分路径，普通保存失败缺少 rollback

**结论：部分整改，未完全满足 R1-004。**

代码证据：

- [DailyTasks.swift — ensureCurrentCycle 的保存分支](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L359-L404)
- [Repositories.swift — StudyCycleRepository.save(_:)](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawn/Data/Repositories.swift#L27-L44)
- [Repositories.swift — save(cycle:candidate:fetchedAt:)](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawn/Data/Repositories.swift#L49-L90)
- [Repositories.swift — ArticleRepository.save(candidate:fetchedAt:)](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawn/Data/Repositories.swift#L92-L109)
- [Repositories.swift — PreferencesRepository.save(_:)](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawn/Data/Repositories.swift#L159-L173)

积极的部分：

- 生产的 `StudyCycleRepository` 实现了 `AtomicCycleCreationStore`。
- `save(cycle:candidate:fetchedAt:)` 将文章和周期放在同一个 ModelContext 保存边界内，并在 catch 中调用 `context.rollback()`。
- 代码会拒绝重复 assignedLocalDate 和重复 canonicalURL。

仍未解决的风险：

1. `DailyCycleService.ensureCurrentCycle` 仍保留 fallback：当 cycleStore 不实现 `AtomicCycleCreationStore` 时，先调用 `articleStore.save`，再调用 `cycleStore.save`。如果第一步成功、第二步失败，就可能留下孤立文章记录。这是服务本身仍允许的非原子路径。
2. 普通 `StudyCycleRepository.save(_:)` 修改已有托管对象、清除其他记录的 `isCurrent` 后调用 `context.save()`，没有 catch/rollback。如果保存失败，当前 ModelContext 中的对象仍可能保留未提交的更改，后续其他保存可能意外提交这些修改。
3. `ArticleRepository.save` 与 `PreferencesRepository.save` 也没有统一失败回滚策略。
4. 同日唯一性和 canonicalURL 唯一性主要靠查询后再保存，没有数据库级 canonicalURL 唯一约束；跨 ModelContext/并发写入没有验证。报告已承认不保证跨进程并发，但没有覆盖同一应用不同 context 的竞争情况。
5. 当前生产创建路径虽然使用原子 store，但没有测试真实 SwiftData 保存失败时 rollback 后数据库和上下文分别是什么状态。

**必须整改：**

- 对非原子 store + articleStore 的组合，禁止静默走两次独立保存；应要求 AtomicCycleCreationStore 或提供明确安全的事务替代。
- 普通 Repository 写操作保存失败时，应明确 rollback/恢复托管对象状态，避免错误状态留在共享 context。
- 增加故障注入测试，验证文章/周期创建失败后没有孤立记录、重复日期、重复文章指派或脏 context 副作用。
- 增加 Repository 层重复 assignedLocalDate 测试，而不仅是 Service 层内存 Store 的顺序幂等测试。
- 对并发限制继续如实记录；不要声称跨 context/跨进程已被唯一约束保护。

### R2-004 — P1：磁盘重开测试存在，但验收断言没有覆盖报告声称的全部数据

代码证据：

- [testDiskContainerReopenRestoresCycleArticleAndPreferences](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawnTests/LexiDawnTests.swift#L254-L285)

当前测试确实使用临时磁盘 `ModelConfiguration(url:)`，在两个作用域中创建容器，且测试已在 CI 运行通过。这是正确的进步。

但在第二次创建容器后，测试只断言：

- 周期 articleID
- assignedLocalDate
- 偏好 displayName

ArticleRecord 的 bodyText 是在第一个容器关闭前查询的；**第二个容器重新打开后没有重新查询 ArticleRecord**。因此当前测试不能证明文章记录及正文在重开后仍存在。

它也没有验证：

- 周期各任务状态
- assignedTimeZoneID
- createdAtUTC / updatedAtUTC / completedAtUTC
- carryOverCount / lastCarryOverLocalDate
- isCurrent / completionReason / 各任务 reason
- 偏好的多个关键字段
- 周期 articleID 指向的 ArticleRecord 是否确实存在且字段一致

**必须整改：** 重开容器后重新创建 ArticleRepository 并验证文章本身、正文、许可字段和关联；同时核验周期状态、时区、时间戳和关键偏好。若不准备逐字段测试，报告必须准确缩小声明范围，不能写成所有周期/文章数据都已恢复验证。

### R2-005 — P1：若干测试名称和追踪矩阵比实际测试证明的内容更强

代码证据：

- [testInvalidCandidateCannotCreateCycleOrArticle](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawnTests/LexiDawnTests.swift#L300-L309)
- [testRetryingFailedRepositoryWriteCanSucceedWithoutDuplicateCycle](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawnTests/LexiDawnTests.swift#L332-L341)
- [testTodayViewModelRetryRepeatsFailedWrite](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawnTests/LexiDawnTests.swift#L343-L362)
- [FailingCycleStore](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawnTests/LexiDawnTests.swift#L423-L439)
- [需求追踪矩阵中的 R1-004 至 R1-006](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/docs/requirements-traceability.md)

具体问题：

1. `testInvalidCandidateCannotCreateCycleOrArticle` 使用的是 `InMemoryCycleStore`，没有传入 ArticleStore，也没有创建 SwiftData ArticleRecord。它只验证周期数组为空，不能证明“文章记录没有被创建”。
2. 两个 retry 测试使用 `FailingCycleStore`，该 fake store 在第一次保存时直接抛错。它们验证 ViewModel/Service 会重试写操作，但**不是实际 SwiftData Repository 的持久化失败测试**，不能证明 ModelContext rollback、磁盘状态和重试后的数据一致性。
3. `testRepositoryMaintainsSingleCurrentCycle` 只验证连续保存两个不同日期的周期后，第二个成为唯一 current；它没有覆盖旧周期完成、下一日新周期创建、历史多 current 修复等情形。
4. `testSameDayProvisioningIsIdempotent` 只使用内存 Store，不能替代 SwiftData Repository 层重复日期约束测试。
5. `testDateRollbackDoesNotIncreaseCarryOverCount` 覆盖一个 UTC 日期回拨场景，但没有验证跨时区切换、夏令时边界或跳过多个日期后重新打开的计数。

追踪矩阵不应把 fake Store 的故障测试描述成真实 Repository 持久化失败已验证。请把测试实际证明的范围和未覆盖范围准确写明。

---

## 5. P1：规格字段和文章许可门禁仍不完整

### R2-006 — P1：ArticleRecord 有字段，但候选数据契约无法填充全部规格字段；UserPreferences 缺 ageRange

规格依据：

- [SPEC §19.1 Article](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/SPEC.md#L1886-L1909)
- [SPEC §19.9 UserPreferences](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/SPEC.md#L2088-L2120)

代码证据：

- [ArticleCandidate 字段定义](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L94-L137)
- [ArticleRecord 字段](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawn/Data/PersistenceModels.swift#L4-L24)
- [ArticleRepository.makeArticleRecord](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawn/Data/Repositories.swift#L115-L134)
- [UserPreferencesRecord](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawn/Data/PersistenceModels.swift#L175-L278)

发现：

1. SPEC §19.1 定义了 `bodyHash`、`wordCount`、`estimatedReadMinutes`、`topicTags`。ArticleRecord 虽然有这些属性，但 ArticleCandidate 没有相应字段，`makeArticleRecord` 也没有传入或计算它们，所以它们始终是默认值（bodyHash nil、wordCount 0、estimatedReadMinutes 0、topicTags 空数组）。
2. SPEC §19.9 要求 UserPreferences 包含可选 `ageRange`。当前 `UserPreferencesRecord` 没有这个字段，偏好数据模型并未完整覆盖规格。
3. `contentStatus` 在持久化模型中仍是任意 String；领域候选使用枚举，但读取已有 ArticleRecord 时没有统一验证其 raw value。
4. 候选门禁验证 ID、标题、来源、HTTP(S) URL、`licenseVerified` 和正文可用性，这比第一轮完善；但仅检查一个布尔值并不能表达“许可允许缓存全文”的具体权利。候选中没有独立的全文缓存/展示权限信息。
5. `imageURL` 不是必填，但若提供则没有验证它是有效 HTTP(S) URL，也没有根据来源许可验证署名要求。
6. `ArticleRepository.save(candidate:fetchedAt:)` 本身只检查 canonicalURL 重复，不执行完整候选验证。当前生产候选 provider 为空，暂未构成真实文章误入生产的证据；但如果后续将该方法直接用于预取/保存，存在绕过服务层门禁的接口风险。

**必须整改：**

- 让候选契约能够提供或可靠计算所有要求的文章元数据；不要让规格字段永远保留空默认值。
- 增加 `ageRange`（可选）或在正式决策记录中解释为什么规格要变更。
- 将“许可已核验”和“允许缓存全文/展示图片/署名要求”区分清楚；没有全文缓存权限的来源不得保存全文。
- 让所有文章持久化入口都无法绕过核心验证，或把 Repository API 限定为只接受已验证候选。
- 增加缺失字段、无效图片 URL、缺署名、许可未核验、正文不可用和内容状态非法的独立测试。

### R2-007 — P1：未接入任务的 blocked/failed 状态没有完整的 UI 说明或恢复路径

代码证据：

- [TodayViewModel.load/retry/start](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawn/Features/Today/TodayFeature.swift#L39-L109)
- [TodayView.actionButtons](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawn/Features/Today/TodayFeature.swift#L212-L243)
- [TaskStatusRow](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawn/Features/Today/TodayFeature.swift#L278-L291)
- [当前 UI 测试文件](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawnUITests/LexiDawnUITests.swift)

积极的部分：未接入的按钮已禁用，`start(task:)` 是 no-op，不再伪造 `inProgress`。这是 R1-002 的有效修复。

未解决的部分：

1. `recoverUnavailableInProgressTasks` 会把遗留的 inProgress 转成 blocked。
2. 文章处于 blocked/inProgress 时会显示“阅读器尚未接入”的文字，但没有可执行的重试/恢复操作；文字称“可恢复”，当前 UI 却没有恢复按钮。
3. review、matching、cloze 的按钮只在 status == ready 时显示。它们如果被恢复为 blocked/failed，页面只显示状态文字，既没有原因，也没有恢复/重试入口。
4. `TaskStatusRow` 只展示状态名，不展示各任务的 reason。
5. 当前 XCUITest 仍然只有两个测试：五个 tab 的导航，以及无候选首页。没有任何 UI 测试验证未接入按钮是否 disabled、blocked 状态的说明或恢复行为。
6. `docs/test-plan.md` 却声称 UI 测试覆盖“禁用未接入任务入口”；当前 XCUITest 源码没有相应断言。

**必须整改：**

- 对所有 blocked/failed 状态提供明确原因和真实可用的下一步操作；如果因功能尚未接入而无法恢复，应如实写“尚不能恢复/等待功能接入”，不要宣称当前可恢复。
- 增加 UI 自动化测试，实际检查四个未接入入口的 disabled 状态、状态不变、blocked/failed 的展示和可恢复行为。
- 如果旧数据中的 inProgress 被转成 blocked，应定义一个安全的修复/恢复策略，并测试不会丢失原始周期、日期和文章指派。

---

## 6. P1：产品完成规则和状态恢复仍有待加强

### R2-008 — P1：文章 completed 仍没有领域层证据约束

规格依据：[SPEC §2.5 阅读任务完成定义](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/SPEC.md#L261-L270)。

当前 `TaskStatus.canTransition` 允许 ready → completed，`DailyCycleService.updateTask` 也接受任意内部调用者传入 article + completed。这个方法没有阅读进度、达到 90% 的证据或用户明确确认完成的参数。

当前 UI 的阅读按钮禁用，生产阅读器尚未接入，因此这不是一个当前用户可直接点击绕过阅读的 UI 路径。但领域服务仍允许未来调用者直接把文章标记完成；如果后续阅读器只是调用这个通用 update 方法，SPEC §2.5 就没有被真正强制执行。

**要求：** 在阅读器接入前，明确文章完成 API 的契约；后续完成操作必须由验证过的阅读进度和用户确认产生。不能把通用的状态更新 API 当成阅读完成证明。

### R2-009 — P2：carryOverCount 仍依赖应用被打开的日期，不等于完整跨日次数

代码证据：[DailyTasks.swift — markCarryOverIfNeeded](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawn/Domain/DailyTasks/DailyTasks.swift#L301-L326)。

当前实现只在“当前本地日期晚于分配日期，且与上一次记录的 carry-over 日期不同”时加 1。如果任务分配在 10 月 26 日，用户直到 10 月 29 日才重新打开应用，当前逻辑只加 1，而不是根据中间经过的学习日期计算跨日次数。

SPEC 把 `carryOverCount` 定义为跨日次数，但没有进一步明确它是“应用打开时观察到的跨日事件数”还是“经过的学习日期数”。这不是当前 UI 的阻断缺陷，但应明确业务语义，并补上“跳过多日后再打开”的测试，避免统计值含义不稳定。

---

## 7. P1：AI 自己的整改报告和追踪文档仍有不准确之处

### R2-010 — P1：整改报告引用的整合 SHA 无法在 GitHub 上解析，历史描述不够准确

整改报告开头和“整合范围与分支状态”声称：

- 起始/整合 commit：`ab70b5a`
- 在 main 上执行非快进整合
- PR #1 关闭且未合并

我尝试从 GitHub 获取 `ab70b5a`，GitHub API 返回 422：`No commit found for SHA: ab70b5a`。因此，不能将这个 SHA 当作可由仓库验证的整合证据。

公开 main 历史中，审查报告提交后可见的是常规提交链（包括 [7e4c7a4](https://github.com/whyhaoyu1022-glitch/LexiDawn/commit/7e4c7a4ea79a93a34862abd9241ed2122a9bbd2e)、[c291c22](https://github.com/whyhaoyu1022-glitch/LexiDawn/commit/c291c225273774df59a28e3bd9c784550253682c) 等），并没有可核验的 `ab70b5a` 公开提交。PR #1 当前确实 closed 且 merged=false。文件树比较显示 main 已包含相应源文件并且内容经过更新，但不能据此声称 PR 已合并或引用一个不存在的公开 SHA。

这不代表当前 main 缺少所有源代码；它代表的是**整合过程的审计证据不准确**。

**必须整改：** 将报告中的整合 SHA 改成真实存在、可打开的 commit；明确说明代码内容进入 main 的实际提交方式，不要声称 GitHub 已正式合并 PR #1。

### R2-011 — P1：文档没有更新到最新的 main Actions 结果

当前真实最新状态是：

- main HEAD：`ee8eee95526d91623ed40803a550b8dfeab55c07`
- 最新 Actions：run [40600352579](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/40600352579)，success
- 当前 run 的 XCTest 25/0 failures、XCUITest 2/0 failures
- 最新 xcresult artifact ID：12777913559

但 AI 的整改报告、STATUS、CHANGELOG 和 2026-10-28 开发记录主要引用 run 40597791954 与 40598844627，没有把 40600352579 作为最新运行记录。它们的代码/文档提交之后又发生了新的 main push 和 CI，所以“最新 CI”表述已经过期。

另外，`docs/test-plan.md` 说 UI 测试覆盖 disabled 未接入入口，但 XCUITest 实际没有这样的测试；需求追踪矩阵把 fake Store 的测试描述成 Repository 持久化失败验证，也过度陈述了证据。

**必须整改：**

- 同步记录真实最新 main SHA、Actions run 和 artifact。
- 将未验证/未覆盖的 UI 状态写成未验证，而不是“已覆盖”。
- 逐条核对需求追踪矩阵中测试名称、测试对象和实际断言，确保描述与源码一致。
- 不要因为 CI success 就把没有测试的行为标记为已验证。

---

## 8. R1-001 至 R1-014 逐项复验矩阵

| 原问题 | 本次复验 | 结论 |
|---|---|---|
| R1-001 文章 deferred 可完成周期 | 文章更新入口已拒绝 deferred；但复习 deferred 仍只验证非空字符串，无法证明队列为空 | **部分修复，核心不变量仍不通过** |
| R1-002 开始任务后永久 inProgress | 未接入按钮禁用，start no-op；遗留 inProgress 会转 blocked。但 blocked/failed UI 解释和恢复不完整，UI 没有验证 disabled 入口 | **部分修复** |
| R1-003 唯一 current / completionReason | 有 completionReason 和 Repository current 清理逻辑；测试仅覆盖连续保存两个不同日期周期，没有覆盖非法历史状态或恢复路径 | **部分修复** |
| R1-004 原子创建、幂等、回滚 | 生产原子创建路径有同一 save + rollback；仍有非原子 fallback，普通保存失败无统一 rollback，缺真实失败注入和重复日期 Repository 测试 | **部分修复** |
| R1-005 保存失败重试 | ViewModel 会重试 pending operation；测试用 FailingCycleStore，不是实际 SwiftData Repository 写失败 | **逻辑有进步，持久化失败路径未完全验收** |
| R1-006 磁盘数据库重开 | 临时磁盘容器确实重开；重开后没有检查 ArticleRecord/bodyText，只检查周期 ID/date 与 displayName | **部分验证，不足以支持报告的完整声明** |
| R1-007 文章模型与许可门禁 | 有展示标题、难度、图片、许可和正文门禁；ArticleCandidate 不能提供 bodyHash/wordCount/readMinutes/topicTags，许可全文缓存权利不够明确；UserPreferences 缺 ageRange | **未完全满足规格** |
| R1-008 回归测试覆盖 | 25 个 XCTest 通过，但缺跨日部分完成、下一日新周期、合法 deferred 原因、真实 Repo 失败、磁盘文章重开和 UI disabled 状态等断言 | **未补齐全部要求** |
| R1-009 CI 与配置 | workflow 保留 iOS 27.0 产品配置、26.5 兼容目标和 xcresult 上传；最新 main CI 通过 | **主要通过，仍有日志警告需跟踪** |
| R1-010 文档和追踪矩阵 | 已有整改报告和更新的文档，但引用不存在的 `ab70b5a`，最新 CI 仍停留在旧 run，测试覆盖描述不准确 | **不通过** |
| R1-011 时区回拨/carry-over | 日期回拨测试通过；多日未打开、夏令时/时区策略场景未覆盖，carryOverCount 语义不明确 | **部分修复** |
| R1-012 URL/候选校验与警告 | 有基础 URL 规范化、重复 URL 检查和候选门禁；候选字段不完整，许可/图片元数据验证不充分 | **部分修复** |
| R1-013 ModelContainer 初始化失败 | 有存储不可用错误页，不 fatalError、不清空数据；无重试按钮，失败注入路径未测试 | **部分修复** |
| R1-014 提交追踪和未验证范围 | 未声称真实设备通过，旧分支保留也符合用户允许的处理方式；但整合 SHA 与 CI 文档记录不准确 | **部分修复** |
| R2-012 schema 迁移 | 有 schemaVersion 字段和可选新增字段，但没有旧 schema 数据库升级测试或实际迁移流程 | **未验证** |

---

### R2-012 — P1：模型版本字段存在，但没有验证从旧 schema 升级的迁移路径

规格依据：[SPEC §19.10 数据迁移与一致性](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/SPEC.md#L2122-L2133)。

当前 `UserPreferencesRecord` 有 `schemaVersion` 字段，但仓库中没有读取该版本并执行迁移的逻辑，也没有 `VersionedSchema` / `SchemaMigrationPlan` 或使用旧版本数据库文件的迁移回归测试。整改报告称新增字段可进行轻量迁移，但当前磁盘重开测试是“用当前模型创建数据库，再用当前模型打开”，并没有用上一版本模型建立旧数据库再升级。

本轮新增到 ArticleRecord 的展示标题、难度、图片 URL/署名等字段是可选字段，SwiftData 可能支持相应轻量迁移；但**没有真实旧 schema 升级测试，就不能把迁移安全性标记为已验证**。如果用户曾经运行过旧分支版本，应用升级时仍需证明旧周期和文章记录不会丢失或导致 ModelContainer 初始化失败。

**必须整改：**

- 明确当前版本支持的旧 schema 范围及迁移策略。
- 至少构造一个由上一版 schema 创建的临时磁盘数据库，再用当前 schema 打开并验证文章、周期、偏好及任务状态。
- 如果当前尚无可支持的历史 schema，文档应明确记录这一产品阶段假设，并说明后续每次模型变更必须增加迁移测试；不能把“当前版本自己创建后能重开”当作迁移测试。

---

## 9. 必须完成的整改清单

### P0：重新验收前必须先修复

- [ ] **禁止任意理由 deferred。** 复习/连线/拼写阶段只能在系统确实确认没有应复习项目时 deferred；在复习队列尚未实现时不能通过任意字符串完成周期。
- [ ] **统一验证所有领域状态入口。** 构造器、Repository 解码和状态更新必须共同保证文章不能 deferred，deferred 必须具备合法原因，非法旧状态必须可恢复。
- [ ] 为上述两个核心问题新增真正证明业务不变量的回归测试，不能只测试“传了字符串就可以完成”。

### P1：必须补齐后才能标记完整整改

- [ ] 修复非原子 fallback 和普通 Repository 保存失败后的 rollback/上下文恢复策略。
- [ ] 增加真实 SwiftData Repository 的重复日期、保存失败、rollback、重试后数据一致性测试。
- [ ] 完善磁盘重开测试：重开后验证 ArticleRecord 正文、文章关联、周期状态/时区/时间戳和关键偏好。
- [ ] 补齐 ArticleCandidate 的 bodyHash、wordCount、estimatedReadMinutes、topicTags 数据契约或可靠计算逻辑。
- [ ] 补齐 UserPreferences 的 ageRange（可选）字段。
- [ ] 明确全文缓存许可和图片 URL/署名验证；确保所有文章写入路径不能绕过门禁。
- [ ] 给 review/matching/cloze 的 blocked/failed 状态提供解释和可执行的下一步；不能只让状态 badge 显示“被阻塞”。
- [ ] 增加真实 XCUITest，验证未接入按钮 disabled、点击不改状态，以及 blocked/failed 的 UI 行为。
- [ ] 补上“文章完成但复习未完成跨日保留”“复习完成但文章未完成跨日保留”“连线完成但拼写未完成”“旧周期完成后下一本地日期建立新周期”等回归测试。
- [ ] 修正整改报告中的 `ab70b5a` 引用，改为实际存在的提交 SHA 和可核验的整合描述。
- [ ] 更新 STATUS、CHANGELOG、测试计划、需求追踪矩阵和整改报告中的最新 CI run/SHA/artifact，避免把 fake Store 测试说成真实 Repository 测试。

### P2：需要明确记录并补充验证

- [ ] 明确 carryOverCount 是“打开应用时观察到的跨日次数”还是“经过的本地学习日期数”，并增加跳过多日的测试。
- [ ] 为存储初始化失败页增加合适的重试/恢复动作，或明确说明只能通过重启应用恢复。
- [ ] 调查 CI 日志中的 CoreData 512/Sandbox 错误；当前 recovery successful 不能替代对真实存储路径的确认。
- [ ] 在 macOS/Xcode 环境完成模型升级/迁移、真实设备、VoiceOver、动态字体、深色模式和 iOS 27 产品目标验证。

---

## 10. 下一次验收必须看到的证据

下次复验时，不接受只提交一份“所有问题已修复”的报告。至少必须看到：

1. 复习 deferred 的合法来源由真实空队列判断决定，而不是由任意字符串决定。
2. 非法状态无法通过初始化、持久化解码或 Repository 写入绕过领域规则。
3. 真实 SwiftData 保存失败后数据库和共享 ModelContext 的状态可预测、可恢复。
4. 磁盘重开后确实能读回文章正文、周期状态、时区、时间戳和偏好。
5. UI 测试实际验证禁用入口与 blocked/failed 状态，而不是只测试导航和空状态。
6. 每个整改项的测试名称、断言内容、CI 运行和报告描述相互对应。
7. 最新 main commit 对应的 Actions 已结束并通过；同时如实列出 CoreData/Xcode/Action 的警告。
8. 文档引用的 SHA 都能从 GitHub 打开，PR 状态和分支状态与 GitHub 实际值一致。

---

## 11. 最终结论

本次整改已经修复了一部分第一轮缺陷，且 main 上最新 CI 的实际结果是成功：25 个 XCTest 与 2 个 XCUITest 全部通过。CI 配置和测试结果 artifact 也比第一轮更完整。

但 **第二次独立验收仍然不通过**。最主要的阻断点不是 CI，而是领域层依然允许通过任意 deferred 理由跳过复习并完成周期；非法状态也可以通过构造器/持久化解码进入模型。其次，原子性、磁盘恢复测试、Article/UserPreferences 规格字段、blocked UI 测试和报告证据都有未闭环之处。

本报告没有修改应用代码。下一步应将以上整改项交回开发 AI，继续在 main 上修复、补测、运行 CI，并在所有阻断项有代码和测试证据后重新验收。旧分支可以继续保留；本次不把分支删除作为条件，也不建议在核心业务规则尚未完全闭环时提前开始新的功能轮次。

## 12. 证据索引

- [当前 main HEAD](https://github.com/whyhaoyu1022-glitch/LexiDawn/commit/ee8eee95526d91623ed40803a550b8dfeab55c07)
- [最新 main CI run 40600352579](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/40600352579)
- [AI 整改报告](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/docs/reviews/round-1-remediation-report-2026-10-27.md)
- [上一份独立验收报告](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/docs/reviews/round-1-acceptance-review-2026-10-27.md)
- [PR #1（closed，unmerged）](https://github.com/whyhaoyu1022-glitch/LexiDawn/pull/1)
- [DailyTasks.swift](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawn/Domain/DailyTasks/DailyTasks.swift)
- [PersistenceModels.swift](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawn/Data/PersistenceModels.swift)
- [Repositories.swift](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawn/Data/Repositories.swift)
- [TodayFeature.swift](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawn/Features/Today/TodayFeature.swift)
- [单元测试](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawnTests/LexiDawnTests.swift)
- [UI 测试](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/LexiDawnUITests/LexiDawnUITests.swift)
- [CI workflow](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/.github/workflows/ios-ci.yml)
- [SPEC.md](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/SPEC.md)
- [需求追踪矩阵](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/docs/requirements-traceability.md)
- [测试计划](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/docs/test-plan.md)
- [STATUS.md](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/main/STATUS.md)
