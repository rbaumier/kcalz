import GRDB

struct OFFProduct: Decodable, FetchableRecord, Identifiable, Sendable, Hashable {
    var id: String { code }

    let code: String
    let name: String
    let brands: String?
    let categories: String?
    let kcal: Double?
    let proteins: Double?
    let carbs: Double?
    let fat: Double?
    let sugars: Double?
    let salt: Double?
    let fiber: Double?
    let nutriscore: String?
    let quantity: String?
    let product_quantity: Double?
    let product_quantity_unit: String?
    let scans: Int?

    static func == (lhs: OFFProduct, rhs: OFFProduct) -> Bool {
        lhs.code == rhs.code
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(code)
    }
}
