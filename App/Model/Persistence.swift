import Foundation
import SwiftData

/// خطّة الترحيل. فارغة الآن؛ وكل إصدار بعد الإطلاق يُضاف إليها بمرحلة تحفظ القديم (4.3).
enum WirdMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum Persistence {
    static var schema: Schema { Schema(versionedSchema: SchemaV1.self) }

    /// مخزن التطبيق. يُزامَن مع حاوية iCloud الخاصة في بناء iCloud وحده (`Cloud`)، دون تغيير البنية (4.4).
    /// ومخازن الاختبار (في الذاكرة أو بمسار) لا تُزامَن أبداً.
    static func makeContainer(url: URL? = nil, inMemory: Bool = false) throws -> ModelContainer {
        let config: ModelConfiguration
        if inMemory {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else if let url {
            config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            config = ModelConfiguration(schema: schema, cloudKitDatabase: appDatabase)
        }
        return try ModelContainer(for: schema, migrationPlan: WirdMigrationPlan.self, configurations: [config])
    }

    /// قاعدة iCloud لمخزن التطبيق: الحاوية الخاصة في بناء iCloud، ولا شيء في غيره.
    static var appDatabase: ModelConfiguration.CloudKitDatabase {
        Cloud.isBuiltIn ? .private(Cloud.containerID) : .none
    }
}
