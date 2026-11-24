# Unit Converter (iOS)

A SwiftUI iPhone/iPad app that converts between **Imperial / US customary** and **Metric** units — in either direction.

## Features
- 10 categories: Length, Weight, Volume (US & UK), Temperature, Area, Speed, Fuel Economy (mpg ↔ L/100 km), Pressure, Energy, Power
- Pick any source unit and see the value in **every** unit of the other system at once
- "To Metric" / "To Imperial" toggle; ★ marks the most readable result
- Tap a result to copy it; long-press to convert from it; swap button in the toolbar
- Accepts `.` or `,` as decimal separator and negative numbers (± key above the keyboard)
- Remembers your last category, unit and value
- Conversions use Apple's `Foundation.Measurement` API (plus a few custom units: ft/s, BTU, ft·lbf, long ton, BTU/h)

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
