import XCTest
@testable import UnitConverter

final class ConversionEngineTests: XCTestCase {
    private func value(_ input: Double, _ fromID: String, _ toID: String,
                       in category: UnitCategory) -> Double {
        let from = category.unit(withID: fromID)!
        let to = category.unit(withID: toID)!
        let results = Converter.convert(input, from: from, in: category, to: to.system)
        return results.first { $0.unit == to }!.value
    }

    func testLength() {
        XCTAssertEqual(value(1, "ft", "m", in: UnitCatalog.length), 0.3048, accuracy: 1e-9)
        XCTAssertEqual(value(1, "mi", "km", in: UnitCatalog.length), 1.609344, accuracy: 1e-9)
        XCTAssertEqual(value(100, "cm", "in", in: UnitCatalog.length), 39.3700787, accuracy: 1e-6)
    }

    func testMass() {
        XCTAssertEqual(value(1, "lb", "kg", in: UnitCatalog.mass), 0.45359237, accuracy: 1e-9)
        XCTAssertEqual(value(1, "st", "kg", in: UnitCatalog.mass), 6.35029318, accuracy: 1e-6)
    }

    func testVolume() {
        XCTAssertEqual(value(1, "gal", "l", in: UnitCatalog.volume), 3.785411784, accuracy: 1e-4)
        XCTAssertEqual(value(1, "impgal", "l", in: UnitCatalog.volume), 4.54609, accuracy: 1e-4)
    }

    func testTemperature() {
        XCTAssertEqual(value(212, "f", "c", in: UnitCatalog.temperature), 100, accuracy: 1e-9)
        XCTAssertEqual(value(-40, "c", "f", in: UnitCatalog.temperature), -40, accuracy: 1e-9)
    }

    func testFuelEconomyIsReciprocal() {
        XCTAssertEqual(value(30, "mpg", "l100km", in: UnitCatalog.fuel), 7.8404, accuracy: 1e-3)
    }

    func testCustomUnits() {
        XCTAssertEqual(value(1, "btu", "j", in: UnitCatalog.energy), 1055.056, accuracy: 1e-3)
        XCTAssertEqual(value(10, "fps", "mps", in: UnitCatalog.speed), 3.048, accuracy: 1e-9)
    }

    /// 1.5 tsp × 5 = 7.5 tsp = 2.5 tbsp.
    func testRecipeScalingExample() {
        let volume = UnitCatalog.volume
        let tsp = volume.unit(withID: "tsp")!, tbsp = volume.unit(withID: "tbsp")!
        let scaled = 1.5 * Converter.parseMultiplier("x5")!
        XCTAssertEqual(Converter.convert(scaled, from: tsp, to: tsp), 7.5, accuracy: 1e-12)
        XCTAssertEqual(Converter.convert(scaled, from: tsp, to: tbsp), 2.5, accuracy: 1e-12)
        XCTAssertEqual(Converter.format(Converter.convert(scaled, from: tsp, to: tbsp),
                                        locale: Locale(identifier: "en_US")), "2.5")
    }

    func testSameSystemConversionsAreExact() {
        let volume = UnitCatalog.volume, mass = UnitCatalog.mass
        XCTAssertEqual(value(3, "tsp", "tbsp", in: volume), 1, accuracy: 1e-12)
        XCTAssertEqual(value(16, "tbsp", "cup", in: volume), 1, accuracy: 1e-12)
        XCTAssertEqual(value(4, "qt", "gal", in: volume), 1, accuracy: 1e-12)
        XCTAssertEqual(value(16, "oz", "lb", in: mass), 1, accuracy: 1e-12)
        XCTAssertEqual(value(1500, "g", "kg", in: mass), 1.5, accuracy: 1e-12)
        XCTAssertEqual(value(250, "ml", "l", in: volume), 0.25, accuracy: 1e-12)
    }

    /// Weight <-> volume uses the density of water: 1 g = 1 mL.
    func testWeightVolumeAssumesWater() {
        let mass = UnitCatalog.mass, volume = UnitCatalog.volume
        func convert(_ v: Double, _ from: UnitOption, _ to: UnitOption) -> Double {
            Converter.convert(v, from: from, to: to)
        }
        let g = mass.unit(withID: "g")!, kg = mass.unit(withID: "kg")!, oz = mass.unit(withID: "oz")!
        let ml = volume.unit(withID: "ml")!, l = volume.unit(withID: "l")!
        let cup = volume.unit(withID: "cup")!, tbsp = volume.unit(withID: "tbsp")!

        XCTAssertEqual(convert(250, g, ml), 250, accuracy: 1e-9)
        XCTAssertEqual(convert(1, l, kg), 1, accuracy: 1e-12)
        XCTAssertEqual(convert(1, cup, g), 236.5882365, accuracy: 1e-6)
        XCTAssertEqual(convert(1, tbsp, g), 14.78676478, accuracy: 1e-6)
        XCTAssertEqual(convert(convert(3, oz, cup), cup, oz), 3, accuracy: 1e-9)
        XCTAssertTrue(Converter.isWeightVolumeConversion(from: g, to: cup))
        XCTAssertFalse(Converter.isWeightVolumeConversion(from: g, to: oz))

        XCTAssertEqual(UnitCatalog.targetCategories(for: mass).map(\.id), ["mass", "volume"])
        XCTAssertEqual(UnitCatalog.targetUnit(withID: "cup", from: mass)?.id, "cup")
        XCTAssertEqual(UnitCatalog.targetCategories(for: UnitCatalog.length).map(\.id), ["length"])
    }

    func testParseMultiplier() {
        let us = Locale(identifier: "en_US")
        XCTAssertEqual(Converter.parseMultiplier("5", locale: us), 5)
        XCTAssertEqual(Converter.parseMultiplier("×2.5", locale: us), 2.5)
        XCTAssertEqual(Converter.parseMultiplier("1/2", locale: us), 0.5)
        XCTAssertEqual(Converter.parseMultiplier("1 1/2", locale: us), 1.5)
        XCTAssertNil(Converter.parseMultiplier("0", locale: us))
        XCTAssertNil(Converter.parseMultiplier("-2", locale: us))
        XCTAssertNil(Converter.parseMultiplier("1/0", locale: us))
    }

    func testKitchenFraction() {
        XCTAssertEqual(Converter.kitchenFraction(2.5), "2 ½")
        XCTAssertEqual(Converter.kitchenFraction(0.75), "¾")
        XCTAssertEqual(Converter.kitchenFraction(1.0 / 3), "⅓")
        XCTAssertEqual(Converter.kitchenFraction(0.33), "≈ ⅓")
        XCTAssertNil(Converter.kitchenFraction(7))
        XCTAssertNil(Converter.kitchenFraction(1.42))
    }

    func testParse() {
        XCTAssertEqual(Converter.parse("1.5", locale: Locale(identifier: "en_US")), 1.5)
        XCTAssertEqual(Converter.parse("1,5", locale: Locale(identifier: "de_DE")), 1.5)
        XCTAssertEqual(Converter.parse("−3", locale: Locale(identifier: "en_US")), -3)
        XCTAssertNil(Converter.parse("abc"))
        XCTAssertNil(Converter.parse(""))
    }

    func testBestFit() {
        let category = UnitCatalog.length
        let results = Converter.convert(5, from: category.unit(withID: "mi")!, in: category, to: .metric)
        XCTAssertEqual(Converter.bestFit(results)?.unit.id, "km")
    }

    func testEveryCategoryHasBothSystems() {
        for category in UnitCatalog.all {
            XCTAssertFalse(category.units(in: .metric).isEmpty, category.name)
            XCTAssertFalse(category.units(in: .imperial).isEmpty, category.name)
            XCTAssertEqual(Set(category.units.map(\.id)).count, category.units.count, category.name)
        }
    }
}
