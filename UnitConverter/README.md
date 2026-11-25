# Unit Converter (iOS)

A SwiftUI iPhone/iPad app that converts between **Imperial / US customary** and **Metric** units — in either direction.

## Features
- 10 categories: Length, Weight, Volume (US & UK), Temperature, Area, Speed, Fuel Economy (mpg ↔ L/100 km), Pressure, Energy, Power
- **Any unit → any unit** in the same category, metric or Imperial/US, including same-system conversions (tsp → tbsp, g → kg, oz → lb)
- **Batch scaling:** multiply an amount by ×¼, ×⅓, ×½, ×2 … ×10, or any custom value (`5`, `2.5`, `1/2`, `1 1/2`), and get it in the unit you choose.
  Example: 1.5 tsp × 5 → **7.5 tsp** or **2.5 tbsp**
- **Weight ↔ volume:** choose **Liquid** (like water, 1 cup = 236.6 g), **Powder** (like flour, 1 cup ≈ 125 g) or **Solid** (like butter, 1 cup ≈ 227 g) — or **Ingredient** to pick from ~35 common ingredients with accepted cup weights (all-purpose flour 120 g, granulated sugar 200 g, honey 340 g, …). Edit `MaterialType` / `IngredientCatalog` in `ConversionEngine.swift` to adjust values.
- Imperial/US results also show a kitchen fraction (2.5 → "2 ½", 0.33 → "≈ ⅓")
- "All equivalents" list (All / Metric / Imperial) — tap a row to make it the target unit, long-press to copy or convert from it
- Swap button flips From/To; tap the main result to copy it
- Accepts `.` or `,` as decimal separator and negative numbers (± key above the keyboard)
- Remembers your last category, units, amount and batch size
- Imperial/US weight, volume, length and area units use exact legal definitions (Foundation's built-in factors are rounded, which would give e.g. 2.49999 tbsp instead of 2.5)

## Run it
1. On a Mac with **Xcode 15+**, open `UnitConverter.xcodeproj`.
2. Select an iPhone simulator and press **⌘R**.
3. To run on a real device, set your Team under *Signing & Capabilities* and change the bundle ID (`com.example.UnitConverter`) to something unique.

Run the unit tests with **⌘U**. Requires iOS 17+.

## Layout
```
UnitConverter/
  UnitConverterApp.swift    – app entry point
  ContentView.swift         – the UI
  ConversionEngine.swift    – unit catalogue, conversion, parsing & formatting
  Assets.xcassets           – app icon & accent color
UnitConverterTests/
  ConversionEngineTests.swift
```
