# CURRENT · Round 3 测试结果与复核方法

## 2026-11-05 · 首次未签名真机IPA已导出

main构建代码 `39c5f7056644972ca0030a1cb041400a08d52c3c`，[专用打包42027995248](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/42027995248) 成功，原全量iOS CI明确skipped。本次只构建iphoneos/arm64 Release，Xcode26.6(17F113)/SDK26.5，最低iOS26.0，显示名LexiDawn，版本0.1.0(1)。实际IPA为6967717字节，SHA256 `2f8b2757a5aed10cee4cfc86f5055e4c4d3cbd880849e6391c1b8b16bf94e8c2`。AppIcon资源编译、完整1024不透明PNG、实际Info.plist、iOS Mach-O、无签名/无profile及ZIP CRC均通过；下载后再校验同一字节/权限。signed=false、installedOnDevice=false、testsRerun=false。未提供或索取Apple凭据；由负责人用AltServer本机重签安装。

SPEC §17.2原文“不使用透明背景。”及“在 Xcode Asset Catalog 中按目标 SDK 要求配置 AppIcon”；§22.7“不能在未签名或签名无效时上传一个被标记为可安装的产物。”本次依赖官方Xcode真机SDK，验收为真实IPA结构/签名状态/元数据/图标与SHA；用户自行签名安装，不能把构建当真机通过。安装步骤见[签名说明](signing.md)。

## 2026-11-02 已有全量与截图交付证据（历史范围）

全量 CI [41436291391](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41436291391) 已完成且成功，测试代码为 `b13d6b4e21e425472d059770319d88cd7c50a15e`。Debug/Release、186 XCTest（0失败）、49主 XCUITest（0失败）、SE7/大屏3（均0失败）、导出专项及截图合并全部通过；327张编号截图覆盖138项要求，缺失0项。当前交付自动化证据与完整截图包，最终视觉验收由负责人逐图确认；真机/iOS27/完整VoiceOver听读及Instruments未实测。本次仅文档与证据收尾，不修改应用、测试或CI代码。

| 验证 | 本次实际结果 |
|---|---|
| Debug build-for-testing / Release | 成功；Release排除故障/截图fixture标记 |
| 完整XCTest | 186执行，0失败；其中原93保留；Free与Wiktionary真实接口本次均成功，无XCTest跳过 |
| 主UI full-1 / full-2 / full-3 / full-4 | 11/12/13/13执行，均0失败，共49个不同方法 |
| iPhone SE / iPhone Pro Max | 7/3执行，均0失败；属于额外设备复跑，不增加不同方法数 |
| 导出专项 | 生命周期单元1/0、原生导出UI1/0；也在完整套件中再次执行，不重复计入186/49 |
| 截图合并 | 327张编号截图；138项要求无缺失；10源完整逐源证据；无缺失设备证据 |

## 测试层与证据边界

- 保留原93 XCTest和20 XCUITest，不删除或弱化断言；当前不同方法186/49。导出专项及设备复跑不重复计数。
- 确定性单元包含RSS/Atom/API、HTML/JSON-LD/正文完整性/去重/事务、门禁/跨日、词典聚合/词形/短语/缓存版本、FSRS/固定语境/可靠中文、导出迟到回调、旧schema磁盘迁移和失败回滚。
- 真实网络层含完整文章导入、空库冷启动和两个英语词典；本次10源29篇、Free及Wiktionary均成功。Free仍为已批准可选来源，未来不可用的skip必须单独报告，本次没有XCTest跳过。
- URLProtocol故障和原创解析fixture验证空/失败/超时/429/503/重复等分支，不冒称每个官网当次返回所有故障。UI元数据逐张保留fixtureOrProduction。
- 4个主UI分组恰好覆盖全部49方法，SE7和大屏3额外执行；真实Save、取消、重启、长文、十次旋转、大字、三主题、AX等价、嵌套、键盘、异常与重试均在现有套件中。
- Release构建验证故障/截图fixture被排除。性能测试不作真机60fps或完整VoiceOver听读结论。

## 原始截图与xcresult

327个唯一截图ID，138项状态无缺失，10源完整逐源证据；具体文件见[INDEX](../artifacts/round-3/screenshots/INDEX.md)、[manifest](../artifacts/round-3/screenshots/manifest.json)、[CSV](../artifacts/round-3/screenshots/screenshots.csv)、[COVERAGE](../artifacts/round-3/screenshots/COVERAGE.md)。654个ZIP内PNG文件含编号副本及xcresult原始附件副本，不是654个不同状态。

PNG签名、逐张SHA256、ZIP CRC及CSV/manifest对应均已核对。可复核命令：

```sh
python3 scripts/verify-round3-coverage.py artifacts/round-3/screenshots/manifest.json --report /tmp/round3-coverage.md
python3 scripts/ci-test-plan.py verify
```

[完整原始artifact与每个xcresult入口、手动复核步骤、设备/视觉限制](reviews/round-3-final-delivery-2026-11-02.md)。本次只验证文档和产物，不重新执行Swift/Xcode，不将静态检查冒称新增原生运行。历史详细用例依据见[收尾前测试计划](https://github.com/whyhaoyu1022-glitch/LexiDawn/blob/b13d6b4e21e425472d059770319d88cd7c50a15e/docs/test-plan.md)。
