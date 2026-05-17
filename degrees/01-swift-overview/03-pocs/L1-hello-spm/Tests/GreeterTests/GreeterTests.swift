import Testing
@testable import Greeter

@Test("Greet a named person")
func greetNamed() {
    #expect(Greeter.greet(name: "world") == "Hello, world!")
}

@Test("Empty name falls back to 'stranger'")
func greetEmpty() {
    #expect(Greeter.greet(name: "") == "Hello, stranger!")
}

@Test("Whitespace in name is trimmed")
func greetTrimmed() {
    #expect(Greeter.greet(name: "  Alice  ") == "Hello, Alice!")
}

@Test("Multi-word names preserve internal spaces")
func greetMultiWord() {
    #expect(Greeter.greet(name: "Alice Cooper") == "Hello, Alice Cooper!")
}
