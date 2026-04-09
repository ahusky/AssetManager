import SwiftUI
import UniformTypeIdentifiers

/// 资产列表视图
struct AssetListView: View {
    @EnvironmentObject private var store: AssetStore

    @State private var searchText = ""
    @State private var filterStatus: AssetStatus? = nil
    @State private var filterPlatform: String = ""
    @State private var sortField: SortField = .maturityDate
    @State private var sortAscending: Bool = true
    @State private var showingAddSheet = false
    @State private var selectedAsset: Asset? = nil
    @State private var showingDeleteAlert = false
    @State private var assetToDelete: Asset? = nil
    @State private var showExportSuccess = false
    @State private var assetToRedeem: Asset? = nil
    @State private var assetToArchive: Asset? = nil
    @State private var showArchiveAlert = false

    /// 排序字段
    enum SortField {
        case purchaseDate, maturityDate
    }

    private var filteredAssets: [Asset] {
        var result = store.assets
        if let status = filterStatus {
            result = result.filter { $0.status == status }
        }
        if !filterPlatform.isEmpty {
            result = result.filter { $0.platform == filterPlatform }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.platform.localizedCaseInsensitiveContains(searchText) ||
                $0.project.localizedCaseInsensitiveContains(searchText)
            }
        }
        let statusOrder: [AssetStatus: Int] = [.holding: 0, .redeemed: 1, .archived: 2]
        result.sort { a, b in
            let orderA = statusOrder[a.status] ?? 9
            let orderB = statusOrder[b.status] ?? 9
            if orderA != orderB { return orderA < orderB }
            let dateA: Date, dateB: Date
            switch sortField {
            case .purchaseDate: dateA = a.purchaseDate; dateB = b.purchaseDate
            case .maturityDate: dateA = a.maturityDate; dateB = b.maturityDate
            }
            return sortAscending ? dateA < dateB : dateA > dateB
        }
        return result
    }

    private var allPlatforms: [String] {
        Set(store.assets.map { $0.platform }).sorted()
    }

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private func isCurrentYear(_ date: Date) -> Bool {
        Calendar.current.component(.year, from: date) == currentYear
    }

    private var holdingAssets: [Asset] {
        filteredAssets.filter { $0.status == .holding }
    }

    private var amountByCurrency: [(currency: Currency, amount: Double)] {
        var dict: [Currency: Double] = [:]
        for asset in holdingAssets { dict[asset.currency, default: 0] += asset.amount }
        return dict.sorted { $0.value > $1.value }.map { (currency: $0.key, amount: $0.value) }
    }

    private var expectedReturnByCurrency: [(currency: Currency, amount: Double)] {
        var dict: [Currency: Double] = [:]
        for asset in holdingAssets where isCurrentYear(asset.maturityDate) {
            dict[asset.currency, default: 0] += asset.expectedReturn
        }
        return dict.sorted { $0.value > $1.value }.map { (currency: $0.key, amount: $0.value) }
    }

    private var actualReturnByCurrency: [(currency: Currency, amount: Double)] {
        var dict: [Currency: Double] = [:]
        for asset in filteredAssets where asset.status == .redeemed && isCurrentYear(asset.maturityDate) {
            dict[asset.currency, default: 0] += asset.actualReturn
        }
        return dict.sorted { $0.value > $1.value }.map { (currency: $0.key, amount: $0.value) }
    }

    private var weightedAvgExpectedRate: Double {
        let totalAmount = holdingAssets.reduce(0.0) { $0 + $1.amount }
        guard totalAmount > 0 else { return 0 }
        return holdingAssets.reduce(0.0) { $0 + $1.amount * $1.expectedReturnRate } / totalAmount
    }

    /// 本年度已赎回笔数
    private var redeemedCountThisYear: Int {
        filteredAssets.filter { $0.status == .redeemed && isCurrentYear($0.maturityDate) }.count
    }

    /// 是否有筛选条件生效
    private var hasActiveFilters: Bool {
        !searchText.isEmpty || filterStatus != nil || !filterPlatform.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            summaryBar
            Divider()
            toolBar
            Divider()
            if filteredAssets.isEmpty { emptyView } else { assetTable }
        }
        .sheet(isPresented: $showingAddSheet) {
            AssetFormView(mode: .add).environmentObject(store)
        }
        .sheet(item: $selectedAsset) { asset in
            AssetFormView(mode: .edit(asset)).environmentObject(store)
        }
        .sheet(item: $assetToRedeem) { asset in
            RedeemView(asset: asset).environmentObject(store)
        }
        .alert("确认归档", isPresented: $showArchiveAlert) {
            Button("取消", role: .cancel) { assetToArchive = nil }
            Button("归档") {
                if let asset = assetToArchive { store.archive(asset) }
                assetToArchive = nil
            }
        } message: {
            Text("归档后该资产将从活跃列表中淡化显示。确定归档？")
        }
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let asset = assetToDelete { withAnimation { store.delete(asset) } }
            }
        } message: {
            Text("确定要删除该资产记录吗？此操作不可恢复。")
        }
    }

    // MARK: - 统计概览
    private var summaryBar: some View {
        HStack(spacing: 28) {
            VStack(alignment: .leading, spacing: 4) {
                Text("持有资产总额").font(.caption).foregroundColor(.secondary)
                if amountByCurrency.isEmpty {
                    Text("0.00 元").font(.title3.bold()).foregroundColor(.blue)
                } else {
                    ForEach(amountByCurrency, id: \.currency) { item in
                        Text("\(item.currency.symbol)\(formatNumber(item.amount))")
                            .font(.title3.bold()).foregroundColor(.blue)
                    }
                }
            }
            Divider().frame(height: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text("本年度预期收益").font(.caption).foregroundColor(.secondary)
                if expectedReturnByCurrency.isEmpty {
                    Text("0.00 元").font(.callout.bold()).foregroundColor(.green)
                } else {
                    ForEach(expectedReturnByCurrency, id: \.currency) { item in
                        Text("\(item.currency.symbol)\(String(format: "%.2f", item.amount))")
                            .font(.callout.bold()).foregroundColor(.green)
                    }
                }
            }
            Divider().frame(height: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text("本年度实际收益").font(.caption).foregroundColor(.secondary)
                if actualReturnByCurrency.isEmpty {
                    Text("0.00 元").font(.callout.bold()).foregroundColor(.orange)
                } else {
                    ForEach(actualReturnByCurrency, id: \.currency) { item in
                        Text("\(item.currency.symbol)\(String(format: "%.2f", item.amount))")
                            .font(.callout.bold()).foregroundColor(.orange)
                    }
                }
            }
            Divider().frame(height: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text("加权平均收益率").font(.caption).foregroundColor(.secondary)
                Text(String(format: "%.2f%%", weightedAvgExpectedRate))
                    .font(.title3.bold()).foregroundColor(.cyan)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("持有/年度赎回").font(.caption).foregroundColor(.secondary)
                HStack(spacing: 4) {
                    Text("\(holdingAssets.count)").font(.title3.bold()).foregroundColor(.purple)
                    Text("/").font(.caption).foregroundColor(.secondary)
                    Text("\(redeemedCountThisYear)").font(.title3.bold()).foregroundColor(.orange)
                    Text("笔").font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func formatNumber(_ value: Double) -> String {
        abs(value) >= 10000 ? String(format: "%.2f 万", value / 10000) : String(format: "%.2f", value)
    }

    // MARK: - 工具栏
    private var toolBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("搜索平台或项目...", text: $searchText).textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(8).background(Color(nsColor: .textBackgroundColor)).cornerRadius(8)
            .frame(maxWidth: 280)

            Picker("平台", selection: $filterPlatform) {
                Text("全部平台").tag("")
                ForEach(allPlatforms, id: \.self) { Text($0).tag($0) }
            }.frame(width: 150)

            Picker("状态", selection: $filterStatus) {
                Text("全部状态").tag(AssetStatus?.none)
                ForEach(AssetStatus.allCases, id: \.self) { Text($0.rawValue).tag(AssetStatus?.some($0)) }
            }.frame(width: 120)

            HStack(spacing: 4) {
                Text("排序:").font(.caption).foregroundColor(.secondary)
                Picker("", selection: $sortField) {
                    Text("到期日期").tag(SortField.maturityDate)
                    Text("购买日期").tag(SortField.purchaseDate)
                }.labelsHidden().frame(width: 100)
                Button(action: { sortAscending.toggle() }) {
                    Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                }.buttonStyle(.bordered)
                .help(sortAscending ? "当前升序，点击切换降序" : "当前降序，点击切换升序")
            }

            Spacer()

            if hasActiveFilters {
                Button(action: {
                    searchText = ""
                    filterStatus = nil
                    filterPlatform = ""
                }) {
                    Label("重置", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
                .help("清除所有筛选条件")
            }

            Button(action: exportCSV) {
                Label("导出 CSV", systemImage: "square.and.arrow.up")
            }.buttonStyle(.bordered).disabled(filteredAssets.isEmpty)
            .help("将当前列表导出为 CSV 文件")
            .popover(isPresented: $showExportSuccess) { Text("✅ 导出成功").padding(12) }

            Button(action: { showingAddSheet = true }) {
                Label("添加资产", systemImage: "plus.circle.fill")
            }.buttonStyle(.borderedProminent).controlSize(.large)
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
    }

    // MARK: - 空状态
    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray").font(.system(size: 48)).foregroundColor(.secondary)
            Text("暂无资产记录").font(.title3).foregroundColor(.secondary)
            Text("点击下方按钮开始记录你的第一笔资产").font(.caption).foregroundColor(.secondary)
            Button(action: { showingAddSheet = true }) {
                Label("添加第一笔资产", systemImage: "plus.circle.fill")
            }.buttonStyle(.borderedProminent).controlSize(.large).padding(.top, 8)
            Spacer()
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 资产表格
    private var assetTable: some View {
        Table(filteredAssets) {
            TableColumn("状态") { asset in
                HStack(spacing: 4) {
                    statusBadge(asset.status)
                    if asset.status == .holding && asset.remainingDays <= 7 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2).foregroundColor(.red)
                            .help(asset.remainingDays == 0 ? "今日到期" : "即将到期")
                    }
                }.opacity(asset.status == .archived ? 0.5 : 1.0)
            }.width(min: 70, ideal: 85, max: 100)

            TableColumn("平台账户") { asset in
                Text(asset.platform).lineLimit(1).opacity(asset.status == .archived ? 0.5 : 1.0)
            }.width(min: 80, ideal: 110)

            TableColumn("项目") { asset in
                Text(asset.project).lineLimit(1).opacity(asset.status == .archived ? 0.5 : 1.0)
            }.width(min: 80, ideal: 130)

            TableColumn("金额") { asset in
                HStack(spacing: 4) {
                    Text(asset.currency.rawValue).font(.caption2)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Color.blue.opacity(0.1)).cornerRadius(3)
                    Text(String(format: "%.2f", asset.amount)).monospacedDigit()
                }.frame(maxWidth: .infinity, alignment: .trailing)
            }.width(min: 100, ideal: 130)

            TableColumn("预期(收益率/收益)") { asset in
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.2f%%", asset.expectedReturnRate)).font(.caption).foregroundColor(.blue)
                    Text("\(asset.currency.symbol)\(String(format: "%.2f", asset.expectedReturn))")
                        .font(.caption).foregroundColor(.green)
                }.monospacedDigit().frame(maxWidth: .infinity, alignment: .trailing)
            }.width(min: 100, ideal: 120)

            TableColumn("实际(收益率/收益)") { asset in
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.2f%%", asset.actualReturnRate)).font(.caption)
                        .foregroundColor(asset.actualReturnRate >= asset.expectedReturnRate ? .green : .orange)
                    Text("\(asset.currency.symbol)\(String(format: "%.2f", asset.actualReturn))")
                        .font(.caption).foregroundColor(.orange)
                }.monospacedDigit().frame(maxWidth: .infinity, alignment: .trailing)
            }.width(min: 100, ideal: 120)

            TableColumn("购买日期") { asset in
                Text(asset.purchaseDate.formatted(date: .abbreviated, time: .omitted))
            }.width(min: 80, ideal: 95)

            TableColumn("到期日期") { asset in
                VStack(alignment: .leading, spacing: 2) {
                    Text(asset.maturityDate.formatted(date: .abbreviated, time: .omitted))
                    if asset.status == .holding {
                        Text(asset.isExpired ? "已到期" : (asset.remainingDays == 0 ? "今日到期" : "剩余\(asset.remainingDays)天"))
                            .font(.caption2).foregroundColor(asset.isExpired || asset.remainingDays == 0 ? .red : .secondary)
                    }
                }
            }.width(min: 80, ideal: 95)

            TableColumn("操作") { asset in
                HStack(spacing: 8) {
                    Button(action: { selectedAsset = asset }) {
                        Image(systemName: "pencil.circle.fill").font(.system(size: 18)).foregroundColor(.blue)
                    }.buttonStyle(.plain).help("编辑")

                    if asset.status == .holding {
                        Button(action: { assetToRedeem = asset }) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundColor(.green)
                        }.buttonStyle(.plain).help("转为已赎回")
                    }

                    if asset.status == .redeemed {
                        Button(action: { assetToArchive = asset; showArchiveAlert = true }) {
                            Image(systemName: "archivebox.circle.fill").font(.system(size: 18)).foregroundColor(.purple)
                        }.buttonStyle(.plain).help("归档")
                    }

                    Button(action: { assetToDelete = asset; showingDeleteAlert = true }) {
                        Image(systemName: "trash.circle.fill").font(.system(size: 18)).foregroundColor(.red)
                    }.buttonStyle(.plain).help("删除")
                }
            }.width(min: 100, ideal: 130, max: 160)
        }
    }

    // MARK: - 状态标签
    private func statusBadge(_ status: AssetStatus) -> some View {
        let (bgColor, fgColor): (Color, Color) = {
            switch status {
            case .holding:  return (Color.green.opacity(0.15), .green)
            case .redeemed: return (Color.orange.opacity(0.15), .orange)
            case .archived: return (Color.gray.opacity(0.15), .secondary)
            }
        }()
        return Text(status.rawValue).font(.caption)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(bgColor).foregroundColor(fgColor).cornerRadius(6)
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    // MARK: - CSV 导出
    private func exportCSV() {
        let header = "状态,平台账户,项目,币种,金额,预期收益率(%),实际收益率(%),预期收益,实际收益,购买日期,到期日期,剩余天数"
        let df = Self.dateFormatter
        let rows = filteredAssets.map { a in
            [csvEscape(a.status.rawValue), csvEscape(a.platform), csvEscape(a.project),
             a.currency.rawValue, String(format: "%.2f", a.amount),
             String(format: "%.2f", a.expectedReturnRate), String(format: "%.2f", a.actualReturnRate),
             String(format: "%.2f", a.expectedReturn), String(format: "%.2f", a.actualReturn),
             df.string(from: a.purchaseDate), df.string(from: a.maturityDate), "\(a.remainingDays)"
            ].joined(separator: ",")
        }
        let csv = ([header] + rows).joined(separator: "\n")
        let panel = NSSavePanel()
        panel.title = "导出资产数据"
        panel.nameFieldStringValue = "资产数据_\(df.string(from: Date())).csv"
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try ("\u{FEFF}" + csv).write(to: url, atomically: true, encoding: .utf8)
                    DispatchQueue.main.async {
                        showExportSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showExportSuccess = false }
                    }
                } catch { print("导出失败: \(error)") }
            }
        }
    }
}

// MARK: - 赎回视图
struct RedeemView: View {
    @EnvironmentObject private var store: AssetStore
    @Environment(\.dismiss) private var dismiss

    let asset: Asset

    @State private var actualReturnText: String = ""
    @State private var maturityDate: Date = Date()
    @State private var showError = false
    @State private var errorMessage = ""

    private var holdingDays: Int {
        max(0, Calendar.current.dateComponents([.day], from: asset.purchaseDate, to: maturityDate).day ?? 0)
    }

    private var calculatedRate: Double? {
        guard let returnAmount = Double(actualReturnText), returnAmount >= 0,
              asset.amount > 0, holdingDays > 0 else { return nil }
        return returnAmount / asset.amount / Double(holdingDays) * 365.0 * 100.0
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("确认赎回").font(.title2.bold())
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill").font(.title3).foregroundColor(.secondary)
                }.buttonStyle(.plain)
            }.padding(20)

            Divider()

            VStack(spacing: 20) {
                // 资产信息摘要
                VStack(alignment: .leading, spacing: 12) {
                    Text("资产信息").font(.headline)
                    infoRow("平台账户", asset.platform)
                    infoRow("项目名称", asset.project)
                    infoRow("投资金额", "\(asset.currency.symbol)\(String(format: "%.2f", asset.amount))")
                    infoRow("预期收益率", String(format: "%.2f%%", asset.expectedReturnRate))
                    infoRow("预期收益", "\(asset.currency.symbol)\(String(format: "%.2f", asset.expectedReturn))")
                    infoRow("购买日期", asset.purchaseDate.formatted(date: .abbreviated, time: .omitted))
                }
                .padding(16)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(10)

                // 赎回信息
                VStack(alignment: .leading, spacing: 12) {
                    Text("赎回信息").font(.headline)

                    HStack(alignment: .center) {
                        Text("到期日期")
                            .frame(width: 110, alignment: .trailing)
                            .foregroundColor(.secondary)
                        DatePicker("", selection: $maturityDate, displayedComponents: .date)
                            .labelsHidden()
                    }

                    HStack {
                        Text("持有天数")
                            .frame(width: 110, alignment: .trailing)
                            .foregroundColor(.secondary)
                        Text("\(holdingDays) 天")
                            .foregroundColor(holdingDays > 0 ? .primary : .red)
                    }

                    HStack(alignment: .center) {
                        Text("实际收益（元）")
                            .frame(width: 110, alignment: .trailing)
                            .foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            Text(asset.currency.symbol).foregroundColor(.secondary).frame(width: 30)
                            TextField("预期: \(String(format: "%.2f", asset.expectedReturn))", text: $actualReturnText)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: actualReturnText) {
                                    if showError { showError = false }
                                }
                        }
                    }

                    if let rate = calculatedRate {
                        HStack {
                            Spacer()
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundColor(.orange).font(.caption)
                                Text("实际年化收益率: \(String(format: "%.4f%%", rate))")
                                    .font(.caption).foregroundColor(.orange)
                                let diff = rate - asset.expectedReturnRate
                                if abs(diff) > 0.001 {
                                    Text(diff > 0 ? "(↑\(String(format: "%.2f%%", diff)))" : "(↓\(String(format: "%.2f%%", abs(diff))))")
                                        .font(.caption2)
                                        .foregroundColor(diff > 0 ? .green : .red)
                                }
                            }
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.orange.opacity(0.08)).cornerRadius(6)
                        }
                    }
                }
                .padding(16)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(10)

                if showError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                        Text(errorMessage).foregroundColor(.red).font(.caption)
                        Spacer()
                    }
                }
            }
            .padding(20)

            Spacer()
            Divider()

            HStack {
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("确认赎回") { confirmRedeem() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent).tint(.orange)
            }.padding(20)
        }
        .frame(width: 480, height: 620)
        .onAppear { maturityDate = asset.maturityDate }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).frame(width: 90, alignment: .trailing).foregroundColor(.secondary).font(.callout)
            Text(value).font(.callout)
            Spacer()
        }
    }

    private func confirmRedeem() {
        guard let returnAmount = Double(actualReturnText), returnAmount >= 0 else {
            errorMessage = "请输入有效的实际收益金额"
            showError = true
            return
        }
        guard let rate = calculatedRate else {
            errorMessage = "无法计算收益率，请检查数据"
            showError = true
            return
        }
        store.redeem(asset, actualReturnRate: rate, maturityDate: maturityDate)
        dismiss()
    }
}