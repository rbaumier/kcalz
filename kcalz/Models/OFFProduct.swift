import GRDB

/// A product row from the local Open Food Facts SQLite database.
struct OFFProduct: Decodable, FetchableRecord, Identifiable, Sendable, Hashable {
    /// Barcode (EAN) used as unique identifier.
    var id: String { code }

    /// Mapped from OFF database column name
    let code: String
    /// Mapped from OFF database column name
    let name: String
    /// Mapped from OFF database column name
    let brands: String?
    /// Mapped from OFF database column name
    let categories: String?
    /// Mapped from OFF database column name
    let kcal: Double?
    /// Mapped from OFF database column name
    let proteins: Double?
    /// Mapped from OFF database column name
    let carbs: Double?
    /// Mapped from OFF database column name
    let fat: Double?
    /// Mapped from OFF database column name
    let sugars: Double?
    /// Mapped from OFF database column name
    let salt: Double?
    /// Mapped from OFF database column name
    let fiber: Double?
    /// Mapped from OFF database column name
    let nutriscore: String?
    /// Mapped from OFF database column name
    let quantity: String?
    /// Mapped from OFF database column name — net weight value.
    let product_quantity: Double?
    /// Mapped from OFF database column name — unit for product_quantity (g, ml, etc.).
    let product_quantity_unit: String?
    /// Mapped from OFF database column name — popularity proxy from OFF.
    let scans: Int?
}
