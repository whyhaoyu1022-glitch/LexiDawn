# 内置词典数据

`dic_data-package-001.zip` 和 `dic_data-package-002.zip` 是同一份 MDX 的二进制分包。每包包含 manifest 与分块。工程从本目录读取两个原包，文件名和目录供构建脚本使用。

从仓库根目录验证恢复，需要 Python 3。

```sh
python3 "Dictionary Data/merge.py" \
  --package-dir "Dictionary Data" \
  --manifest-package "dic_data-package-001.zip" \
  --output /tmp/LexiDawn-BundledDictionary.mdx
wc -c /tmp/LexiDawn-BundledDictionary.mdx
shasum -a 256 /tmp/LexiDawn-BundledDictionary.mdx
python3 scripts/verify-bundled-dictionary.py --mdx /tmp/LexiDawn-BundledDictionary.mdx
```

| 属性 | 已验证值 |
|---|---|
| 原文件名 | `dic_data(1)` |
| 大小 | 38,774,534 字节 |
| SHA-256 | `095e9a98a95ec2a8ce7f4489fa3f338891aa29abce20e88e38ca2c5b117ba443` |
| 格式 | MDX 2.0，UTF-16LE XML 头，UTF-8 HTML 记录，未加密 |

`merge.py` 比对 manifest，并按清单顺序核验每块及完整文件的大小与哈希。校验通过后才替换输出。需要制备分包时，使用现有 `split.py --help` 查看参数。

Xcode Build Phase 在中间目录恢复文件，成品应用含完整单文件 `BundledDictionary.mdx`，供设备离线查询。[词典功能规范](../docs/plans/round-4-dictionary-detail-addendum.md) · [实际 IPA 核验](../docs/reviews/round-4-final-delivery.md#ipa-与内置词典)
