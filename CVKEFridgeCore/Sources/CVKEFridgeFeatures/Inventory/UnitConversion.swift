import Foundation

// The conversion of the quantities of a product when its unit changes. The Android app has no such file: a change of
// the unit there keeps the numbers, so 500 g becomes 500 kg (defect 3 in `docs/android-parity-plan.md`).

/// What a change of the unit of a product does to the quantities of its batches.
public enum UnitChange: Hashable, Sendable {
    /// The unit stays, or there is no quantity to change.
    case unchanged
    /// The quantities change to the new unit: g and kg, or ml and l. 500 g becomes 0.5 kg.
    case converts
    /// The two units have no fixed relation, so the numbers stay: 500 g becomes 500 pcs. Ask the person first.
    case keepsNumbers
}

/// Converts quantities between g and kg, and between ml and l. A quantity is in thousandths.
public enum UnitConversion {
    /// The change of the quantities for a change of the unit from `old` to `new`.
    public static func change(from old: MeasureUnit?, to new: MeasureUnit?) -> UnitChange {
        if old == new {
            return .unchanged
        }
        return factor(from: old, to: new) != nil ? .converts : .keepsNumbers
    }

    /// The quantity in the new unit, in thousandths, or nil when the two units have no fixed relation. The result is
    /// exact when it is a whole number of thousandths, for example each whole number of grams in kg. A smaller part
    /// goes to the nearest thousandth, a half up, and the result is never less than 1 thousandth.
    public static func convert(_ thousandths: Int, from old: MeasureUnit?, to new: MeasureUnit?) -> Int? {
        if old == new {
            return thousandths
        }
        guard let factor = factor(from: old, to: new) else {
            return nil
        }
        if factor > 0 {
            let (result, overflow) = thousandths.multipliedReportingOverflow(by: factor)
            return overflow ? nil : result
        }
        let divisor = -factor
        let rounded = (thousandths + divisor / 2) / divisor
        return thousandths > 0 ? max(rounded, 1) : rounded
    }

    /// The factor from `old` to `new`: a positive number multiplies, and a negative number divides by its size. Nil
    /// when the two units have no fixed relation.
    private static func factor(from old: MeasureUnit?, to new: MeasureUnit?) -> Int? {
        switch (old, new) {
        case (.g?, .kg?), (.ml?, .l?):
            return -1000
        case (.kg?, .g?), (.l?, .ml?):
            return 1000
        default:
            return nil
        }
    }
}
