import Foundation

/// 资产状态枚举
enum AssetStatus: String, Codable, CaseIterable {
    case holding = "已持有"
    case redeemed = "已赎回"
    case archived = "已归档"
}

/// 币种枚举
enum Currency: String, Codable, CaseIterable {
    case cny = "CNY"
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case jpy = "JPY"
    case hkd = "HKD"

    var symbol: String {
        switch self {
        case .cny: return "¥"
        case .usd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .jpy: return "¥"
        case .hkd: return "HK$"
        }
    }

    var displayName: String {
        switch self {
        case .cny: return "人民币 (CNY)"
        case .usd: return "美元 (USD)"
        case .eur: return "欧元 (EUR)"
        case .gbp: return "英镑 (GBP)"
        case .jpy: return "日元 (JPY)"
        case .hkd: return "港币 (HKD)"
        }
    }
}

/// 资产数据模型
final class Asset: Identifiable, Codable, ObservableObject {
    let id: UUID
    @Published var platform: String            // 平台账户
    @Published var project: String             // 项目
    @Published var currency: Currency          // 币种
    @Published var amount: Double              // 金额
    @Published var expectedReturnRate: Double  // 预期收益率（%）
    @Published var actualReturnRate: Double    // 实际收益率（%）
    @Published var purchaseDate: Date          // 购买日期
    @Published var maturityDate: Date          // 到期日期
    @Published var status: AssetStatus         // 资产状态

    /// 预期收益
    var expectedReturn: Double {
        let days = max(0, Calendar.current.dateComponents([.day], from: purchaseDate, to: maturityDate).day ?? 0)
        return amount * (expectedReturnRate / 100.0) * Double(days) / 365.0
    }

    /// 实际收益
    var actualReturn: Double {
        let endDate: Date
        switch status {
        case .redeemed, .archived:
            endDate = maturityDate
        case .holding:
            endDate = Date()
        }
        let days = Calendar.current.dateComponents([.day], from: purchaseDate, to: endDate).day ?? 0
        return amount * (actualReturnRate / 100.0) * Double(days) / 365.0
    }

    /// 是否已过期
    var isExpired: Bool {
        maturityDate < Date()
    }

    /// 剩余天数
    var remainingDays: Int {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: maturityDate).day ?? 0
        return max(0, days)
    }

    init(
        id: UUID = UUID(),
        platform: String = "",
        project: String = "",
        currency: Currency = .cny,
        amount: Double = 0,
        expectedReturnRate: Double = 0,
        actualReturnRate: Double = 0,
        purchaseDate: Date = Date(),
        maturityDate: Date = Date().addingTimeInterval(365 * 24 * 3600),
        status: AssetStatus = .holding
    ) {
        self.id = id
        self.platform = platform
        self.project = project
        self.currency = currency
        self.amount = amount
        self.expectedReturnRate = expectedReturnRate
        self.actualReturnRate = actualReturnRate
        self.purchaseDate = purchaseDate
        self.maturityDate = maturityDate
        self.status = status
    }

    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case id, platform, project, currency, amount, expectedReturnRate, actualReturnRate, purchaseDate, maturityDate, status
        // 旧字段兼容
        case returnRate
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        platform = try c.decode(String.self, forKey: .platform)
        project = try c.decode(String.self, forKey: .project)
        currency = try c.decodeIfPresent(Currency.self, forKey: .currency) ?? .cny
        amount = try c.decode(Double.self, forKey: .amount)
        // 兼容旧数据：如果有 returnRate 则同时赋给预期和实际
        if let oldRate = try? c.decode(Double.self, forKey: .returnRate) {
            expectedReturnRate = oldRate
            actualReturnRate = oldRate
        } else {
            expectedReturnRate = try c.decodeIfPresent(Double.self, forKey: .expectedReturnRate) ?? 0
            actualReturnRate = try c.decodeIfPresent(Double.self, forKey: .actualReturnRate) ?? 0
        }
        purchaseDate = try c.decode(Date.self, forKey: .purchaseDate)
        maturityDate = try c.decode(Date.self, forKey: .maturityDate)
        status = try c.decode(AssetStatus.self, forKey: .status)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(platform, forKey: .platform)
        try c.encode(project, forKey: .project)
        try c.encode(currency, forKey: .currency)
        try c.encode(amount, forKey: .amount)
        try c.encode(expectedReturnRate, forKey: .expectedReturnRate)
        try c.encode(actualReturnRate, forKey: .actualReturnRate)
        try c.encode(purchaseDate, forKey: .purchaseDate)
        try c.encode(maturityDate, forKey: .maturityDate)
        try c.encode(status, forKey: .status)
    }
}