# 测试计划

每次记录运行的代码 SHA、测试范围、工具链、设备和结果。按[需求追踪](requirements-traceability.md)查标准，用 [交付报告](reviews/round-4-final-delivery.md)查实际结果。

## 验证层级

| 层级 | 执行与证据 |
|---|---|
| 文档与仓库完整性 | 检查文档链接，核对数据清单、编译与脚本依赖路径，用 Git diff 证明修改范围。文档维护提交可用 `[skip ci]`。 |
| 宿主 MDX | `python3 scripts/test-bundled-dictionary.py`。复原真实分包及哈希，验证缺包、缺块及不一致边界，并扫描真实索引与记录。 |
| XCTest | 学习周期、SwiftData 磁盘升级和事务失败、真实 MDX、文章网络、词义资格、组题与 FSRS。真实资源测试、确定性故障注入和原站请求分别报告。 |
| XCUITest | iPhone 17 Pro 四组全量及独立生产首启，iPhone SE 第三代与 Pro Max 专项。覆盖正常、错误、持久化、旋转/动态字体、导出及复习闭环，保留原始 PNG 与 xcresult。 |
| Release / IPA | Release 兼容构建检查旧词典网络端点与调试场景排除。实际 IPA 检查 MDX、架构、Info.plist、图标、无签名以及包完整性。 |

## CI 范围

- 在 macOS runner 按当前 workflow 检查 Xcode 与 Simulator 版本。Debug 生成一次测试产物，原生分组复用同一产物并校验工具链。
- 修复回归时先重跑实际失败且受修改影响的方法。用 `python3 scripts/ci-test-plan.py verify` 确认全量分组无遗漏。专项由 `[round4-fix-ui]` 选用当前脚本中的明确选择器。用例范围随实际失败调整。
- 回归全部通过后，用最终代码做 `[round4-final]` 全量验收。一轮运行涵盖单元、磁盘、真实网络、原生 UI、截图覆盖与未签名 IPA。文档或证据的整理复用已验证构建。
- 截图需保存原始 PNG、单图哈希、方法结果、实测系统/设备、主题、字号和数据来源。一个方法即使通过也可展示刻意触发的失败界面。截图相关编号与独立验收结论分开记。

## 当前已验证基线

构建源码 `309bbfd` 已通过 254 项 XCTest 和 77 次 XCUITest，包含主设备 67 次、SE 第三代复跑 7 次及 Pro Max 复跑 3 次。原文导入、跨正文版本保护、复习延期、冻结数据、拼写优先级和截图 `reader-11` 以[当前交付记录](reviews/round-4-final-delivery.md)为准。具体执行数与设备号查对应 SHA 的原生结果。

历史专项、选择器和实际运行见[交付与审查](reviews/README.md)。`[round4-final]` 执行全部方法，覆盖专项的跳过条件。Simulator 启动有两次上限和诊断，启动失败不计入通过。

## 真机验收

按[iPhone 真机测试清单](device-testing.md)执行安装、升级和用户路径。涉及长文性能时记录滚动和点词实测，必要时在设备上用 Instruments 记录。报告注明机型、系统、签名方式及构建号。自动化兼容验收和真机结果分别登记在[当前状态](../STATUS.md)。

真实冷启动用正常生产发现服务和独立的刷新偏好 suite；两小时策略仍保留。多来源阅读遇到真实学习日期变化，必须通过 UI 完成新周期再继续，不能绕过门禁或预置完成数据。
