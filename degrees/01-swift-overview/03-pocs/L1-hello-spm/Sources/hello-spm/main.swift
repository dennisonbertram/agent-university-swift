import Greeter

let args = CommandLine.arguments
let name = args.count > 1 ? args[1] : ""
print(Greeter.greet(name: name))
