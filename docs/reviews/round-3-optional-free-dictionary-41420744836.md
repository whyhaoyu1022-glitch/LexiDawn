# Round 3 · 可选Free Dictionary可用性与跨日测试整改

负责人2026-11-02明确授权：Free Dictionary不稳定时显示当前不可用，继续使用可用维基来源，不再执着让该外部服务必须可用。本指示优先于此前要求Free真实联网必过的约束；仅作用于该可选外部服务，不允许跳过解析错误、核心业务失败或Wiktionary强制真实验证。词典来源是Wiktionary；Wikipedia仍只用于文章链路。

## 本次真实失败

被核查main `954b30b6ee38059c16560eb68c661329dd439d35`，[运行41420744836](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41420744836)。Debug/Release与测试目标编译通过；184 XCTest中2失败（不是只有1个）：Free Dictionary真实book三次404，另有词汇推荐固定日期与系统日期不一致导致意外门禁错误。Wiktionary真实book非空noun测试通过，10源29篇全文导入通过。UI/截图合并跳过，没有执行证据。

## 真实修改

1. 保留Free Provider及其限次/取消/缓存语义。聚合结果新增本次emptyProviders：不把404无词误说成成功定义，也不把未知词必然说成全站宕机。浮窗/详情显示“Free Dictionary API 当前无可用结果（暂不可用或未收录此词）。其他可用来源仍可使用。”明确失败的Provider同样显示来源名称。
2. Free返回空或失败均保留实际Wiktionary/本地义项和可用旧缓存；缓存回退标记保留。两源全无释义时仍显示无可靠结果，不造中文答案、不伪造复习题。
3. 原Free真实测试方法保留：只有已知transport/rateLimited/notFound或无释义外部状态才XCTSkip，原因明确记为可选服务不可用，不能计作真实查询成功。只要返回非空数据，原非空noun断言仍运行；解码/解析错误等不在skip范围。Wiktionary真实book和其他全部必要关卡保持失败即红，没有全局continue-on-error。
4. 增加确定性真实Repository聚合测试：Free空/失败两种状态都只保留Wiktionary明确fixture释义及真实来源，并无编造中文。新增UI free-unavailable fixture，断言只有Wiktionary来源与明确提示，截图R3-D07；原6种Provider状态及原截图要求不改，共138项。
5. 修复另一独立失败：词汇推荐门禁工厂允许注入clock，默认仍每次读取真实Date。测试统一使用固定时钟，保留原锁定/不自动加词/手动加入断言，并增加推进一天后重新锁定断言。生产跨日锁定没有被移除或伪造完成状态。

SPEC §30原文：“**锁定不可绕过**：探索与词汇推荐的业务层必须检查必做周期状态。”及“**真实失败必须可见**：网络、数据库、签名或 AI 失败不能被伪装成成功。”用户本轮指示调整的是可选外部服务验收策略；Repository、学习数据、答案可靠性及其他业务要求不减少。

## 验证与边界

本地Linux无Xcode。已做源码差异、Python/YAML/Shell静态验证、49主UI完整分组核对和原93/20文件保留核对。源码185 XCTest/49 UI；新测试/138状态截图尚待CI。Free可用性skip必须在报告中单独列明，不能把185源码或跳过数当作通过数。真实Wiktionary有先前运行通过证据，新代码完整CI仍需重跑；若Wiktionary失效，仍应失败并定位。

四个主UI组存在runner排队与十几分钟差异，按实际状态记录，不因慢就声称失败；单纯等待时按负责人持续授权结束对话。导出真实保存与完整最终截图包仍未统一验收。
