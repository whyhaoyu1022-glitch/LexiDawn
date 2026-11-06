# Round 4 · 首次真机21图逐张审阅记录

状态：**全部21张原图已逐张人工查看；本轮仅形成计划，尚未整改代码、运行新测试或取得整改后真机截图。**

用户2026-11-06的新批注及本次指令优先于旧SPEC中的冲突UI/交互要求。所有强制项继续在[开发任务书](../plans/round-4-development-specification.md)统一验收。

## 原始证据与阅读方法

上传包：`修改意见(1).zip`；SHA256：`e754df2436b246c4798a95775a5f10e7776bd56c85fb7045ff5351b2ff302528`。ZIP共43项：1目录、21张HEIC、21个macOS资源旁文件；按文件名排序后建立P01–P21，**不是按ZIP物理顺序编号**。21个原件SHA均不同。

逐张查看完整解码图，再对手写、黑字深底、重复圈线、密集示意做局部放大；预览未替换原件。下列记录把用户批注、实际界面、代码证据和工程解释分开。小点/无字短线逐图说明，不臆造额外要求。部分手写连接字不够确定时明确标注，不拿猜测当原话；此类字形不影响相应整改动作。

图像边长约1206×2622；未从分辨率猜手机型号/iOS版本。当前代码审查基线main `6840b2d0d786c88d6c067feebd16df968c50849a`，此前IPA构建代码`39c5f7056644972ca0030a1cb041400a08d52c3c`。截图本身未暴露build，正式复现必须记录实装包与设备信息，不能仅由文件名断言版本。

原图定位使用“上传包/IMG_xxxx.heic”；本文不把预览图当整改后截图。完整哈希、尺寸、摘录、要求与验收在[机器可读清单](round-4-feedback-manifest.json)。

| 审阅ID | 原图 | 页面/问题 | 优先级 | 需求 / 测试 |
|---|---|---|---|---|
| R4-P01 | `IMG_8854.heic` | 今日任务卡删除技术性版权/个人模式长文案 | P1 | R4-F01 / R4-T01 |
| R4-P02 | `IMG_8857.heic` | 今日统一真实多来源刷新，解释并降级RFC入口 | P1 | R4-F02 / R4-T02 |
| R4-P03 | `IMG_8858.heic` | 消除今日重复文章区，统一数量与标题质量 | P1 | R4-F03 / R4-T03 |
| R4-P04 | `IMG_8859.heic` | 文章库总量与收藏/稍后入口可发现 | P1 | R4-F04 / R4-T04 |
| R4-P05 | `IMG_8860.heic` | 发现/导入显示真实进度与正在访问的来源 | P1 | R4-F05 / R4-T05 |
| R4-P06 | `IMG_8862.heic` | 阅读器完整标题可换行 | P1 | R4-F06 / R4-T06 |
| R4-P07 | `IMG_8863.heic` | 正文排除视频/脚本控件等非文章内容 | P0 | R4-F07 / R4-T07 |
| R4-P08 | `IMG_8864.heic` | 复习入口先预检，失败用可处理弹窗 | P0 | R4-F08 / R4-T08 |
| R4-P09 | `IMG_8866.heic` | 生词词元正确、释义笔记自动保存 | P0 | R4-F09 / R4-T09 |
| R4-P10 | `IMG_8867.heic` | 连线答案符合语境、词形与大小写 | P0 | R4-F10 / R4-T10 |
| R4-P11 | `IMG_8869.heic` | 拼写挖空位置多样且固定可恢复 | P1 | R4-F11 / R4-T11 |
| R4-P12 | `IMG_8870.heic` | 完成页移除默认逐词排程日志墙 | P1 | R4-F12 / R4-T12 |
| R4-P13 | `IMG_8872.heic` | 探索改为每篇一张完整渐变卡片 | P1 | R4-F13 / R4-T13 |
| R4-P14 | `IMG_8873.heic` | 生词上下文去重复URL与内部导入长说明 | P1 | R4-F14 / R4-T14 |
| R4-P15 | `IMG_8875.heic` | 生词详情与完整词典合为单一详细页 | P1 | R4-F15 / R4-T15 |
| R4-P16 | `IMG_8876.heic` | 可靠词典优先、CC-CEDICT最低、词性明确 | P0 | R4-F16 / R4-T16 |
| R4-P17 | `IMG_8878.heic` | 词汇推荐改为紧凑渐变词卡 | P1 | R4-F17 / R4-T17 |
| R4-P18 | `IMG_8879.heic` | 复习按钮有边界，反馈不能串题 | P0 | R4-F18 / R4-T18 |
| R4-P19 | `IMG_8880.heic` | 显示答案后必须亲自正确输入再推进 | P0 | R4-F19 / R4-T19 |
| R4-P20 | `IMG_8881.heic` | 设置自动保存，新增关于页与开发者名 | P1 | R4-F20 / R4-T20 |
| R4-P21 | `IMG_8883.heic` | 阅读查词改为小浮层，箭头进入新全屏详情 | P1 | R4-F21 / R4-T21 |

## R4-P01 · IMG_8854.heic · 今日任务卡删除技术性版权/个人模式长文案

原件：1206×2565，1453704字节；SHA256 `f1b57d1c74afa1c30c916b107abf3b29b2a7db942593f41ce6680145e21dc25b`。

**用户批注摘录与圈画**

手写“去掉”。

白色椭圆圈住Deutsche Welle后方的“原作者及原始版权归属保留 · 按负责人个人使用指示本地导入…”；并非圈住整个文章标题或任务卡。

**画面事实**

任务卡标题很大，发布方后接内部导入政策，灰色长文被截断。阅读0%、分配日期/时区和三个阶段也同时占据首屏。

**工程核查与任务定位**

- `LexiDawn/Features/Learning/LearningHome.swift:LiveTodayView.hero`
- `LexiDawn/Domain/Learning/PublisherSources.swift:ArticleSourceRegistry.evidence`
- `LexiDawn/Data/FullTextRepository.swift:ContentRepository.importFullText`

独立闭环：R4-F01；验收5项；测试族R4-T01。完整实现与逐项判据见任务书同编号章节。


## R4-P02 · IMG_8857.heic · 今日统一真实多来源刷新，解释并降级RFC入口

原件：1206×2620，1389860字节；SHA256 `6627297897b05ae88cb51bdc175579d8bb1fa73888e634e0c06afb354834d6eb`。

**用户批注摘录与圈画**

上方手写“意义不明”；RFC旁手写质疑其含义（“RFC”清楚，连接字笔迹不强行逐字定为产品文案）；下方“未看见BBC等新闻来源”。

“使用官方 RFC 原文”和“从官方来源刷新”分别被白圈标出，箭头指向意见。

**画面事实**

用户看到两项含糊动作，不能判断刷新的是RFC还是新闻。图中下方已出现BBC卡，因此不能据此断言BBC从未导入。

**工程核查与任务定位**

- `LexiDawn/Features/Learning/LearningHome.swift:LiveTodayView阅读内容区/refreshDiscovered`
- `LexiDawn/Data/ContentRepository.swift:ArticleAcquisitionService.refresh`
- `LexiDawn/Data/ArticleNetwork.swift:ArticleDiscoveryService.refresh`

独立闭环：R4-F02；验收5项；测试族R4-T02。完整实现与逐项判据见任务书同编号章节。


## R4-P03 · IMG_8858.heic · 消除今日重复文章区，统一数量与标题质量

原件：1205×2622，988146字节；SHA256 `29c00e705e502cd00c11ff6dbc9684213fd3ee67f5700a380cc83478a6cac1fc`。

**用户批注摘录与圈画**

手写“文章…不对”“而且这个板块有何意义？”；中间连笔字未强行逐字定为“数量”或“质量”，工程上同时核查条数与标题质量，以整块“本地完整原文”列表为对象。

白字覆盖BBC/NPR/DW卡片；下方ScienceDaily标题仍显示“Don&apos;t”“November&apos;s”实体文本。

**画面事实**

今日预览与完整文章库混在一起，预览每源一篇且最多6篇；数量容易被误认成库存。标题实体也未完全解码。

**工程核查与任务定位**

- `LexiDawn/Features/Learning/LearningHome.swift:highlightedArticles（seen sourceID + prefix(6)）`
- `LexiDawn/Data/ArticleNetwork.swift:ArticleFeedParser`
- `LexiDawn/Domain/Learning/ArticleWebPageExtractor.swift:标题提取`
- `LexiDawn/Domain/Learning/ArticleHTMLExtractor.swift:decodeEntities`

独立闭环：R4-F03；验收5项；测试族R4-T03。完整实现与逐项判据见任务书同编号章节。


## R4-P04 · IMG_8859.heic · 文章库总量与收藏/稍后入口可发现

原件：1206×2620，926090字节；SHA256 `9db1ab75fa60d2dc2344345dd4f1413e03b2fdf69c9d8d2fb3fb6910bc545c9a`。

**用户批注摘录与圈画**

“1.未显示文章总数量”；收藏/稍后旁手写“未找到其他入口”。

白圈同时圈住收藏和稍后阅读两个操作，向上箭头表示找不到之后查看这些内容的地方。

**画面事实**

现有阅读内容Picker实际上含收藏/稍后/历史，但隐藏在“全部”的菜单里；页面无总量和结果数。

**工程核查与任务定位**

- `LexiDawn/Features/Learning/ArticleLibraryFeature.swift:visible、阅读内容Picker、flags`
- `LexiDawn/Data/FullTextRepository.swift:setLibraryFlags`

独立闭环：R4-F04；验收5项；测试族R4-T04。完整实现与逐项判据见任务书同编号章节。


## R4-P05 · IMG_8860.heic · 发现/导入显示真实进度与正在访问的来源

原件：1206×2622，1049142字节；SHA256 `c9a54257151a02989e9e36faa4a4ef617bc3c8c462460b5e97c9261a026cb8a4`。

**用户批注摘录与圈画**

粉色：“增加一个进度条，并且显示当前正在搜索哪个网站”；白色：“未显示进度”。

白圈圈住旋转指示器和“正在导入完整文章…”；箭头标出缺少进度。

**画面事实**

只有不定进度旋转图与停止按钮，看不到多来源是否仍在工作或卡住。

**工程核查与任务定位**

- `LexiDawn/Data/ArticleNetwork.swift:ArticleDiscoveryService及3路并发`
- `LexiDawn/Features/Learning/ArticleLibraryFeature.swift:loading/refresh`
- `LexiDawn/Features/Learning/LearningHome.swift:discover/refreshDiscovered`

独立闭环：R4-F05；验收5项；测试族R4-T05。完整实现与逐项判据见任务书同编号章节。


## R4-P06 · IMG_8862.heic · 阅读器完整标题可换行

原件：1171×2622，800005字节；SHA256 `3ff72be8cc02c6c1f9f461986767d58bcc799447610376b4792bbdc5cd5f7b2b`。

**用户批注摘录与圈画**

“把标题显示全，可以换行”。

白色大圈覆盖标题、来源作者、日期和“来源与许可”，焦点是被省略的标题。

**画面事实**

DW长标题只显示一行并出现省略号；抬头与来源信息占用固定顶部空间。

**工程核查与任务定位**

- `LexiDawn/Features/Learning/ReaderFeature.swift:ReaderView标题lineLimit`
- `LexiDawn/Features/Learning/InteractiveEnglishText.swift:正文视口/恢复`

独立闭环：R4-F06；验收5项；测试族R4-T06。完整实现与逐项判据见任务书同编号章节。


## R4-P07 · IMG_8863.heic · 正文排除视频/脚本控件等非文章内容

原件：1206×2622，677961字节；SHA256 `a382ae8d1aa72653a8bb9cfb64527ca8290d890507975392036c4fb44050820b`。

**用户批注摘录与圈画**

“去掉这些无用内容”。

白圈圈住“To view this video please enable JavaScript, and consider upgrading to a web browser that supports HTML5 video”；长箭头指向删除意见。

**画面事实**

视频播放失败提示被渲染成正文段落，打断DW文章。

**工程核查与任务定位**

- `LexiDawn/Domain/Learning/ArticleHTMLExtractor.swift:excluded目前未涵盖video/noscript`
- `LexiDawn/Domain/Learning/ArticleWebPageExtractor.swift:正文子树选择`
- `LexiDawn/Domain/Learning/ArticleDocument.swift:结构与显示投影`
- `LexiDawn/Data/ReaderRepository.swift:内容版本/偏移`

独立闭环：R4-F07；验收5项；测试族R4-T07。完整实现与逐项判据见任务书同编号章节。


## R4-P08 · IMG_8864.heic · 复习入口先预检，失败用可处理弹窗

原件：1206×2622，1029371字节；SHA256 `9c76007bbf3f7530e4c7d0013997d011be05a098aadce26e0adbe20fa902d71d`。

**用户批注摘录与圈画**

“这里的逻辑改一下，如果报错的话弹出一个弹窗，提示错误信息，然后弹窗的选项可以选择取消，忽略这个单词，或者立即填写，跳转到生词本填写的界面。不仅仅针对这个报错，凡是报错了就不要进入复习的这个界面了，就要弹出错误窗口，可以选择忽略取消或者是解决方法”。

无额外大圈，白色整段批注指向红色effectively无中文义项错误与下方不相干空态。

**画面事实**

错误、FSRS说明、请先获得文章、重试同时出现；用户已积累词但被一个词阻塞。

**工程核查与任务定位**

- `LexiDawn/Features/Learning/ReviewFeature.swift:load的catch与session=nil分支`
- `LexiDawn/Data/ReviewRepository.swift:prepare/insertExercises题组与无义项抛错`
- `LexiDawn/Features/Learning/LearningHome.swift:review sheet入口`

独立闭环：R4-F08；验收5项；测试族R4-T08。完整实现与逐项判据见任务书同编号章节。


## R4-P09 · IMG_8866.heic · 生词词元正确、释义笔记自动保存

原件：1206×2622，1811506字节；SHA256 `c79dbe8603818b296aad1636518737628e08c6311a3e50b6109a07a2409fe5c1`。

**用户批注摘录与圈画**

“这个保存完全就是没有任何必要，我觉得完全可以实现输入完成之后自动保存，我觉得这个技术上应该不是很难”；红字“不应有复数”；“而且不一定要用户点击完成输入才保存，只要这个键盘消失了，那就可以保存了”。

红圈圈住users的s；白圈分别圈右上保存与键盘上方完成输入。

**画面事实**

users作为主词条；填写“用户”后还需点保存，键盘收起不会自动提交。

**工程核查与任务定位**

- `LexiDawn/Features/Learning/VocabularyFeature.swift:VocabularyDetailView.save/toolbar/FocusState`
- `LexiDawn/Domain/Learning/LearningRules.swift:EnglishTokenizer.lemma`
- `LexiDawn/Data/VocabularyRepository.swift:add/annotate`

独立闭环：R4-F09；验收6项；测试族R4-T09。完整实现与逐项判据见任务书同编号章节。


## R4-P10 · IMG_8867.heic · 连线答案符合语境、词形与大小写

原件：1205×2622，1057714字节；SHA256 `68220b5528e10f1fb81011b93701a42bf90eb59dd56d5a6afd82c1bd2942daef`。

**用户批注摘录与圈画**

visits的s旁圈问号；圈出may与“五月份”，手写“应大写”。

白圈分别圈may、五月份；另在visits末尾标问号。

**画面事实**

图上provide→具、visits→人次、should→合该、may→五月份均显示绿色已匹配；绿色只证明senseID匹配，不能证明语义正确。

**工程核查与任务定位**

- `LexiDawn/Data/ReviewRepository.swift:insertExercises的ranked.first及meaning/senseID`
- `LexiDawn/Data/DictionaryAggregation.swift:rank`
- `LexiDawn/Domain/Learning/LearningRules.swift:词形与大小写规范`

独立闭环：R4-F10；验收5项；测试族R4-T10。完整实现与逐项判据见任务书同编号章节。


## R4-P11 · IMG_8869.heic · 拼写挖空位置多样且固定可恢复

原件：1206×2622，1243068字节；SHA256 `cc18c3762dfcadd0209e7695d8751e766e791ad07db1f0a2085ccb793f3e2a49`。

**用户批注摘录与圈画**

黑色批注“目前好像扣掉都是结尾的字母，”（原字“扣”保留，含义为挖空集中在词尾）。

白圈圈住prov…提示；黑字位于深色背景，已单独放大核对。

**画面事实**

provide只保留前缀，词尾被连续遮掉；与当前mask从尾部反向取字母一致。

**工程核查与任务定位**

- `LexiDawn/Domain/Learning/LearningRules.swift:BasicReviewScheduler.mask`
- `LexiDawn/Data/ReviewRepository.swift:cloze prompt创建`
- `LexiDawn/Domain/Learning/ClozeContext.swift:原句整词遮空`

独立闭环：R4-F11；验收5项；测试族R4-T11。完整实现与逐项判据见任务书同编号章节。


## R4-P12 · IMG_8870.heic · 完成页移除默认逐词排程日志墙

原件：1206×2622，1242588字节；SHA256 `c97902f9413febabed28a24194921e3d84b838e64152000401a72e18e27314d6`。

**用户批注摘录与圈画**

手写“不需显示”。

大白圈圈住should、effectively、visits、users、may、provide的Good/Hard与原定→下次长日志；箭头标示该区域。

**画面事实**

复习完成后大量日期/算法解释占满页面，下方仍出现正确已保存与重新读取/重试。

**工程核查与任务定位**

- `LexiDawn/Features/Learning/ReviewFeature.swift:ForEach(schedules)、feedback、常驻重试`
- `LexiDawn/Data/ReviewRepository.swift:scheduleFeedback/extraScheduleFeedback`

独立闭环：R4-F12；验收5项；测试族R4-T12。完整实现与逐项判据见任务书同编号章节。


## R4-P13 · IMG_8872.heic · 探索改为每篇一张完整渐变卡片

原件：1206×2622，1981195字节；SHA256 `0f3a649f8a55a02fd2c8a68ccd30583db6e49d98362b3e6b95cb0de594118199`。

**用户批注摘录与圈画**

“太难看了，重新设计一下这个界面，可以把标题放到这个渐变色的框里，然后字体可以换成首页那个字体，然后把其他的信息也放在框里，在下面排成一行小字就行了。总之这个探索就改成每个框，对应一篇文章就行了，信息全部都放在框里面。然后呢，对应不同主题框的渐变色颜色可以有区分。总之要设计得漂亮一些。”

蓝色整段意见；大白圈囊括上方渐变装饰、卡外标题、元信息及收藏/稍后按钮。

**画面事实**

渐变区只画图标，标题和若干重复元数据在下面逐行展开；一篇内容被视觉切碎。

**工程核查与任务定位**

- `LexiDawn/Features/Learning/LearningHome.swift:LiveExploreView/ExploreArticleCard`
- `LexiDawn/DesignSystem/DesignTokens.swift`

独立闭环：R4-F13；验收5项；测试族R4-T13。完整实现与逐项判据见任务书同编号章节。


## R4-P14 · IMG_8873.heic · 生词上下文去重复URL与内部导入长说明

原件：1205×2622，1477758字节；SHA256 `10ebb6633300217b97faad0d3528971379b3837f539827dba131a4fadc0471af`。

**用户批注摘录与圈画**

手写“去掉”；多根箭头对应多个圈。

圈出来源卡attribution+URL、重复原文URL，以及下方同一来源再次出现的attribution/URL；非要求删除当前原句。

**画面事实**

一页中同一DW标题和网址多次出现；用户读义项时被出处长串和个人导入解释干扰。

**工程核查与任务定位**

- `LexiDawn/Features/Learning/VocabularyFeature.swift:VocabularyDetailView来源上下文Section`
- `LexiDawn/Data/VocabularyRepository.swift:VocabularySourceContext/VocabularyItem`
- `LexiDawn/Data/FullTextRepository.swift:sourceAttribution拼接canonical`

独立闭环：R4-F14；验收5项；测试族R4-T14。完整实现与逐项判据见任务书同编号章节。


## R4-P15 · IMG_8875.heic · 生词详情与完整词典合为单一详细页

原件：1206×2621，1279485字节；SHA256 `4ed7adc0721a4d494a90c430e21674d670c05b2b350703f79dd511c38a12e9f8`。

**用户批注摘录与圈画**

“去掉这个部分，把里面的内容合并到一起”。

白圈圈住“详细词典”导航行，箭头指向意见；不是要求删除词典内容。

**画面事实**

已经展示长义项列表的生词详情还要再点详细词典，内容和入口重复。

**工程核查与任务定位**

- `LexiDawn/Features/Learning/VocabularyFeature.swift:DictionaryResultContent + NavigationLink详细词典`
- `LexiDawn/Features/Learning/ReaderFeature.swift:DictionaryDetailView/DictionaryResultContent`

独立闭环：R4-F15；验收5项；测试族R4-T15。完整实现与逐项判据见任务书同编号章节。


## R4-P16 · IMG_8876.heic · 可靠词典优先、CC-CEDICT最低、词性明确

原件：1206×2622，1018644字节；SHA256 `197522dae6ae40057892b3ec49e7efa1ed3162a22f29540c4e6499d444035ed9`。

**用户批注摘录与圈画**

“词性未注明”“未发现其他词典来源。而且这个CC开头的这个来源准确性太低了，这个来源的优先级最低，优先采用其他可靠词典上的词典。”

白圈圈住“已合并：CC-CEDICT”；白色整段批注覆盖不可靠中文义项。

**画面事实**

need只见CC-CEDICT的“须需/得要/待”等反向候选，词性未注明；不能把“有两Provider代码/CI一次成功”当设备上真实可用。

**工程核查与任务定位**

- `LexiDawn/Data/DictionaryAggregation.swift:DictionaryAggregator.lookup/merge/rank`
- `LexiDawn/Data/VocabularyRepository.swift:DictionaryLookupService.lookup/localResult`
- `LexiDawn/Data/ReviewRepository.swift:primeMeanings/insertExercises`
- `LexiDawn/Features/Learning/ReaderFeature.swift:DictionaryQuickMeaning.quickSenses`
- `LexiDawn/Features/Learning/VocabularyFeature.swift:lookup未传上下文`

独立闭环：R4-F16；验收6项；测试族R4-T16。完整实现与逐项判据见任务书同编号章节。


## R4-P17 · IMG_8878.heic · 词汇推荐改为紧凑渐变词卡

原件：1206×2622，939696字节；SHA256 `8dedb9d37fe854225c6d7561cc19de5eed65a84c611475f832e860215a2a81fd`。

**用户批注摘录与圈画**

“这个界面也要重新设计，就是和探索一样，也是设计成一个个渐变颜色的小框，每个小框里面只显示英文、音标和中文简明示意就是词典的示意，然后用户点击之后就跳转到详细词典的界面”。（“示意”按原字记录，产品含义为释义。）

整段白字覆盖推荐理由/原句/查看详情/加入的冗长块。

**画面事实**

anti-corruption一张大卡有许多分隔线、推荐理由、文章原句和两个动作，信息密度失衡。

**工程核查与任务定位**

- `LexiDawn/Features/Learning/VocabularyRecommendationFeature.swift:ForEach Section`
- `LexiDawn/Data/VocabularyRecommendations.swift:discover`
- `LexiDawn/Features/Learning/ReaderFeature.swift:DictionaryDetailView`

独立闭环：R4-F17；验收5项；测试族R4-T17。完整实现与逐项判据见任务书同编号章节。


## R4-P18 · IMG_8879.heic · 复习按钮有边界，反馈不能串题

原件：1206×2621，1083997字节；SHA256 `69467b3d60a6d13a705faa50c675668a4a48ca80be9b19877bf5083e9866e777`。

**用户批注摘录与圈画**

手写“意义不明”；“这几个包括使用提示这几个按钮需要重新设计这些按钮加上边框，然后呢，这些按钮显示逻辑好像存在问题，我不知道为什么在输入的时候会显示一个绿色正确，已保存这个东西，这个地方需要重新设计。并且检查一下逻辑问题，现在完全不美观”。

白圈圈“使用提示”、绿色“正确，已保存”和“重新读取/重试”；箭头连接反馈到文字意见。

**画面事实**

observer尚未提交、键盘打开时，下方已经显示绿色成功；普通按钮看起来是解释文本。

**工程核查与任务定位**

- `LexiDawn/Features/Learning/ReviewFeature.swift:共享feedback、cloze选择first incomplete、submit`
- `LexiDawn/Features/Learning/ReviewFeature.swift:无条件重新读取按钮`

独立闭环：R4-F18；验收5项；测试族R4-T18。完整实现与逐项判据见任务书同编号章节。


## R4-P19 · IMG_8880.heic · 显示答案后必须亲自正确输入再推进

原件：1206×2622，951191字节；SHA256 `e9e2b81ea27bc3c4489c489cca3e3b04c1678884e1958ae5482f8788fa1e2e33`。

**用户批注摘录与圈画**

“用户点击显示答案之后，应该让用户在输入一遍正确答案，而不是直接跳转到下一题”。（“在”按原字记录。）

白圈圈“答案：product。本题记录为Again。”及其下方重试；右上少量白点无独立可辨文字。

**画面事实**

当前题干为commo____，答案反馈却为product，进一步表明已推进到下一题但旧反馈仍在。

**工程核查与任务定位**

- `LexiDawn/Data/ReviewRepository.swift:submitSaved中的correct || reveal直接完成`
- `LexiDawn/Features/Learning/ReviewFeature.swift:显示答案回调与first incomplete切题`
- `LexiDawn/Data/LearningModels.swift:ReviewExerciseRecord`

独立闭环：R4-F19；验收5项；测试族R4-T19。完整实现与逐项判据见任务书同编号章节。


## R4-P20 · IMG_8881.heic · 设置自动保存，新增关于页与开发者名

原件：1206×2622，1135991字节；SHA256 `5e256a4df4f6432574b194b56dbebf89eab733877c9014e2f3ff45480105e3dd`。

**用户批注摘录与圈画**

“改成自动保存，同时增加一个关于页面，显示本应用的开发者Why Haoyu，喝一些其他的信息”。（“喝”为原图文字，理解为“和”。）

白圈圈“保存设置”；左上及右侧少量白点/短笔画不另推导隐藏需求。

**画面事实**

主题、自动加入、每日上限和时区修改后还需找底部保存；关于只有准备中与许可入口。

**工程核查与任务定位**

- `LexiDawn/Features/Learning/SettingsFeature.swift:LearningSettingsView.save/load/Form`
- `LexiDawn/Data/Repositories.swift:PreferencesRepository`
- `LexiDawn/Features/Learning/SourceLicensesView.swift`

独立闭环：R4-F20；验收5项；测试族R4-T20。完整实现与逐项判据见任务书同编号章节。


## R4-P21 · IMG_8883.heic · 阅读查词改为小浮层，箭头进入新全屏详情

原件：1205×2618，1394702字节；SHA256 `ade6a1dd41c0fd7d934b410d9d3249eb92a9112e0ed497baf38f5447f5d9fe1f`。

**用户批注摘录与圈画**

“这个点击单词，查看释义的界面需要大幅修改，首先现在弹出的窗口太大了，只需要我画的那个方框那么大就足够了。上面只要显示我的那个示意图的那些信息，然后呢，下面的左边是一个对号，表示成功加入生词本，可以点击撤销，然后右下角是一个指向右侧的一个箭头，点击可以查看详细解释。详细解释就应该进入一个新的全屏界面”。

圈中prices为触发词；白色矩形示意含“英文词条/音标”、v./adj.中文义项、左下勾号与“撤销”、右下圆圈右箭头。

**画面事实**

本图展示期望示意，并非已实现浮层；当前代码实际默认large sheet并堆列表。

**工程核查与任务定位**

- `LexiDawn/Features/Learning/ReaderFeature.swift:WordLookupSheet默认detent=.large`
- `LexiDawn/Features/Learning/ReaderFeature.swift:DictionaryQuickMeaning/DictionaryDetailView`
- `LexiDawn/Features/Learning/InteractiveEnglishText.swift:词元点击及几何定位`
- `LexiDawn/Data/VocabularyRepository.swift:VocabularyAddition/undo`

独立闭环：R4-F21；验收6项；测试族R4-T21。完整实现与逐项判据见任务书同编号章节。

## 核对结论

21/21完整图已查看；7张另做批注放大。P01–P21各自有需求、代码关联、测试族和独立验收条目，共108条逐图验收标准。关联问题可以共用实现，但不能合并后只关闭其中一张图。

P02中“未看见BBC等新闻来源”与同图底部BBC卡并存，所以任务是刷新行为/命名/可发现性整改，不能写成BBC从未接入。P10展示已画线却语义错误，应独立验语义与连接正确性。P19同时暴露答案揭示自动推进和上题反馈串题，必须一起解决。P21是用户画的期望布局，不能作为现有小浮层已实现证据。
