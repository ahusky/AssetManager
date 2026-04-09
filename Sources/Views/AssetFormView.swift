import SwiftUI

/// 表单模式
enum FormMode: Identifiable {
    case add
    case edit(Asset)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let asset): return asset.id.uuidString
        }
    }
}

/// 资产表单视图（新增 & 编辑）
struct AssetFormView: View {
    @EnvironmentObject private var store: AssetStore
    @Environment(\.dismiss) private var dismiss

    let mode: FormMode

    @State private var platform: String = ""
    @State private var isCustomPlatform: Bool = false
    @State private var project: String = ""
    @State private var currency: Currency = .cny
    @State private var amountText: String = ""
    @State private var expectedReturnRateText: String = ""
    @State private var actualReturnRateText: String = ""
    @State private var purchaseDate: Date = Date()
    @State private var maturityDate: Date = Date().addingTimeInterval(365 * 24 * 3600)
    @State private var status: AssetStatus = .holding
    @State private var showValidationError = false
    @State private var validationMessage = ""
    @State private var showPlatformManager = false

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var title: String {
        isEditing ? "编辑资产" : "添加资产"
    }

    /// 实时预估预期收益
    private var previewExpectedReturn: Double? {
        guard let amount = Double(amountText), amount > 0,
              let rate = Double(expectedReturnRateText), rate >= 0 else { return nil }
        let days = Calendar.current.dateComponents([.day], from: purchaseDate, to: maturityDate).day ?? 0
        guard days > 0 else { return nil }
        return amount * (rate / 100.0) * Double(days) / 365.0
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(title)
                    .font(.title2.bold())
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            // 表单内容
            ScrollView {
                VStack(spacing: 20) {
                    formSection("基本信息") {
                        formField("平台账户") {
                            HStack(spacing: 8) {
                                if store.platforms.isEmpty || isCustomPlatform {
                                    TextField("请输入平台账户名称", text: $platform)
                                        .textFieldStyle(.roundedBorder)
                                    if !store.platforms.isEmpty {
                                        Button(action: { isCustomPlatform = false; platform = "" }) {
                                            Image(systemName: "list.bullet")
                                                .foregroundColor(.blue)
                                        }
                                        .buttonStyle(.plain)
                                        .help("从列表选择")
                                    }
                                } else {
                                    Picker("", selection: $platform) {
                                        Text("请选择...").tag("")
                                        ForEach(store.platforms, id: \.self) { p in
                                            Text(p).tag(p)
                                        }
                                    }
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity)
                                    Button(action: { isCustomPlatform = true; platform = "" }) {
                                        Image(systemName: "pencil")
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(.plain)
                                    .help("手动输入")
                                }
                                Button(action: { showPlatformManager = true }) {
                                    Image(systemName: "gear")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                                .help("管理平台")
                            }
                        }
                        formField("项目名称") {
                            TextField("请输入项目名称", text: $project)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    formSection("财务信息") {
                        formField("币种") {
                            Picker("", selection: $currency) {
                                ForEach(Currency.allCases, id: \.self) { c in
                                    Text(c.displayName).tag(c)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                        }
                        formField("金额（元）") {
                            HStack(spacing: 4) {
                                Text(currency.symbol)
                                    .foregroundColor(.secondary)
                                    .frame(width: 30)
                                TextField("请输入金额", text: $amountText)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: amountText) { clearError() }
                            }
                        }
                        formField("预期收益率(%)") {
                            TextField("请输入预期年化收益率", text: $expectedReturnRateText)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: expectedReturnRateText) { clearError() }
                        }
                        formField("实际收益率(%)") {
                            TextField("请输入实际年化收益率", text: $actualReturnRateText)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: actualReturnRateText) { clearError() }
                        }

                        // 预期收益实时预览
                        if let preview = previewExpectedReturn {
                            let days = Calendar.current.dateComponents([.day], from: purchaseDate, to: maturityDate).day ?? 0
                            HStack {
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text("持有\(days)天 · 预期收益: \(currency.symbol)\(String(format: "%.2f", preview))")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.08))
                                .cornerRadius(6)
                            }
                        }
                    }

                    formSection("日期信息") {
                        formField("购买日期") {
                            DatePicker("", selection: $purchaseDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        formField("到期日期") {
                            DatePicker("", selection: $maturityDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                    }

                    formSection("资产状态") {
                        formField("状态") {
                            Picker("", selection: $status) {
                                ForEach(AssetStatus.allCases, id: \.self) { s in
                                    Text(s.rawValue).tag(s)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 280)
                        }
                    }

                    if showValidationError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(validationMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(20)
                .animation(.easeInOut(duration: 0.2), value: showValidationError)
            }

            Divider()

            // 底部按钮
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isEditing ? "保存修改" : "添加") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
        .frame(width: 520, height: 720)
        .onAppear(perform: loadData)
        .sheet(isPresented: $showPlatformManager) {
            PlatformManagerView()
                .environmentObject(store)
        }
    }

    // MARK: - 表单组件
    private func formSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            content()
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }

    private func formField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center) {
            Text(label)
                .frame(width: 110, alignment: .trailing)
                .foregroundColor(.secondary)
            content()
        }
    }

    // MARK: - 加载数据（编辑模式）
    private func loadData() {
        if case .edit(let asset) = mode {
            platform = asset.platform
            project = asset.project
            currency = asset.currency
            amountText = String(format: "%.2f", asset.amount)
            expectedReturnRateText = String(format: "%.2f", asset.expectedReturnRate)
            actualReturnRateText = String(format: "%.2f", asset.actualReturnRate)
            purchaseDate = asset.purchaseDate
            maturityDate = asset.maturityDate
            status = asset.status
            // 如果平台不在列表中，自动切换到手动输入模式
            if !store.platforms.contains(asset.platform) && !asset.platform.isEmpty {
                isCustomPlatform = true
            }
        }
    }

    // MARK: - 验证 & 保存
    private func save() {
        guard !platform.trimmingCharacters(in: .whitespaces).isEmpty else {
            showError("请选择或输入平台账户")
            return
        }
        guard !project.trimmingCharacters(in: .whitespaces).isEmpty else {
            showError("请输入项目名称")
            return
        }
        guard let amount = Double(amountText), amount > 0 else {
            showError("请输入有效的金额")
            return
        }
        guard let expectedRate = Double(expectedReturnRateText), expectedRate >= 0 else {
            showError("请输入有效的预期收益率")
            return
        }
        let actualRate = Double(actualReturnRateText) ?? 0
        guard maturityDate > purchaseDate else {
            showError("到期日期必须晚于购买日期")
            return
        }

        switch mode {
        case .add:
            let asset = Asset(
                platform: platform.trimmingCharacters(in: .whitespaces),
                project: project.trimmingCharacters(in: .whitespaces),
                currency: currency,
                amount: amount,
                expectedReturnRate: expectedRate,
                actualReturnRate: actualRate,
                purchaseDate: purchaseDate,
                maturityDate: maturityDate,
                status: status
            )
            store.add(asset)
        case .edit(let asset):
            store.update(asset,
                         platform: platform.trimmingCharacters(in: .whitespaces),
                         project: project.trimmingCharacters(in: .whitespaces),
                         currency: currency,
                         amount: amount,
                         expectedReturnRate: expectedRate,
                         actualReturnRate: actualRate,
                         purchaseDate: purchaseDate,
                         maturityDate: maturityDate,
                         status: status)
        }

        dismiss()
    }

    private func showError(_ message: String) {
        validationMessage = message
        showValidationError = true
    }

    private func clearError() {
        if showValidationError {
            showValidationError = false
        }
    }
}

// MARK: - 平台管理视图
struct PlatformManagerView: View {
    @EnvironmentObject private var store: AssetStore
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    @State private var platformToDelete: String? = nil
    @State private var showDeleteAlert = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("管理平台账户")
                    .font(.title3.bold())
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            // 添加新平台
            HStack(spacing: 8) {
                TextField("输入新平台名称", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addPlatform() }
                Button("添加") { addPlatform() }
                    .buttonStyle(.borderedProminent)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)

            Divider()

            // 平台列表
            if store.platforms.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text("暂无平台")
                        .foregroundColor(.secondary)
                    Text("添加平台后可在资产表单中快速选择")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(store.platforms, id: \.self) { platform in
                        HStack {
                            Text(platform)
                            Spacer()
                            let count = store.assets.filter { $0.platform == platform }.count
                            if count > 0 {
                                Text("\(count) 笔资产")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Button(action: {
                                let count = store.assets.filter { $0.platform == platform }.count
                                if count > 0 {
                                    platformToDelete = platform
                                    showDeleteAlert = true
                                } else {
                                    store.deletePlatform(platform)
                                }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .frame(width: 400, height: 400)
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { platformToDelete = nil }
            Button("删除", role: .destructive) {
                if let name = platformToDelete {
                    store.deletePlatform(name)
                    platformToDelete = nil
                }
            }
        } message: {
            if let name = platformToDelete {
                let count = store.assets.filter { $0.platform == name }.count
                Text("平台「\(name)」下有 \(count) 笔关联资产，删除后不影响已有资产数据，但新建资产时将无法选择此平台。确定删除？")
            }
        }
    }

    private func addPlatform() {
        store.addPlatform(newName)
        newName = ""
    }
}