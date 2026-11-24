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

// MARK: - Custom units Foundation doesn't provide

extension UnitSpeed {
    static let feetPerSecond = UnitSpeed(symbol: "ft/s", converter: UnitConverterLinear(coefficient: 0.3048))
}

extension UnitEnergy {
    static let britishThermalUnits = UnitEnergy(symbol: "BTU", converter: UnitConverterLinear(coefficient: 1055.05585262))
    static let footPounds = UnitEnergy(symbol: "ft·lbf", converter: UnitConverterLinear(coefficient: 1.3558179483314004))
}

extension UnitMass {
    /// Imperial (long) ton, 2240 lb.
    static let longTons = UnitMass(symbol: "long tn", converter: UnitConverterLinear(coefficient: 1016.0469088))
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
        i("mi", "Miles", UnitLength.miles),
        i("nmi", "Nautical miles", UnitLength.nauticalMiles),
    ])

    static let mass = UnitCategory(id: "mass", name: "Weight", systemImage: "scalemass", units: [
        m("mg", "Milligrams", UnitMass.milligrams),
        m("g", "Grams", UnitMass.grams),
        m("kg", "Kilograms", UnitMass.kilograms),
        m("t", "Metric tons", UnitMass.metricTons),
        i("oz", "Ounces", UnitMass.ounces),
        i("lb", "Pounds", UnitMass.pounds),
        i("st", "Stone", UnitMass.stones),
        i("ton", "US tons (short)", UnitMass.shortTons),
        i("lton", "Imperial tons (long)", UnitMass.longTons),
    ])

    static let volume = UnitCategory(id: "volume", name: "Volume", systemImage: "drop", units: [
        m("ml", "Milliliters", UnitVolume.milliliters),
        m("l", "Liters", UnitVolume.liters),
        m("cm3", "Cubic centimeters", UnitVolume.cubicCentimeters),
        m("m3", "Cubic meters", UnitVolume.cubicMeters),
        i("tsp", "Teaspoons (US)", UnitVolume.teaspoons),
        i("tbsp", "Tablespoons (US)", UnitVolume.tablespoons),
        i("floz", "Fluid ounces (US)", UnitVolume.fluidOunces),
        i("cup", "Cups (US)", UnitVolume.cups),
        i("pt", "Pints (US)", UnitVolume.pints),
        i("qt", "Quarts (US)", UnitVolume.quarts),
        i("gal", "Gallons (US)", UnitVolume.gallons),
        i("impfloz", "Fluid ounces (UK)", UnitVolume.imperialFluidOunces),
        i("imppt", "Pints (UK)", UnitVolume.imperialPints),
        i("impgal", "Gallons (UK)", UnitVolume.imperialGallons),
        i("in3", "Cubic inches", UnitVolume.cubicInches),
        i("ft3", "Cubic feet", UnitVolume.cubicFeet),
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
        i("in2", "Square inches", UnitArea.squareInches),
        i("ft2", "Square feet", UnitArea.squareFeet),
        i("yd2", "Square yards", UnitArea.squareYards),
        i("ac", "Acres", UnitArea.acres),
        i("mi2", "Square miles", UnitArea.squareMiles),
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
}

// MARK: - Conversion

enum Converter {
    /// Converts `value` in `from` into every unit of `category` that belongs to `system`.
    static func convert(_ value: Double, from: UnitOption, in category: UnitCategory,
                        to system: MeasurementSystem) -> [ConversionResult] {
        let source = Measurement(value: value, unit: from.unit)
        return category.units(in: system).map { target in
            ConversionResult(unit: target, value: source.converted(to: target.unit).value)
        }
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
