# Impact methodology

Version: 2026-10-24. Three quantities are intentionally kept separate: application XP, an incomplete personal consumption estimate, and user-declared waste-management scenario differences. No field baseline or causal waste-reduction result has been measured.

## Personal estimate

The new short flow accepts household electricity in kWh/month and household size, plus personal petrol/diesel consumption in litres/month. Annual UI entries are divided by 12 before submission. Unknown answers remain unknown. A zero value must be entered explicitly.

- Electricity: **0.469 kgCO2e/kWh**, Turkey distribution-grid consumption factor, reporting year 2023. Source: [ETKB](https://enerji.gov.tr/evced-cevre-ve-iklim-elektrik-uretim-tuketim-emisyon-faktorleri). Published tCO2e/MWh and kgCO2e/kWh have the same numeric value. Household energy is divided by household members.
- Petrol combustion: **8.887 kgCO2 / 3.785411784 litres**.
- Diesel combustion: **10.180 kgCO2 / 3.785411784 litres**. These are US fuel-composition proxies, not Turkey-specific lifecycle factors. Source: [US EPA](https://www.epa.gov/greenvehicles/greenhouse-gas-emissions-typical-passenger-vehicle).

The aggregate includes measured-input electricity CO2e plus fuel combustion CO2, with CO2's GWP of one. It omits other vehicle gases and upstream fuel production. Heating, food, aviation and other purchases are explicitly missing, so the result is a **known-scope partial estimate**, not a complete personal inventory. The previous questionnaire's fixed answer weights are retained only in legacy code and are not presented as source-based coefficients.

Hand check: 200 kWh/month × 12 × 0.469 / 2 people = **562.8 kgCO2e/person/year**, or 46.9 kg/month. The month is a uniform annual projection, not a measured seasonal distribution.

## Waste scenario comparison

Versioned source: [EPA WARM v13, March 2015 factor table](https://archive.epa.gov/epawaste/conserve/tools/warm/Warm_Form.html), US national assumptions. This historical published version is explicitly used; it is not represented as the latest WARM release.

| Material | Landfill | Recycling | Original unit |
|---|---:|---:|---|
| PET | 0.04 | -1.13 | metric tonnes CO2e / US short ton |
| Glass | 0.04 | -0.28 | metric tonnes CO2e / US short ton |
| Aluminum cans | 0.04 | -9.11 | metric tonnes CO2e / US short ton |

`differenceKgCO2e = materialKg × (baselineFactor - selectedFactor) × 1000 / 907.18474`.

The WARM comparison includes materials-management and displaced manufacturing credits. It is not a measured Turkey emissions reduction and must not be merged with the personal footprint as an offset. A negative difference remains negative; identical routes yield zero. Unsupported materials/routes yield no estimate.

Mass is supplied by the user, preferably by weighing; no grams are inferred from the photo. Evidence is USER_DECLARED. A scan, route launch, quiz, login or quest reward does not create a carbon action automatically. Each action has a stable user-scoped key. Replaying the same key returns the same record. Deleting an action changes the SQL-derived total immediately. Distinct dishonest declarations cannot be externally verified by this MVP.

## Pilot proposal

Recruit, for example, 20 consenting campus volunteers for two weeks. Measure an initial sorting quiz and time to identify an appropriate return point, then repeat after the pilot. Record conditional routing success and separately label self-reported returns. Track AI corrections/rejections and API latency. These are proposed measurements, not completed findings. A comparison design and sufficient evidence are needed before claiming causal waste reduction.
