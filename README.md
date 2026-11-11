# 词光 LexiDawn

原生 iOS 英文全文阅读、离线查词、生词管理和间隔复习应用。SwiftUI、SwiftData，保持 Domain / Service / Repository 分层。

Round 4 正在开发，尚未完成144项最终验收。直接在原 main 开发，无新分支或PR。[当前状态](STATUS.md) · [持续交付记录](docs/reviews/round-4-final-delivery.md) · [原21图问题](docs/reviews/round-4-first-device-21-image-audit-2026-11-06.md) · [42张实际运行截图逐张复核](artifacts/round-4/screenshots/VISUAL-REVIEW.md)。已实际逐张核对上传原包的21张HEIC和三张词典JPEG，详见[原图复核](docs/reviews/round-4-original-image-recheck-2026-11-11.md)。

## 当前词典规则

唯一词典来源：App 内置 MDX。`Dictionary Data/` 中两个ZIP是同一文件的分块，构建时由原 `merge.py` 按manifest恢复、验证，完整单一文件进入App Bundle。运行时不下载、不访问GitHub，不支持用户导入词典，无其他词典Provider或自动回退。

批准MDX为38,774,534字节，SHA256 `095e9a98a95ec2a8ce7f4489fa3f338891aa29abce20e88e38ca2c5b117ba443`。实际MDX2.0/UTF8 HTML/未加密，原生C/zlib按需读块，Swift Actor管理索引和128词LRU，系统libxml2解析结构。只声明支持这份实测格式，不宣称通用加密/LZO支持。App不包含Python解释器。

系统发音使用 AVSpeechSynthesizer，可开始、停止和报告系统语音不可用。不需要MDD、词典图片、音频文件或在线发音API。音标只展示，不当普通英文朗读。

只有MDX成功确认没有中文释义或没有词条，才允许结构化个人词。支持多词性、多义项、配对例句/翻译、搭配/短语/习语、语法/语域/场景/备注、确认和修订历史。MDX已有中文时所有个人义写入口锁定，独立笔记仍可编辑；旧个人内容只读保留。资源缺失/损坏/解析错误绝不冒充无词。

完整词典、阅读浮层、生词和复习共享词义身份。新题冻结义项、来源版本、原句/原词形/位置、答案和seed/mask；进行中题不因新查询暗换答案。显示答案后必须亲自输入正确答案，仍计Again，FSRS事件幂等。

## 产品入口

- 今日：继续最早未完成周期，精简来源、真实阅读/连线/拼写状态，只保留文章库总量摘要。
- 文章库：完整本地库存、当前结果数、全部/收藏/稍后/历史可见筛选；收藏和稍后独立持久化。
- 发现：今日、书库和探索共用 ArticleDiscoveryService，展示真实runID、来源数/阶段/活跃来源、导入/去重/失败及停止。
- 阅读器：完整离线原文、自然段落/标题/列表/引用、原始offset映射、阅读恢复、三主题/横屏/动态字体；点词显示附近小浮层，箭头进入完整词典。
- 探索和词汇推荐：完成当前必做后解锁；主题渐变卡、收藏/稍后和紧凑词卡；浏览推荐不会自动加入。
- 生词：离线搜索、多词性个人编辑、笔记自动保存/草稿恢复、版本历史、安全撤销、JSON/CSV导出。
- 复习：真实可见曲线连线、按题反馈、持久化拼写与纠正、FSRS4.5、明确延期、简洁完成页和次级日志。
- 设置：自动保存及失败重试，关于页开发者Why Haoyu、实际Bundle版本/build。

已有周期、全文、笔记、词汇、上下文、排程、已完成及未完成题组保留；升级前备份，失败报错，不删除数据库或要求重装清库。

## 文章数据

继续尝试已登记的BBC、Reuters、AP、Guardian、NPR、DW、VOA、NASA、ScienceDaily、Phys.org、Smithsonian、Wikipedia/Wikinews公开完整正文。配置不代表实际成功，逐源尝试/结果分别记录。不绕过登录、验证码或付费墙；完整性/事务检查不通过就放弃，无摘要、链接或WebView阅读降级。原始来源元数据保留在数据层及次级详情。

## 实际验证与构建

`4739708` 的 [42657203329](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/42657203329) 完成全目标编译、Release Simulator、227 XCTest/0失败；该轮UI被跳过，不能称完整通过。相同提交的[未签名IPA](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/42659832536/artifacts/13692674476) 已下载检查，实际Bundle包含批准MDX，版本0.1.0(20)、最低iOS27.0，未真机安装。

原图审查批次 [43031419700](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/43031419700) 已编译全部目标和 Release，234 XCTest 中232通过、2项真实 MDX 词头分组/自身参见断言失败，UI 当轮未执行。两处问题已针对实际词典结构修改。当前235 XCTest、63 XCUITest为源码数量，待新版验证。

产品最低iOS27.0。当前CI Xcode26.6/SDK26.5及临时iOS26.5 Simulator仅为兼容验证，不能冒充iOS27真机验收。Linux开发容器无Xcode/Simulator，真实原生运行由macOS Actions完成。所有旧测试保留；4主UI分组和SE/大屏专项穷尽分配，fail-fast关闭，逐方法核对实际执行，失败也导出原始PNG/xcresult。

```sh
python3 scripts/ci-test-plan.py verify
python3 scripts/test-bundled-dictionary.py
xcodebuild -project LexiDawn.xcodeproj -scheme LexiDawn -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

[主规范](SPEC.md) · [Round4规范](docs/plans/round-4-development-specification.md) · [词典补充](docs/plans/round-4-dictionary-detail-addendum.md) · [架构](docs/architecture.md) · [追踪](docs/requirements-traceability.md) · [测试计划](docs/test-plan.md) · [安装说明](docs/signing.md)。历史Round3结果单独保留于[原交付报告](docs/reviews/round-3-final-delivery-2026-11-02.md)，不得作为本轮通过证据。
