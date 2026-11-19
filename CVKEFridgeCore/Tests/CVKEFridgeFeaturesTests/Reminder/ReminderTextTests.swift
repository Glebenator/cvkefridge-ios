import CVKEFridgeFeatures
import Testing

/// The content of the reminder notification. The Android test `ReminderTextTest` has the same cases. It compares the
/// texts with the English words of Android (`EnglishReminder`), so each case also checks the values that make them.
struct ReminderTextTests {
    private func food(_ name: String, _ daysLeft: Int, estimated: Bool = false) -> ReminderFood {
        ReminderFood(productId: "id-\(name)", name: name, daysLeft: daysLeft, estimated: estimated)
    }

    private func english(_ foods: [ReminderFood]) throws -> EnglishReminder.Text {
        EnglishReminder.text(try #require(ReminderText.message(foods)))
    }

    @Test func noFoodsGiveNoReminder() {
        #expect(ReminderText.message([]) == nil)
    }

    @Test func oneFoodHasTheSingularTitle() throws {
        let message = try #require(ReminderText.message([food("Whole milk", 1)]))
        #expect(
            message == ReminderMessage(
                count: 1,
                names: ["Whole milk"],
                moreNames: 0,
                lines: [ReminderLine(productId: "id-Whole milk", name: "Whole milk", daysLeft: .expiresTomorrow, estimated: false)],
                moreLines: 0
            )
        )
        let text = EnglishReminder.text(message)
        #expect(text.title == "1 item needs attention")
        #expect(text.text == "Whole milk")
        #expect(text.lines == ["Expires tomorrow: Whole milk"])
    }

    @Test func eachLineSaysTheDaysLeftAndAnEstimate() throws {
        let foods = [food("Chicken thighs", -1, estimated: true), food("Baby spinach", 0), food("Milk", 1), food("Greek yoghurt", 2)]
        let message = try #require(ReminderText.message(foods))
        #expect(message.lines.map(\.daysLeft) == [.expiredYesterday, .expiresToday, .expiresTomorrow, .expiresInDays(2)])
        #expect(message.lines.map(\.estimated) == [true, false, false, false])
        let text = EnglishReminder.text(message)
        #expect(text.title == "4 items need attention")
        #expect(
            text.lines == [
                "Expired yesterday, estimated: Chicken thighs",
                "Expires today: Baby spinach",
                "Expires tomorrow: Milk",
                "Expires in 2 days: Greek yoghurt",
            ]
        )
        // The collapsed notification names two foods, and counts the others.
        #expect(message.names == ["Chicken thighs", "Baby spinach"])
        #expect(message.moreNames == 2)
        #expect(text.text == "Chicken thighs, Baby spinach and 2 more")
    }

    @Test func fiveFoodsHaveFiveLinesAndMoreFoodsHaveALastLineWithTheirNumber() throws {
        let five = (1...5).map { food("Food \($0)", 0) }
        #expect(try english(five).lines == (1...5).map { "Expires today: Food \($0)" })
        #expect(ReminderText.message(five)?.moreLines == 0)

        let seven = (1...7).map { food("Food \($0)", 0) }
        let message = try english(seven)
        #expect(message.title == "7 items need attention")
        #expect(message.lines == (1...4).map { "Expires today: Food \($0)" } + ["And 3 more"])
        #expect(message.text == "Food 1, Food 2 and 5 more")
        #expect(ReminderText.message(seven)?.lines.count == 4)
        #expect(ReminderText.message(seven)?.moreLines == 3)

        let six = (1...6).map { food("Food \($0)", 0) }
        #expect(try english(six).lines.last == "And 2 more")
        let two = (1...2).map { food("Food \($0)", 0) }
        #expect(try english(two).text == "Food 1, Food 2")
        let three = (1...3).map { food("Food \($0)", 0) }
        #expect(try english(three).text == "Food 1, Food 2 and 1 more")
    }

    @Test func aLongNameDoesNotHideTheDaysLeftOrTheNumberOfFoods() throws {
        let lasagne = "Leftover lasagne with roasted vegetables and béchamel sauce"
        let message = try english([food(lasagne, 2, estimated: true), food("Milk", 2), food("Eggs", 2)])
        // The days left are first in a line. The system can cut the end of the line, which is the name.
        #expect(message.lines.first == "Expires in 2 days, estimated: \(lasagne)")
        // The collapsed text cuts the name, so the number of the other foods stays.
        #expect(message.text == "Leftover lasagne with roast…, Milk and 1 more")
        // A name of the largest length stays as it is.
        let longest = String(repeating: "x", count: ReminderText.maxName)
        #expect(try english([food(longest, 0)]).text == longest)
    }

    // iOS: the cut counts characters, so it does not break an emoji (Android cuts UTF-16 units).
    @Test func theCutOfALongNameKeepsWholeCharacters() {
        let name = String(repeating: "a", count: 26) + "🧀🧀🧀"
        #expect(ReminderText.short(name) == String(repeating: "a", count: 26) + "🧀…")
    }
}
