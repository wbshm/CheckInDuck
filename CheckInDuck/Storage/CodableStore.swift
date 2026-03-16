import Foundation

enum CodableStore {
    static func load<Value: Decodable>(
        key: String,
        defaults: KeyValueStoring,
        decoder: JSONDecoder = JSONDecoder()
    ) -> Value? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? decoder.decode(Value.self, from: data)
    }

    static func save<Value: Encodable>(
        value: Value,
        key: String,
        defaults: KeyValueStoring,
        encoder: JSONEncoder = JSONEncoder()
    ) {
        let data = try? encoder.encode(value)
        defaults.set(data, forKey: key)
    }
}
