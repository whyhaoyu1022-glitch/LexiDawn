# Dictionary Data

本目录保存经授权可使用的词典数据分块，以及拆分、合并和完整性校验工具。

## 已上传的数据包

两个 ZIP 包已从仓库根目录移动到本目录。请保留原文件名：

- `dic_data-package-001.zip`
- `dic_data-package-002.zip`

每个 ZIP 包都包含对应的二进制分块、`manifest.json` 和上传说明。两个包都必须存在，才能完整恢复原始文件。

## 合并与校验

需要 Python 3。进入本目录后运行：

```bash
python3 merge.py --output ../dic_data_restored
```

也可以从仓库根目录运行：

```bash
python3 "Dictionary Data/merge.py" \
  --package-dir "Dictionary Data" \
  --output dic_data_restored
```

合并程序会：
1. 从第一个 ZIP 包读取清单；
2. 检查每个 ZIP 包内的清单是否一致；
3. 按清单顺序提取数据分块；
4. 校验每个分块的字节数和 SHA-256；
5. 校验合并文件的总字节数和 SHA-256；
6. 只有全部校验通过后才生成最终文件。

如果任一分块缺失、包名不正确或校验失败，程序会报错并删除临时输出文件。

## 原始文件校验信息

- 原始文件名：`dic_data(1)`
- 原始大小：`38,774,534` bytes
- 原始 SHA-256：`095e9a98a95ec2a8ce7f4489fa3f338891aa29abce20e88e38ca2c5b117ba443`

## 工具

- `split.py`：将本地二进制文件拆分成 ZIP 数据包，并生成 SHA-256 清单。
- `merge.py`：从 ZIP 数据包恢复原文件，并执行完整性校验。

重新拆分其他文件的示例：

```bash
python3 split.py "/path/to/input-file" --output-dir .
```

默认每个原始分块为 20,000,000 bytes。

## 访问与版权

本仓库设置为 Private。请仅在你持有的许可允许的范围内存储、备份和使用数据。私有仓库并不自动授予额外的复制、云端存储或再分发权利。不要向未获授权的人分享仓库、数据包或恢复后的文件。
