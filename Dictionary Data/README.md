# Dictionary Data

本目录用于在授权范围内保存、备份和重组词典数据文件。

## 当前上传方式

原始二进制文件已拆成两个 ZIP 包，方便通过单文件大小有限的网页上传：

- dic_data-package-001.zip
- dic_data-package-002.zip

请将**两个 ZIP 包都上传到本目录**，保持文件名不变。不要只上传其中一个，也不要在上传前解压。每个 ZIP 内都包含对应的二进制分块、manifest.json 和上传说明。

> 当前仓库中的 ZIP 包需要由用户从原始文件下载后手动上传；仓库中尚未自动包含这两个包。

## 合并与校验

需要 Python 3。将两个 ZIP 包放在本目录后，在本目录运行：

    python3 merge.py --output ../dic_data_restored

merge.py 会从第一个 ZIP 包读取 manifest，检查每个包内的 manifest 是否一致，逐块验证大小和 SHA-256，再验证合并文件的总大小及 SHA-256。只有全部校验通过后才会生成目标文件。

本次原始文件信息：

- 文件名：dic_data(1)
- 原始大小：38,774,534 bytes
- 原始 SHA-256：095e9a98a95ec2a8ce7f4489fa3f338891aa29abce20e88e38ca2c5b117ba443

## 重新拆分其他文件

    python3 split.py "/path/to/input-file" --output-dir .

默认每个数据分块为 20,000,000 bytes。脚本会为每个分块创建一个独立 ZIP 包，且在每个 ZIP 中放入相同的 manifest.json。

## 版权与访问

本仓库设置为 Private。请仅在你持有的许可允许的范围内存储、备份和使用数据。私有仓库并不等于取得额外的复制、云端存储或再分发授权。不要向未获授权的人分享仓库、分块或合并后的文件。
