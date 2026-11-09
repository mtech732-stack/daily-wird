import Foundation
import SwiftData

/// خطّة الترحيل. فارغة الآن؛ وكل إصدار بعد الإطلاق يُضاف إليها بمرحلة تحفظ القديم (4.3).
enum WirdMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum Persistence {
    static var schema: Schema { Schema(versionedSchema: SchemaV1.self) }

    /// مخزن التطبيق على الجهاز. المزامنة مع iCloud تُفعَّل في ش7
    /// بتغيير `cloudKitDatabase` إلى `.automatic` وحده، دون تغيير البنية (4.4).
    static func makeContainer(url: URL? = nil, inMemory: Bool = false) throws -> ModelContainer {
        let config: ModelConfiguration
        if inMemory {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else if let url {
            config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, migrationPlan: WirdMigrationPlan.self, configurations: [config])
    }
}
