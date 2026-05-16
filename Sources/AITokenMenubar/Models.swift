import Foundation

struct QuotaItem: Codable, Identifiable {
    var id: String { "\(platform)-\(period)" }
    let platform: String
    let period: String
    let quota: Double
    let currency: String
    let expire_at: String
    var usage: Double
    let platform_label: String

    var usagePercent: Double {
        guard quota > 0 else { return 0 }
        return min(usage / quota * 100, 100)
    }

    var remaining: Double {
        max(quota - usage, 0)
    }

    var statusColor: StatusColor {
        switch usagePercent {
        case 0..<70: return .normal
        case 70..<90: return .warning
        default:     return .critical
        }
    }

    enum StatusColor {
        case normal, warning, critical
    }
}

struct GetQuotaResponse: Codable {
    let data: [QuotaItem]
    let user: QuotaUser?
}

struct QuotaUser: Codable {
    let username: String
    let chinese_name: String
    let hr_org_id: String?
    let org_location_name: String?
}

struct GetMyProfileResponse: Codable {
    let staff_name: String
    let chinese_name: String
    let bg_short_name: String
    let dept_id: Int
    let dept_name: String
    let official_id: Int
}

struct QuotaUsageItem: Codable {
    let username: String
    let platform: String
    let period: String
    let usage: Double
    let currency: String
    let quota: Double
}

struct GetQuotaUsageResponse: Codable {
    let data: [QuotaUsageItem]
}
