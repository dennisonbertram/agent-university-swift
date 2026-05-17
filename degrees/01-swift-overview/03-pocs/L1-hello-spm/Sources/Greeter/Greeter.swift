public enum Greeter {
    public static func greet(name: String) -> String {
        let trimmed = name.trimmingPrefix(while: \.isWhitespace)
            .reversed()
            .drop(while: \.isWhitespace)
            .reversed()
        let result = String(trimmed)
        if result.isEmpty {
            return "Hello, stranger!"
        }
        return "Hello, \(result)!"
    }
}
