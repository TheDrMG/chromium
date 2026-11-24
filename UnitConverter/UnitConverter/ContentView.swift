import SwiftUI
import UIKit

struct ContentView: View {
    @AppStorage("categoryID") private var categoryID = UnitCatalog.length.id
    @AppStorage("sourceUnitID") private var sourceUnitID = "ft"
    @AppStorage("targetSystem") private var targetSystemRaw = MeasurementSystem.metric.rawValue
    @AppStorage("inputText") private var inputText = "1"

    @FocusState private var inputFocused: Bool
    @State private var copiedID: String?

    private var category: UnitCategory {
        UnitCatalog.category(withID: categoryID) ?? UnitCatalog.length
    }

    private var targetSystem: MeasurementSystem {
        MeasurementSystem(rawValue: targetSystemRaw) ?? .metric
    }

    private var sourceUnit: UnitOption {
        category.unit(withID: sourceUnitID)
            ?? category.units(in: targetSystem.opposite).first
            ?? category.units[0]
    }

    private var inputValue: Double? { Converter.parse(inputText) }

    private var results: [ConversionResult] {
        guard let value = inputValue else { return [] }
        return Converter.convert(value, from: sourceUnit, in: category, to: targetSystem)
            .filter { $0.unit != sourceUnit }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    categoryPicker
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section("Convert") {
                    HStack(spacing: 12) {
                        TextField("Value", text: $inputText)
                            .keyboardType(.numbersAndPunctuation)
                            .font(.system(.title, design: .rounded).weight(.semibold))
                            .focused($inputFocused)
                            .submitLabel(.done)
                            .accessibilityLabel("Value to convert")
                        if !inputText.isEmpty {
                            Button {
                                inputText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear")
                        }
                    }

                    Picker("From", selection: sourceBinding) {
                        ForEach(MeasurementSystem.allCases) { system in
                            Section(system.title) {
                                ForEach(category.units(in: system)) { unit in
                                    Text("\(unit.name) (\(unit.symbol))").tag(unit.id)
                                }
                            }
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    Picker("Convert to", selection: targetBinding) {
                        ForEach(MeasurementSystem.allCases) { system in
                            Text("To \(system.title)").tag(system)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                resultsSection
            }
            .navigationTitle("Unit Converter")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        flipDirection()
                    } label: {
                        Label("Swap", systemImage: "arrow.left.arrow.right")
                    }
                    .disabled(results.isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Button("±") { toggleSign() }
                    Spacer()
                    Button("Done") { inputFocused = false }
                }
            }
        }
    }

    // MARK: Subviews

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(UnitCatalog.all) { item in
                    Button {
                        selectCategory(item)
                    } label: {
                        Label(item.name, systemImage: item.systemImage)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(item == category ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                            )
                            .foregroundStyle(item == category ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(item == category ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        let best = Converter.bestFit(results)
        Section {
            if inputValue == nil {
                Text(inputText.isEmpty ? "Enter a value to convert." : "“\(inputText)” isn’t a number.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(results) { result in
                    resultRow(result, isBest: result.id == best?.id)
                }
            }
        } header: {
            Text(targetSystem.title)
        } footer: {
            if inputValue != nil {
                Text("Tap a result to copy it. Long-press to convert from it.")
            }
        }
    }

    private func resultRow(_ result: ConversionResult, isBest: Bool) -> some View {
        let formatted = Converter.format(result.value)
        return Button {
            UIPasteboard.general.string = "\(formatted) \(result.unit.symbol)"
            withAnimation { copiedID = result.id }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation { if copiedID == result.id { copiedID = nil } }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.unit.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(formatted) \(result.unit.symbol)")
                        .font(.system(isBest ? .title2 : .title3, design: .rounded).weight(isBest ? .bold : .regular))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }
                Spacer()
                if copiedID == result.id {
                    Label("Copied", systemImage: "checkmark")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.green)
                } else if isBest {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("Best fit")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                useAsSource(result)
            } label: {
                Label("Convert from \(result.unit.name)", systemImage: "arrow.uturn.left")
            }
        }
    }

    // MARK: Bindings & actions

    private var sourceBinding: Binding<String> {
        Binding(get: { sourceUnit.id }, set: { sourceUnitID = $0 })
    }

    private var targetBinding: Binding<MeasurementSystem> {
        Binding(get: { targetSystem }, set: { newSystem in
            targetSystemRaw = newSystem.rawValue
            // Keep converting *from* the other system so results stay useful.
            if sourceUnit.system == newSystem,
               let replacement = category.units(in: newSystem.opposite).first {
                sourceUnitID = replacement.id
            }
        })
    }

    private func selectCategory(_ newCategory: UnitCategory) {
        guard newCategory != category else { return }
        categoryID = newCategory.id
        sourceUnitID = newCategory.units(in: targetSystem.opposite).first?.id ?? newCategory.units[0].id
    }

    private func flipDirection() {
        guard let best = Converter.bestFit(results) else { return }
        useAsSource(best)
    }

    private func useAsSource(_ result: ConversionResult) {
        inputText = Converter.format(result.value)
            .replacingOccurrences(of: Locale.current.groupingSeparator ?? ",", with: "")
        sourceUnitID = result.unit.id
        targetSystemRaw = result.unit.system.opposite.rawValue
    }

    private func toggleSign() {
        if inputText.hasPrefix("-") {
            inputText.removeFirst()
        } else {
            inputText = "-" + inputText
        }
    }
}

#Preview {
    ContentView()
}
