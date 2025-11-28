// Generated using Sourcery 2.3.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
// Generated using Sourcery
// DO NOT EDIT

// MARK: - Person AutoEquatable
extension Person: Equatable {
    static func == (lhs: Person, rhs: Person) -> Bool {
        guard lhs.name == rhs.name else { return false }
        guard lhs.age == rhs.age else { return false }
        guard lhs.email == rhs.email else { return false }
        return true
    }
}
