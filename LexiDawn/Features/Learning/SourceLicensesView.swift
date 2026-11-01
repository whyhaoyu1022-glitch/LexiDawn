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
            Section("开放词典与个人释义") {
                Text("CC-CEDICT · MDBG与贡献者 · CC BY-SA 4.0；反向索引提供可能中文对应词。").font(.subheadline)
                Link("CC-CEDICT来源与许可", destination: URL(string: "https://www.mdbg.net/chinese/dictionary?page=cc-cedict")!)
                Text("Free Dictionary API和English Wiktionary按返回的原始义项、词性、发音及例句展示；每条来源及许可随结果保留。没有可靠中文时使用明确标记的个人释义。").font(.subheadline)
                Link("Free Dictionary API说明", destination: URL(string: "https://dictionaryapi.dev/")!)
                Link("Wiktionary项目许可", destination: URL(string: "https://en.wiktionary.org/wiki/Wiktionary:Copyrights")!)
            }
            Section("随附原始声明") { DisclosureGroup("查看完整许可说明") { Text(bundledNotices).font(.body).textSelection(.enabled) } }
        }.navigationTitle("来源与许可")
    }
}
