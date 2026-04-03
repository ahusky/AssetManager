# AssetManager - 资产管理工具

一个简洁高效的 macOS 本地资产管理应用，基于 SwiftUI 构建，使用 JSON 文件持久化存储。

## 功能特性

### 核心功能
- ✅ **资产增删改查** — 完整的 CRUD 操作
- ✅ **资产核心要素** — 平台账户、项目、币种、金额、收益率、购买日期、到期日期、资产状态
- ✅ **多币种支持** — 人民币(CNY)、美元(USD)、欧元(EUR)、英镑(GBP)、日元(JPY)、港币(HKD)
- ✅ **收益率管理** — 区分预期收益率和实际收益率，支持实时预览预期收益
- ✅ **资产状态管理** — 已持有 / 已赎回 / 已归档，三级生命周期管理

### 平台管理
- ✅ **平台账户管理** — 可添加/删除平台，支持下拉快速选择或手动输入
- ✅ **自动同步** — 新增资产时自动将平台加入管理列表

### 赎回 & 归档
- ✅ **快速赎回** — 输入实际收益金额，自动计算实际年化收益率并与预期收益率对比
- ✅ **赎回时更新到期日期** — 支持修改实际到期日期（提前赎回/延迟到账）
- ✅ **一键归档** — 已赎回资产可快速归档，归档资产半透明显示

### 筛选 & 排序
- ✅ **搜索** — 按平台/项目名称搜索
- ✅ **状态筛选** — 全部/已持有/已赎回/已归档
- ✅ **平台筛选** — 按平台账户筛选
- ✅ **排序** — 支持按到期日期/购买日期排序，升序/降序切换

### 统计概览
- ✅ **持有资产总额** — 按币种分行展示，金额超万自动显示"万"
- ✅ **本年度预期收益** — 仅统计本年度到期的持有资产
- ✅ **本年度实际收益** — 仅统计本年度赎回的资产
- ✅ **加权平均收益率** — 按金额加权的平均预期收益率
- ✅ **资产笔数** — 当前筛选结果的资产数量

### 其他
- ✅ **到期预警** — 7天内到期及今日到期的资产显示 ⚠️ 警示图标
- ✅ **CSV 导出** — 支持导出为 CSV 文件（UTF-8 BOM，兼容 Excel 中文）
- ✅ **本地持久化** — JSON 文件存储，数据保存在 `~/Library/Application Support/AssetManager/`

## 系统要求

- macOS 14.0 (Sonoma) 或更高版本
- Swift 5.9+

## 项目结构

```
AssetManager/
├── Package.swift              # Swift Package 配置
├── README.md                  # 项目说明
├── build.sh                   # 打包脚本
├── logo.png                   # 应用图标
└── Sources/
    ├── AssetManagerApp.swift   # 应用入口
    ├── Models/
    │   ├── Asset.swift         # 资产数据模型（含币种、状态枚举）
    │   └── AssetStore.swift    # 数据存储管理器（JSON 持久化）
    └── Views/
        ├── AssetListView.swift # 资产列表视图（主界面、统计、表格、赎回、CSV导出）
        └── AssetFormView.swift # 资产表单视图（新增/编辑、平台管理）
```

## 构建 & 运行

### 开发调试

```bash
cd AssetManager
swift build
swift run
```

### 打包为 .app

```bash
./build.sh
# 产物: build/AssetManager.app
```

### 打包为 zip 分发

```bash
./build.sh
cd build && zip -r ../AssetManager.zip AssetManager.app
```

### 使用 Xcode

```bash
open Package.swift
# 点击 Run (⌘R) 即可运行
```

## 数据存储

数据保存在 macOS 标准应用数据目录：

```
~/Library/Application Support/AssetManager/
├── assets.json       # 资产数据
└── platforms.json    # 平台账户列表
```

备份时拷贝此文件夹即可。

## 分享给他人

1. 运行 `./build.sh` 构建
2. 将 `build/AssetManager.app` 压缩为 zip 发送
3. 对方解压后，右键点击 App → 选择"打开" → 确认即可使用
4. 无需预装数据文件，首次启动自动创建空数据库