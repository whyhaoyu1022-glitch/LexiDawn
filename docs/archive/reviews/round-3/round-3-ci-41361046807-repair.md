# Round 3 · CI 41361046807 前置关卡核查

对应main `03a4b0edad02a18de2d644822b545536d45dd92d`，[Actions 41361046807](https://github.com/whyhaoyu1022-glitch/LexiDawn/actions/runs/41361046807)。新修复源码尚未原生复验。

## 真实失败位置

日志明确有 `TEST BUILD SUCCEEDED` 和 Release `BUILD SUCCEEDED`；Debug应用、两个测试目标和Release均编译成功。失败步骤是同一build-and-test job中的真实网络测试，不能称作Swift编译失败。

182 XCTest中181通过、1失败：`testLiveFreeDictionaryEnglishDefinition` 查询 `book` 后没有得到预期非空noun义项。HTTP日志显示Free Dictionary同一接口连续3次404。其余真实来源导入10源29篇，其他网络/迁移/事务测试通过。UI矩阵和截图合并因前置关卡失败而skipped；没有运行，不是UI测试断言失败。

CoreData损坏库/只读保存日志来自已有故障注入测试，相关方法通过，不是本次失败原因。AppIntents与strip警告也不能当作编译失败。未为这些预期日志修改数据库逻辑或删除测试。

## 修改及边界

现有Free Dictionary逻辑在404后会限次重试，但只设置reloadIgnoringLocalCacheData，重复请求没有要求中间缓存重新验证。三次404不能证明一定是CDN缓存，服务端也可能持续返回真实404。

为共享传输添加默认关闭的revalidate参数；仅Free Dictionary在第一次404后的第2、第3次请求启用 `Cache-Control: no-cache, max-age=0` 和 `Pragma: no-cache`。同一HTTPS主机、同一URL、同一词条，仍最多3次；取消、403、429/限流、解析失败和最终404语义保持。没有随机查询参数、登录/验证码绕过、换词或换Provider冒充成功。最终仍404则正常无结果；真实book集成断言仍必须取得非空noun，否则继续失败。

加强原注入404测试：必须恰好3次、后2次有重新验证头、最终空结果且URL不变。新增2项测试：注入首次404后仅重新验证请求获得真实响应字节并解析原义项；提前取消不得发请求或变成空成功。故障注入不算真实网络成功；真实Free Dictionary测试代码及断言逐字保持。

SPEC §8.2要求“数据来源”；§30原文：“**真实失败必须可见**：网络、数据库、签名或 AI 失败不能被伪装成成功。”原任务书要求“请求可取消”“重试有上限”以及不能把mock说成外网成功。本修复只处理已有词典网络链路的HTTP重试请求，依赖现有传输/Provider/Repository，不更改模型、文章准入、学习门禁或复习算法。

## 验证与未完成项

本地Linux无Xcode，只运行静态差异、Python/YAML/Shell和49主UI穷尽分组检查；确认原93单元/20UI文件、原真实book集成方法未改。源码为184 XCTest/49 UI，新增2测试尚未运行。137截图状态及所有CI关卡保持。

如果官方服务重新验证后仍404，新运行应继续红，不能把测试改为空可接受或使用其他Provider代替。导出修复和实际Save路径也仍需新UI运行验证，不能借用旧运行宣称通过。四个UI组可以因runner排队而相差十几分钟，本次全部skipped是前置测试失败导致，和慢组无关。

完成独立工作后只剩CI运行时按负责人持续授权结束对话；最终以新main真实运行结果为准。
