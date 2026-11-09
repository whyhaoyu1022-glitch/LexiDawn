import SwiftUI

struct SourceLicensesView: View {
    let bundledNotices: String
    var body: some View {
        List {
            Section("完整原文与离线阅读") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("RFC Editor · RFC 8890", systemImage: "doc.text")
                    Text("M. Nottingham · IETF Trust · August 2020").font(.subheadline)
                    Text("完整原文连同版权声明保存。按IETF TLP 5 §3(c)(i)使用，原文指纹核验后才能更新。").font(.footnote)
                    Link("IETF许可条款", destination: URL(string: SourceRegistry.rfc.licenseURL)!)
                }.padding(.vertical, 6)
                VStack(alignment: .leading, spacing: 8) {
                    Label("English Wikipedia · 文字", systemImage: "text.book.closed")
                    Text("Contributors · CC BY-SA 4.0").font(.subheadline)
                    Text("固定修订版完整文字、出处和署名保存本地。非文字媒体与存在版权警告的候选不导入。").font(.footnote)
                    Link("Wikimedia使用条款", destination: URL(string: ArticleSourceRegistry.wikipediaRights.termsURL)!)
                    Link("CC BY-SA 4.0", destination: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!)
                }.padding(.vertical, 6)
                Text("个人导入只在本地使用；需要你确认全文完整及合法保存权限。文章只有完整入库后才会出现，不提供网址或摘要阅读。").font(.footnote)
            }
            Section("个人使用的官网全文来源") {
                Text("按负责人2026-11-01个人使用指示尝试公开全文；这是导入依据，不表示取得出版社授权。登录、付费墙、验证码和不完整正文跳过。")
                    .font(.footnote)
                ForEach(ArticleSourceRegistry.personalSources, id: \.id) { source in
                    Label(source.name, systemImage: "doc.text").accessibilityIdentifier("source-" + source.id)
                }
                Text("Wikinews：仅导入2024-12-17之后创建的已发布原文，保留贡献者署名与CC BY 4.0声明。 ")
                    .font(.footnote)
            }
            Section("内置词典与个人释义") {
                Text("唯一词典来源：App 内置 MDX。所有查词在设备上离线完成。").font(.subheadline)
                Text("系统英语朗读由 iOS 提供。不需要 MDD、词典图片或在线音频。").font(.footnote)
                Text("MDX 没有中文释义时，可创建标记为用户自建的个人义项。个人笔记始终可以编辑。").font(.footnote)
            }
            Section("随附原始声明") { DisclosureGroup("查看完整许可说明") { Text(bundledNotices).font(.body).textSelection(.enabled) } }
        }.navigationTitle("来源与许可")
    }
}
