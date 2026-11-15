import CVKEFridgeCore
import CVKEFridgeFeatures
import Foundation
import Testing
@testable import CVKEFridge

/// The texts with a count have one key with plural forms in the string catalog. The English text is the text of the
/// two keys that the app had before, for the count 1 and for each other count.
@MainActor
struct WordingPluralTests {
    @Test(.enabled(if: Locale.current.language.languageCode == .english))
    func theEnglishTextsHaveTheFormOfTheirCount() {
        #expect(Wording.itemCount(1) == "1 item")
        #expect(Wording.itemCount(12) == "12 items")
        #expect(Wording.itemCount(0) == "0 items")
        #expect(Wording.batchCount(1) == "1 batch")
        #expect(Wording.batchCount(3) == "3 batches")
        #expect(Wording.expiryDateCount(1) == "1 expiry date")
        #expect(Wording.expiryDateCount(2) == "2 expiry dates")

        #expect(Wording.text(KeepTime(count: 1, unit: .days)) == "About 1 day.")
        #expect(Wording.text(KeepTime(count: 3, unit: .days)) == "About 3 days.")
        #expect(Wording.text(KeepTime(count: 1, unit: .weeks)) == "About 1 week.")
        #expect(Wording.text(KeepTime(count: 2, unit: .weeks)) == "About 2 weeks.")
        #expect(Wording.text(KeepTime(count: 1, unit: .months)) == "About 1 month.")
        #expect(Wording.text(KeepTime(count: 6, unit: .months)) == "About 6 months.")
        #expect(Wording.text(KeepTime(count: 1, unit: .years)) == "About 1 year.")
        #expect(Wording.text(KeepTime(count: 2, unit: .years)) == "About 2 years.")

        #expect(NoticeText.changesNotRead(count: 1).text == "1 change in the inventory file can't be read. The other food is here.")
        #expect(NoticeText.changesNotRead(count: 4).text == "4 changes in the inventory file can't be read. The other food is here.")
        #expect(Wording.text(NoticeMessage.batchDeleted(name: "Milk", count: 1)) == "1 batch of Milk deleted")
        #expect(Wording.text(NoticeMessage.batchDeleted(name: "Milk", count: 2)) == "2 batches of Milk deleted")

        let one = ReminderMessage(count: 1, names: ["Milk"], moreNames: 0, lines: [], moreLines: 0)
        let three = ReminderMessage(count: 3, names: ["Milk"], moreNames: 2, lines: [], moreLines: 0)
        #expect(Wording.reminderTitle(one) == "1 item needs attention")
        #expect(Wording.reminderTitle(three) == "3 items need attention")
        #expect(Wording.reminderDaysLeft(.expiresInDays(1)) == "Expires in 1 day")
        #expect(Wording.reminderDaysLeft(.expiresInDays(5)) == "Expires in 5 days")
        #expect(Wording.reminderLead(days: 0) == "On the expiry date")
        #expect(Wording.reminderLead(days: 1) == "1 day before the expiry date")
        #expect(Wording.reminderLead(days: 3) == "3 days before the expiry date")

        let butter = Food(id: "butter", name: "Butter", subtitle: nil, category: .dairy, keywords: [], days: [.fridge: 30, .pantry: 1])
        #expect(Wording.estimateHint(food: butter, kind: .fridge) == "Estimate for Butter (Fridge): 30 days.")
        #expect(Wording.estimateHint(food: butter, kind: .pantry) == "Estimate for Butter (Pantry): 1 day.")
    }
}
