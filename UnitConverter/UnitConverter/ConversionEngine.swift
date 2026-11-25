import Foundation

/// The two families of units the app converts between.
enum MeasurementSystem: String, CaseIterable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }

    var title: String {
        switch self {
        case .metric: return "Metric"
        case .imperial: return "Imperial / US"
        }
    }

    var opposite: MeasurementSystem {
        self == .metric ? .imperial : .metric
    }
}

/// One selectable unit, e.g. "Feet (ft)".
struct UnitOption: Identifiable, Hashable {
    let id: String
    let name: String
    let unit: Dimension
    let system: MeasurementSystem

    var symbol: String { unit.symbol }

    static func == (lhs: UnitOption, rhs: UnitOption) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// A kind of quantity (length, mass, ...) and the units that measure it.
struct UnitCategory: Identifiable, Hashable {
    let id: String
    let name: String
    let systemImage: String
    let units: [UnitOption]

    func units(in system: MeasurementSystem) -> [UnitOption] {
        units.filter { $0.system == system }
    }

    func unit(withID id: String) -> UnitOption? {
        units.first { $0.id == id }
    }

    static func == (lhs: UnitCategory, rhs: UnitCategory) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// A single converted value.
struct ConversionResult: Identifiable {
    let unit: UnitOption
    let value: Double
    var id: String { unit.id }
}

// MARK: - Exact Imperial / US units
//
// Foundation's built-in Imperial units use rounded factors (e.g. a tablespoon is
// not exactly 3 teaspoons and 16 oz is 0.999998 lb), which shows up as results
// like "2.49999 tbsp". These use the exact legal definitions instead.

enum ExactUnits {
    // Volume — UnitVolume's base unit is the liter.
    static let usFluidOunceL = 0.0295735295625
    static let teaspoons = UnitVolume(symbol: "tsp", converter: UnitConverterLinear(coefficient: usFluidOunceL / 6))
    static let tablespoons = UnitVolume(symbol: "tbsp", converter: UnitConverterLinear(coefficient: usFluidOunceL / 2))
    static let fluidOunces = UnitVolume(symbol: "fl oz", converter: UnitConverterLinear(coefficient: usFluidOunceL))
    static let cups = UnitVolume(symbol: "cup", converter: UnitConverterLinear(coefficient: usFluidOunceL * 8))
    static let pints = UnitVolume(symbol: "pt", converter: UnitConverterLinear(coefficient: usFluidOunceL * 16))
    static let quarts = UnitVolume(symbol: "qt", converter: UnitConverterLinear(coefficient: usFluidOunceL * 32))
    static let gallons = UnitVolume(symbol: "gal", converter: UnitConverterLinear(coefficient: usFluidOunceL * 128))
    static let imperialFluidOunceL = 0.0284130625
    static let imperialFluidOunces = UnitVolume(symbol: "UK fl oz", converter: UnitConverterLinear(coefficient: imperialFluidOunceL))
    static let imperialPints = UnitVolume(symbol: "UK pt", converter: UnitConverterLinear(coefficient: imperialFluidOunceL * 20))
    static let imperialGallons = UnitVolume(symbol: "UK gal", converter: UnitConverterLinear(coefficient: imperialFluidOunceL * 160))
    static let cubicInches = UnitVolume(symbol: "in³", converter: UnitConverterLinear(coefficient: 0.016387064))
    static let cubicFeet = UnitVolume(symbol: "ft³", converter: UnitConverterLinear(coefficient: 28.316846592))

    // Mass — UnitMass's base unit is the kilogram.
    static let poundKg = 0.45359237
    static let ounces = UnitMass(symbol: "oz", converter: UnitConverterLinear(coefficient: poundKg / 16))
    static let pounds = UnitMass(symbol: "lb", converter: UnitConverterLinear(coefficient: poundKg))
    static let stones = UnitMass(symbol: "st", converter: UnitConverterLinear(coefficient: poundKg * 14))
    static let shortTons = UnitMass(symbol: "ton", converter: UnitConverterLinear(coefficient: poundKg * 2000))
    static let longTons = UnitMass(symbol: "long ton", converter: UnitConverterLinear(coefficient: poundKg * 2240))

    // Length — UnitLength's base unit is the meter.
    static let miles = UnitLength(symbol: "mi", converter: UnitConverterLinear(coefficient: 1609.344))

    // Area — UnitArea's base unit is the square meter.
    static let squareInches = UnitArea(symbol: "in²", converter: UnitConverterLinear(coefficient: 0.00064516))
    static let squareFeet = UnitArea(symbol: "ft²", converter: UnitConverterLinear(coefficient: 0.09290304))
    static let squareYards = UnitArea(symbol: "yd²", converter: UnitConverterLinear(coefficient: 0.83612736))
    static let acres = UnitArea(symbol: "ac", converter: UnitConverterLinear(coefficient: 4046.8564224))
    static let squareMiles = UnitArea(symbol: "mi²", converter: UnitConverterLinear(coefficient: 2_589_988.110336))
}

// MARK: - Custom units Foundation doesn't provide

extension UnitSpeed {
    static let feetPerSecond = UnitSpeed(symbol: "ft/s", converter: UnitConverterLinear(coefficient: 0.3048))
}

extension UnitEnergy {
    static let britishThermalUnits = UnitEnergy(symbol: "BTU", converter: UnitConverterLinear(coefficient: 1055.05585262))
    static let footPounds = UnitEnergy(symbol: "ft·lbf", converter: UnitConverterLinear(coefficient: 1.3558179483314004))
}

extension UnitPower {
    static let btuPerHour = UnitPower(symbol: "BTU/h", converter: UnitConverterLinear(coefficient: 0.29307107))
}

// MARK: - Catalogue

enum UnitCatalog {
    private static func m(_ id: String, _ name: String, _ unit: Dimension) -> UnitOption {
        UnitOption(id: id, name: name, unit: unit, system: .metric)
    }

    private static func i(_ id: String, _ name: String, _ unit: Dimension) -> UnitOption {
        UnitOption(id: id, name: name, unit: unit, system: .imperial)
    }

    static let length = UnitCategory(id: "length", name: "Length", systemImage: "ruler", units: [
        m("mm", "Millimeters", UnitLength.millimeters),
        m("cm", "Centimeters", UnitLength.centimeters),
        m("m", "Meters", UnitLength.meters),
        m("km", "Kilometers", UnitLength.kilometers),
        i("in", "Inches", UnitLength.inches),
        i("ft", "Feet", UnitLength.feet),
        i("yd", "Yards", UnitLength.yards),
        i("mi", "Miles", ExactUnits.miles),
        i("nmi", "Nautical miles", UnitLength.nauticalMiles),
    ])

    static let mass = UnitCategory(id: "mass", name: "Weight", systemImage: "scalemass", units: [
        m("mg", "Milligrams", UnitMass.milligrams),
        m("g", "Grams", UnitMass.grams),
        m("kg", "Kilograms", UnitMass.kilograms),
        m("t", "Metric tons", UnitMass.metricTons),
        i("oz", "Ounces", ExactUnits.ounces),
        i("lb", "Pounds", ExactUnits.pounds),
        i("st", "Stone", ExactUnits.stones),
        i("ton", "US tons (short)", ExactUnits.shortTons),
        i("lton", "Imperial tons (long)", ExactUnits.longTons),
    ])

    static let volume = UnitCategory(id: "volume", name: "Volume", systemImage: "drop", units: [
        m("ml", "Milliliters", UnitVolume.milliliters),
        m("l", "Liters", UnitVolume.liters),
        m("cm3", "Cubic centimeters", UnitVolume.cubicCentimeters),
        m("m3", "Cubic meters", UnitVolume.cubicMeters),
        i("tsp", "Teaspoons (US)", ExactUnits.teaspoons),
        i("tbsp", "Tablespoons (US)", ExactUnits.tablespoons),
        i("floz", "Fluid ounces (US)", ExactUnits.fluidOunces),
        i("cup", "Cups (US)", ExactUnits.cups),
        i("pt", "Pints (US)", ExactUnits.pints),
        i("qt", "Quarts (US)", ExactUnits.quarts),
        i("gal", "Gallons (US)", ExactUnits.gallons),
        i("impfloz", "Fluid ounces (UK)", ExactUnits.imperialFluidOunces),
        i("imppt", "Pints (UK)", ExactUnits.imperialPints),
        i("impgal", "Gallons (UK)", ExactUnits.imperialGallons),
        i("in3", "Cubic inches", ExactUnits.cubicInches),
        i("ft3", "Cubic feet", ExactUnits.cubicFeet),
    ])

    static let temperature = UnitCategory(id: "temperature", name: "Temperature", systemImage: "thermometer.medium", units: [
        m("c", "Celsius", UnitTemperature.celsius),
        m("k", "Kelvin", UnitTemperature.kelvin),
        i("f", "Fahrenheit", UnitTemperature.fahrenheit),
    ])

    static let area = UnitCategory(id: "area", name: "Area", systemImage: "square.dashed", units: [
        m("cm2", "Square centimeters", UnitArea.squareCentimeters),
        m("m2", "Square meters", UnitArea.squareMeters),
        m("ha", "Hectares", UnitArea.hectares),
        m("km2", "Square kilometers", UnitArea.squareKilometers),
        i("in2", "Square inches", ExactUnits.squareInches),
        i("ft2", "Square feet", ExactUnits.squareFeet),
        i("yd2", "Square yards", ExactUnits.squareYards),
        i("ac", "Acres", ExactUnits.acres),
        i("mi2", "Square miles", ExactUnits.squareMiles),
    ])

    static let speed = UnitCategory(id: "speed", name: "Speed", systemImage: "speedometer", units: [
        m("mps", "Meters per second", UnitSpeed.metersPerSecond),
        m("kph", "Kilometers per hour", UnitSpeed.kilometersPerHour),
        i("mph", "Miles per hour", UnitSpeed.milesPerHour),
        i("fps", "Feet per second", UnitSpeed.feetPerSecond),
        i("kn", "Knots", UnitSpeed.knots),
    ])

    static let fuel = UnitCategory(id: "fuel", name: "Fuel Economy", systemImage: "fuelpump", units: [
        m("l100km", "Liters per 100 km", UnitFuelEfficiency.litersPer100Kilometers),
        i("mpg", "Miles per gallon (US)", UnitFuelEfficiency.milesPerGallon),
        i("mpgimp", "Miles per gallon (UK)", UnitFuelEfficiency.milesPerImperialGallon),
    ])

    static let pressure = UnitCategory(id: "pressure", name: "Pressure", systemImage: "gauge.with.dots.needle.33percent", units: [
        m("kpa", "Kilopascals", UnitPressure.kilopascals),
        m("hpa", "Hectopascals", UnitPressure.hectopascals),
        m("bar", "Bar", UnitPressure.bars),
        i("psi", "Pounds per sq. inch", UnitPressure.poundsForcePerSquareInch),
        i("inhg", "Inches of mercury", UnitPressure.inchesOfMercury),
    ])

    static let energy = UnitCategory(id: "energy", name: "Energy", systemImage: "bolt", units: [
        m("j", "Joules", UnitEnergy.joules),
        m("kj", "Kilojoules", UnitEnergy.kilojoules),
        m("kcal", "Kilocalories", UnitEnergy.kilocalories),
        m("kwh", "Kilowatt-hours", UnitEnergy.kilowattHours),
        i("btu", "British thermal units", UnitEnergy.britishThermalUnits),
        i("ftlb", "Foot-pounds", UnitEnergy.footPounds),
    ])

    static let power = UnitCategory(id: "power", name: "Power", systemImage: "powerplug", units: [
        m("w", "Watts", UnitPower.watts),
        m("kw", "Kilowatts", UnitPower.kilowatts),
        i("hp", "Horsepower", UnitPower.horsepower),
        i("btuh", "BTU per hour", UnitPower.btuPerHour),
    ])

    static let all: [UnitCategory] = [
        length, mass, volume, temperature, area, speed, fuel, pressure, energy, power,
    ]

    static func category(withID id: String) -> UnitCategory? {
        all.first { $0.id == id }
    }

    /// Categories a unit can be converted into from `category`. Weight and volume
    /// are linked so you can go from one to the other (assuming water density).
    static func targetCategories(for category: UnitCategory) -> [UnitCategory] {
        switch category.id {
        case mass.id: return [mass, volume]
        case volume.id: return [volume, mass]
        default: return [category]
        }
    }

    /// Looks up a unit by ID among the categories reachable from `category`.
    static func targetUnit(withID id: String, from category: UnitCategory) -> UnitOption? {
        for candidate in targetCategories(for: category) {
            if let unit = candidate.unit(withID: id) { return unit }
        }
        return nil
    }
}

// MARK: - Ingredients (for weight <-> volume)

/// A common ingredient and its accepted weight per US cup, used to convert
/// between weight and volume. Values are the standard kitchen/baking figures
/// (spooned & leveled for flours, packed for brown sugar).
struct Ingredient: Identifiable, Hashable {
    let id: String
    let name: String
    let gramsPerCup: Double

    /// Kilograms per liter (equivalently grams per milliliter).
    var density: Double { gramsPerCup / (ExactUnits.usFluidOunceL * 8 * 1000) }

    static let water = Ingredient(id: "water", name: "Water", gramsPerCup: 236.5882365)
}

/// The quick choice used for weight <-> volume: a generic material type,
/// or a specific ingredient from `IngredientCatalog`.
enum MaterialType: String, CaseIterable, Identifiable {
    case liquid, powder, solid, ingredient

    var id: String { rawValue }

    var title: String {
        switch self {
        case .liquid: return "Liquid"
        case .powder: return "Powder"
        case .solid: return "Solid"
        case .ingredient: return "Ingredient"
        }
    }

    /// Typical examples, shown as a hint.
    var examples: String {
        switch self {
        case .liquid: return "Water, milk, juice, broth"
        case .powder: return "Flour, powdered sugar, spices"
        case .solid: return "Butter, shortening, cream cheese"
        case .ingredient: return "Pick a specific ingredient"
        }
    }

    /// Standard density for the generic types; nil for `.ingredient`.
    var standardIngredient: Ingredient? {
        switch self {
        case .liquid: return Ingredient(id: "liquid", name: "Liquid", gramsPerCup: Ingredient.water.gramsPerCup)
        case .powder: return Ingredient(id: "powder", name: "Powder", gramsPerCup: 125)
        case .solid: return Ingredient(id: "solid", name: "Solid", gramsPerCup: 227)
        case .ingredient: return nil
        }
    }

    /// The ingredient to convert with, given the specific-ingredient selection.
    func resolve(ingredientID: String) -> Ingredient {
        standardIngredient ?? IngredientCatalog.ingredient(withID: ingredientID)
    }
}

struct IngredientGroup: Identifiable {
    let name: String
    let items: [Ingredient]
    var id: String { name }
}

enum IngredientCatalog {
    private static func item(_ id: String, _ name: String, _ grams: Double) -> Ingredient {
        Ingredient(id: id, name: name, gramsPerCup: grams)
    }

    static let groups: [IngredientGroup] = [
        IngredientGroup(name: "Liquids", items: [
            .water,
            item("milk", "Milk", 242),
            item("cream", "Heavy cream", 238),
            item("buttermilk", "Buttermilk", 245),
            item("oil", "Vegetable oil", 218),
            item("honey", "Honey", 340),
            item("maple", "Maple syrup", 315),
            item("molasses", "Molasses", 337),
        ]),
        IngredientGroup(name: "Flours & starches", items: [
            item("apflour", "All-purpose flour", 120),
            item("breadflour", "Bread flour", 120),
            item("cakeflour", "Cake flour", 114),
            item("wwflour", "Whole wheat flour", 113),
            item("cornmeal", "Cornmeal", 138),
            item("cornstarch", "Cornstarch", 112),
            item("cocoa", "Cocoa powder", 84),
        ]),
        IngredientGroup(name: "Sugars", items: [
            item("sugar", "Granulated sugar", 200),
            item("brownsugar", "Brown sugar (packed)", 213),
            item("powderedsugar", "Powdered sugar", 120),
        ]),
        IngredientGroup(name: "Fats & dairy", items: [
            item("butter", "Butter", 227),
            item("shortening", "Shortening", 190),
            item("peanutbutter", "Peanut butter", 270),
            item("yogurt", "Yogurt", 245),
            item("sourcream", "Sour cream", 230),
            item("parmesan", "Parmesan (grated)", 100),
            item("cheddar", "Cheddar (shredded)", 113),
        ]),
        IngredientGroup(name: "Grains, nuts & more", items: [
            item("oats", "Rolled oats", 90),
            item("rice", "White rice (uncooked)", 185),
            item("chocchips", "Chocolate chips", 170),
            item("nuts", "Chopped nuts", 120),
            item("raisins", "Raisins", 145),
        ]),
        IngredientGroup(name: "Leaveners & salt", items: [
            item("salt", "Table salt", 288),
            item("kosher", "Kosher salt (Morton)", 230),
            item("bakingsoda", "Baking soda", 288),
            item("bakingpowder", "Baking powder", 192),
            item("yeast", "Instant yeast", 150),
        ]),
    ]

    static let all: [Ingredient] = groups.flatMap { $0.items }

    static func ingredient(withID id: String) -> Ingredient {
        all.first { $0.id == id } ?? .water
    }
}

// MARK: - Conversion

enum Converter {
    /// True when converting between `from` and `to` goes from weight to volume or back.
    static func isWeightVolumeConversion(from: UnitOption, to: UnitOption) -> Bool {
        (from.unit is UnitMass && to.unit is UnitVolume) || (from.unit is UnitVolume && to.unit is UnitMass)
    }

    /// Converts `value` in `from` into a single unit `to`. Units must share a
    /// dimension, except weight <-> volume, which uses `ingredient`'s density
    /// (water by default: 1 g = 1 mL).
    static func convert(_ value: Double, from: UnitOption, to: UnitOption,
                        ingredient: Ingredient = .water) -> Double {
        let source = Measurement(value: value, unit: from.unit)
        if from.unit is UnitMass, to.unit is UnitVolume {
            let liters = source.converted(to: UnitMass.kilograms).value / ingredient.density
            return Measurement(value: liters, unit: UnitVolume.liters).converted(to: to.unit).value
        }
        if from.unit is UnitVolume, to.unit is UnitMass {
            let kilograms = source.converted(to: UnitVolume.liters).value * ingredient.density
            return Measurement(value: kilograms, unit: UnitMass.kilograms).converted(to: to.unit).value
        }
        return source.converted(to: to.unit).value
    }

    /// Converts `value` in `from` into every unit of `category` that belongs to `system`
    /// (or every unit of the category when `system` is nil).
    static func convert(_ value: Double, from: UnitOption, in category: UnitCategory,
                        to system: MeasurementSystem?, ingredient: Ingredient = .water) -> [ConversionResult] {
        let targets = system.map { category.units(in: $0) } ?? category.units
        return targets.map { target in
            ConversionResult(unit: target, value: convert(value, from: from, to: target, ingredient: ingredient))
        }
    }

    /// Parses a batch multiplier such as "5", "x5", "×2.5", "1/2" or "1 1/2".
    /// Returns nil for anything that isn't a positive number.
    static func parseMultiplier(_ text: String, locale: Locale = .current) -> Double? {
        var trimmed = text.trimmingCharacters(in: .whitespaces)
        if let first = trimmed.first, "xX×*".contains(first) {
            trimmed = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        let result: Double?
        if trimmed.contains("/") {
            let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard (1...2).contains(parts.count) else { return nil }
            let fraction = parts.last!.split(separator: "/")
            guard fraction.count == 2,
                  let numerator = parse(String(fraction[0]), locale: locale),
                  let denominator = parse(String(fraction[1]), locale: locale),
                  denominator != 0 else { return nil }
            var total = numerator / denominator
            if parts.count == 2 {
                guard let whole = parse(String(parts[0]), locale: locale) else { return nil }
                total += whole
            }
            result = total
        } else {
            result = parse(trimmed, locale: locale)
        }
        guard let value = result, value.isFinite, value > 0 else { return nil }
        return value
    }

    /// A cooking-friendly fraction for a value, e.g. 2.5 → "2 ½", 0.333 → "⅓".
    /// Returns nil for whole numbers or values that aren't near a common fraction.
    static func kitchenFraction(_ value: Double) -> String? {
        guard value.isFinite, value > 0, value < 10_000 else { return nil }
        let whole = value.rounded(.down)
        let remainder = value - whole
        let fractions: [(Double, String)] = [
            (1.0 / 8, "⅛"), (1.0 / 4, "¼"), (1.0 / 3, "⅓"), (3.0 / 8, "⅜"), (1.0 / 2, "½"),
            (5.0 / 8, "⅝"), (2.0 / 3, "⅔"), (3.0 / 4, "¾"), (7.0 / 8, "⅞"),
        ]
        guard let match = fractions.min(by: { abs($0.0 - remainder) < abs($1.0 - remainder) }),
              abs(match.0 - remainder) < 0.01 else { return nil }
        let prefix = abs(match.0 - remainder) < 1e-9 ? "" : "≈ "
        return whole == 0 ? prefix + match.1 : "\(prefix)\(Int(whole)) \(match.1)"
    }

    /// The result that reads most naturally (closest to a value between 1 and 1000).
    static func bestFit(_ results: [ConversionResult]) -> ConversionResult? {
        results.min { score($0.value) < score($1.value) }
    }

    private static func score(_ value: Double) -> Double {
        let magnitude = abs(value)
        guard magnitude.isFinite, magnitude > 0 else { return .infinity }
        if magnitude >= 1 && magnitude < 1000 { return 0 }
        return magnitude < 1 ? -log10(magnitude) : log10(magnitude / 1000) + 0.5
    }

    /// Parses user input, accepting either "." or the locale's decimal separator.
    static func parse(_ text: String, locale: Locale = .current) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "−", with: "-")
        guard !trimmed.isEmpty else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        if let number = formatter.number(from: trimmed) { return number.doubleValue }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }

    /// Formats a value with up to 6 significant digits, switching to scientific
    /// notation for very large or very small numbers.
    static func format(_ value: Double, locale: Locale = .current) -> String {
        guard value.isFinite else { return "—" }
        let magnitude = abs(value)
        let formatter = NumberFormatter()
        formatter.locale = locale
        if magnitude != 0 && (magnitude >= 1e12 || magnitude < 1e-6) {
            formatter.numberStyle = .scientific
            formatter.maximumSignificantDigits = 4
        } else {
            formatter.numberStyle = .decimal
            formatter.usesSignificantDigits = true
            formatter.maximumSignificantDigits = 6
        }
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
