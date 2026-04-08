import Foundation

/// 资产数据存储管理器 - 使用 JSON 文件持久化
final class AssetStore: ObservableObject {
    @Published var assets: [Asset] = []
    @Published var platforms: [String] = []

    private let assetsFileURL: URL
    private let platformsFileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("AssetManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.assetsFileURL = dir.appendingPathComponent("assets.json")
        self.platformsFileURL = dir.appendingPathComponent("platforms.json")
        loadPlatforms()
        loadAssets()
    }

    // MARK: - 平台管理

    func addPlatform(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !platforms.contains(trimmed) else { return }
        platforms.append(trimmed)
        savePlatforms()
    }

    func deletePlatform(_ name: String) {
        platforms.removeAll { $0 == name }
        savePlatforms()
    }

    func deletePlatform(at offsets: IndexSet) {
        platforms.remove(atOffsets: offsets)
        savePlatforms()
    }

    // MARK: - 资产 CRUD

    func add(_ asset: Asset) {
        assets.append(asset)
        // 自动添加平台到列表
        if !platforms.contains(asset.platform) && !asset.platform.isEmpty {
            platforms.append(asset.platform)
            savePlatforms()
        }
        saveAssets()
    }

    func update(_ asset: Asset, platform: String, project: String, currency: Currency,
                amount: Double, expectedReturnRate: Double, actualReturnRate: Double,
                purchaseDate: Date, maturityDate: Date, status: AssetStatus) {
        objectWillChange.send()
        asset.platform = platform
        asset.project = project
        asset.currency = currency
        asset.amount = amount
        asset.expectedReturnRate = expectedReturnRate
        asset.actualReturnRate = actualReturnRate
        asset.purchaseDate = purchaseDate
        asset.maturityDate = maturityDate
        asset.status = status
        // 自动添加平台到列表
        if !platforms.contains(platform) && !platform.isEmpty {
            platforms.append(platform)
            savePlatforms()
        }
        saveAssets()
    }

    func delete(_ asset: Asset) {
        assets.removeAll { $0.id == asset.id }
        saveAssets()
    }

    func delete(at offsets: IndexSet) {
        assets.remove(atOffsets: offsets)
        saveAssets()
    }

    func redeem(_ asset: Asset, actualReturnRate: Double, maturityDate: Date) {
        objectWillChange.send()
        asset.actualReturnRate = actualReturnRate
        asset.maturityDate = maturityDate
        asset.status = .redeemed
        saveAssets()
    }

    func archive(_ asset: Asset) {
        objectWillChange.send()
        asset.status = .archived
        saveAssets()
    }

    // MARK: - 持久化

    private func saveAssets() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        do {
            let data = try encoder.encode(assets)
            try data.write(to: assetsFileURL, options: .atomic)
        } catch {
            print("保存资产失败: \(error)")
        }
    }

    private func loadAssets() {
        guard FileManager.default.fileExists(atPath: assetsFileURL.path) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let data = try Data(contentsOf: assetsFileURL)
            assets = try decoder.decode([Asset].self, from: data)
        } catch {
            print("加载资产失败: \(error)")
        }
    }

    private func savePlatforms() {
        do {
            let data = try JSONEncoder().encode(platforms)
            try data.write(to: platformsFileURL, options: .atomic)
        } catch {
            print("保存平台失败: \(error)")
        }
    }

    private func loadPlatforms() {
        guard FileManager.default.fileExists(atPath: platformsFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: platformsFileURL)
            platforms = try JSONDecoder().decode([String].self, from: data)
        } catch {
            print("加载平台失败: \(error)")
        }
    }
}