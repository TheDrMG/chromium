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
