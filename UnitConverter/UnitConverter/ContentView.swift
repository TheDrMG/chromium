import SwiftUI
import UIKit

/// Which units to list under "All equivalents".
enum ResultFilter: String, CaseIterable, Identifiable {
    case all, metric, imperial
    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .metric: return "Metric"
        case .imperial: return "Imperial / US"
        }
    }

    var system: MeasurementSystem? {
        switch self {
        case .all: return nil
        case .metric: return .metric
        case .imperial: return .imperial
        }
    }
}

struct ContentView: View {
    private enum Field { case amount, scale }

    /// Quick batch-size buttons: (stored text, label).
    private static let quickScales: [(String, String)] = [
        ("1/4", "×¼"), ("1/3", "×⅓"), ("1/2", "×½"), ("1", "×1"), ("2", "×2"),
        ("3", "×3"), ("4", "×4"), ("5", "×5"), ("10", "×10"),
    ]

    @AppStorage("categoryID") private var categoryID = UnitCatalog.volume.id
    @AppStorage("sourceUnitID") private var sourceUnitID = "tsp"
    @AppStorage("targetUnitID") private var targetUnitID = "tbsp"
    @AppStorage("inputText") private var inputText = "1.5"
    @AppStorage("scaleText") private var scaleText = "1"
    @AppStorage("resultFilter") private var filterRaw = ResultFilter.all.rawValue
    @AppStorage("ingredientID") private var ingredientID = Ingredient.water.id
    @AppStorage("materialType") private var materialRaw = MaterialType.liquid.rawValue

    @FocusState private var focusedField: Field?
    @State private var copiedID: String?

    // MARK: Derived state

    private var category: UnitCategory {
        UnitCatalog.category(withID: categoryID) ?? UnitCatalog.volume
    }

    private var sourceUnit: UnitOption {
        category.unit(withID: sourceUnitID) ?? category.units[0]
    }

    /// The category plus any category it can convert into (weight <-> volume).
    private var targetCategories: [UnitCategory] { UnitCatalog.targetCategories(for: category) }

    private var targetUnit: UnitOption {
        UnitCatalog.targetUnit(withID: targetUnitID, from: category)
            ?? category.units(in: sourceUnit.system.opposite).first
            ?? category.units[0]
    }

    private var material: MaterialType { MaterialType(rawValue: materialRaw) ?? .liquid }
    private var ingredient: Ingredient { material.resolve(ingredientID: ingredientID) }

    /// Weight and Volume can convert into each other, which needs an ingredient.
    private var usesIngredient: Bool { targetCategories.count > 1 }

    private var filter: ResultFilter { ResultFilter(rawValue: filterRaw) ?? .all }

    private var inputValue: Double? { Converter.parse(inputText) }
    private var multiplier: Double? { Converter.parseMultiplier(scaleText) }

    /// The amount after scaling, still in the source unit.
    private var scaledValue: Double? {
        guard let value = inputValue, let multiplier else { return nil }
        return value * multiplier
    }

    private var isScaled: Bool { (multiplier ?? 1) != 1 }

    private var targetValue: Double? {
        scaledValue.map { Converter.convert($0, from: sourceUnit, to: targetUnit, ingredient: ingredient) }
    }

    private func equivalents(in target: UnitCategory) -> [ConversionResult] {
        guard let scaledValue else { return [] }
        return Converter.convert(scaledValue, from: sourceUnit, in: target, to: filter.system, ingredient: ingredient)
    }

    /// Section title for a target category, flagging the water assumption.
    private func title(for target: UnitCategory) -> String {
        target == category ? target.name : "\(target.name) (as \(ingredient.name.lowercased()))"
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            List {
                Section {
                    categoryPicker
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                amountSection
                scaleSection
                targetSection
                equivalentsSection
            }
            .navigationTitle("Unit Converter")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        swapUnits()
                    } label: {
                        Label("Swap units", systemImage: "arrow.up.arrow.down")
                    }
                    .disabled(targetValue == nil)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if focusedField == .amount {
                        Button("±") { toggleSign() }
                    }
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
        }
    }

    // MARK: Sections

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(UnitCatalog.all) { item in
                    chip(item.name, systemImage: item.systemImage, selected: item == category) {
                        selectCategory(item)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var amountSection: some View {
        Section("Amount") {
            HStack(spacing: 12) {
                TextField("Value", text: $inputText)
                    .keyboardType(.numbersAndPunctuation)
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .focused($focusedField, equals: .amount)
                    .submitLabel(.done)
                    .accessibilityLabel("Amount to convert")
                if !inputText.isEmpty {
                    Button {
                        inputText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear")
                }
            }
            unitPicker("From", selection: $sourceUnitID, categories: [category])
            if !inputText.isEmpty && inputValue == nil {
                Text("“\(inputText)” isn’t a number.").foregroundStyle(.red)
            }
        }
    }

    private var scaleSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.quickScales, id: \.0) { item in
                        chip(item.1, selected: multiplier == Converter.parseMultiplier(item.0)) {
                            scaleText = item.0
                            focusedField = nil
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))

            HStack {
                Text("Multiply by")
                Spacer()
                Text("×").foregroundStyle(.secondary)
                TextField("1", text: $scaleText)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 90)
                    .focused($focusedField, equals: .scale)
                    .submitLabel(.done)
                    .accessibilityLabel("Batch multiplier")
            }
            if multiplier == nil {
                Text("Enter a positive number, e.g. 5, 2.5 or 1/2.").foregroundStyle(.red)
            }
        } header: {
            Text("Batch size")
        } footer: {
            Text("Scale a recipe amount — e.g. ×5 to make five batches, ×½ for half a batch.")
        }
    }

    private var targetSection: some View {
        Section("Convert to") {
            unitPicker("To", selection: $targetUnitID, categories: targetCategories, current: targetUnit.id)

            if usesIngredient {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weight ↔ volume as")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("Material", selection: $materialRaw) {
                        ForEach(MaterialType.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    Text(material == .ingredient ? material.examples : "\(material.examples) · \(densityNote)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                if material == .ingredient {
                    Picker("Ingredient", selection: $ingredientID) {
                        ForEach(IngredientCatalog.groups) { group in
                            Section(group.name) {
                                ForEach(group.items) { item in
                                    Text(item.name).tag(item.id)
                                }
                            }
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            if let targetValue, let value = inputValue {
                let formatted = Converter.format(targetValue)
                Button {
                    copy("\(formatted) \(targetUnit.symbol)", id: "target")
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(equationText(value))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(formatted) \(targetUnit.symbol)")
                                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                            Spacer()
                            copiedBadge(id: "target")
                        }
                        if targetUnit.system == .imperial, let fraction = Converter.kitchenFraction(targetValue) {
                            Text("\(fraction) \(targetUnit.symbol)")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        if Converter.isWeightVolumeConversion(from: sourceUnit, to: targetUnit) {
                            Label("\(ingredient.name): \(densityNote)", systemImage: "scalemass")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Copies the result")
            }
        }
    }

    @ViewBuilder
    private var equivalentsSection: some View {
        Section {
            Picker("Show", selection: $filterRaw) {
                ForEach(ResultFilter.allCases) { Text($0.title).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }

        ForEach(targetCategories) { target in
            let results = equivalents(in: target)
            if !results.isEmpty {
                let best = Converter.bestFit(results)
                Section {
                    ForEach(results) { result in
                        equivalentRow(result, isBest: result.id == best?.id)
                    }
                } header: {
                    Text(isScaled ? "\(title(for: target)) — scaled" : title(for: target))
                } footer: {
                    if target != category {
                        Text("Converted as \(ingredient.name.lowercased()): \(densityNote). Change it under “Weight ↔ volume as” above.")
                    } else {
                        Text("Tap to make it the “To” unit. Long-press to copy or convert from it.")
                    }
                }
            }
        }
    }

    private func equivalentRow(_ result: ConversionResult, isBest: Bool) -> some View {
        let formatted = Converter.format(result.value)
        let isTarget = result.unit == targetUnit
        return Button {
            targetUnitID = result.unit.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.unit.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(formatted) \(result.unit.symbol)")
                            .font(.system(.title3, design: .rounded).weight(isTarget ? .bold : .regular))
                        if result.unit.system == .imperial, let fraction = Converter.kitchenFraction(result.value) {
                            Text("(\(fraction))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                if copiedID == result.id {
                    copiedBadge(id: result.id)
                } else if isTarget {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.brand)
                        .accessibilityLabel("Selected")
                } else if isBest {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                        .accessibilityLabel("Most readable")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                copy("\(formatted) \(result.unit.symbol)", id: result.id)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            Button {
                inputText = plainNumber(result.value)
                convertFrom(result.unit)
                scaleText = "1"
            } label: {
                Label("Convert from \(result.unit.name)", systemImage: "arrow.uturn.up")
            }
        }
    }

    // MARK: Reusable pieces

    private func unitPicker(_ title: String, selection: Binding<String>, categories: [UnitCategory],
                            current: String? = nil) -> some View {
        let binding = Binding<String>(
            get: { current ?? category.unit(withID: selection.wrappedValue)?.id ?? category.units[0].id },
            set: { selection.wrappedValue = $0 }
        )
        let showCategoryName = categories.count > 1
        return Picker(title, selection: binding) {
            ForEach(categories) { group in
                ForEach(MeasurementSystem.allCases) { system in
                    Section(showCategoryName ? "\(self.title(for: group)) · \(system.title)" : system.title) {
                        ForEach(group.units(in: system)) { unit in
                            Text("\(unit.name) (\(unit.symbol))").tag(unit.id)
                        }
                    }
                }
            }
        }
        .pickerStyle(.menu)
    }

    private func chip(_ title: String, systemImage: String? = nil, selected: Bool,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Label(title, systemImage: systemImage)
                } else {
                    Text(title)
                }
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(selected ? Color.brand : Color(.secondarySystemGroupedBackground)))
            .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private func copiedBadge(id: String) -> some View {
        if copiedID == id {
            Label("Copied", systemImage: "checkmark")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.green)
        }
    }

    /// e.g. "1 cup = 120 g" for the selected ingredient.
    private var densityNote: String {
        "1 cup = \(Converter.format((ingredient.gramsPerCup * 10).rounded() / 10)) g"
    }

    /// e.g. "1.5 tsp × 5 = 7.5 tsp =" or "1.5 tsp =".
    private func equationText(_ value: Double) -> String {
        let source = "\(Converter.format(value)) \(sourceUnit.symbol)"
        guard isScaled, let multiplier, let scaledValue else { return "\(source) =" }
        let scale = Converter.format(multiplier)
        if sourceUnit == targetUnit { return "\(source) × \(scale) =" }
        return "\(source) × \(scale) = \(Converter.format(scaledValue)) \(sourceUnit.symbol) ="
    }

    // MARK: Actions

    private func selectCategory(_ newCategory: UnitCategory) {
        guard newCategory != category else { return }
        categoryID = newCategory.id
        let from = newCategory.units(in: .imperial).first ?? newCategory.units[0]
        sourceUnitID = from.id
        targetUnitID = (newCategory.units(in: .metric).first ?? newCategory.units[0]).id
    }

    /// Swaps From and To, carrying the (scaled) result over as the new amount.
    private func swapUnits() {
        guard let targetValue else { return }
        let oldSource = sourceUnit.id
        inputText = plainNumber(targetValue)
        convertFrom(targetUnit)
        targetUnitID = oldSource
        scaleText = "1"
    }

    /// Makes `unit` the From unit, switching between Weight and Volume if needed.
    private func convertFrom(_ unit: UnitOption) {
        if let owner = targetCategories.first(where: { $0.unit(withID: unit.id) != nil }) {
            categoryID = owner.id
        }
        sourceUnitID = unit.id
    }

    private func toggleSign() {
        if inputText.hasPrefix("-") {
            inputText.removeFirst()
        } else {
            inputText = "-" + inputText
        }
    }

    private func copy(_ text: String, id: String) {
        UIPasteboard.general.string = text
        withAnimation { copiedID = id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { if copiedID == id { copiedID = nil } }
        }
    }

    /// A formatted number without grouping separators, suitable for re-entry.
    private func plainNumber(_ value: Double) -> String {
        Converter.format(value).replacingOccurrences(of: Locale.current.groupingSeparator ?? ",", with: "")
    }
}

#Preview {
    ContentView()
}
