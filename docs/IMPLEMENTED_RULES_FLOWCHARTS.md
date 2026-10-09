# Can I Wear — Implemented Rules Flowcharts

> Status: DESCRIPTIVE IMPLEMENTATION REFERENCE
> Source of truth: NO — approved behavior remains in `DECISIONS.md` and the other truth files
> Generated from the implementation on 2026-10-09

These charts describe the rules currently implemented in the app. They do not approve any remaining TBD product or UX decisions. Values shown below come from `AppConfiguration.swift`.

## 1. Location, weather, and cache flow

```mermaid
flowchart TD
    A["App screen starts `loadIfNeeded()`"] --> B{"State is idle?"}
    B -- "No" --> B1["Do nothing; repeated view updates do not start duplicate requests"]
    B -- "Yes" --> C["Show loading state"]

    C --> D["Read latest saved location"]
    D --> E{"Location cache is decodable and valid?<br/>• coordinates are finite and in range<br/>• accuracy exists, is finite, and is 0–5 km<br/>• age is 0–30 minutes inclusive"}
    E -- "Yes" --> F["Reuse cached location; do not ask Core Location"]
    E -- "No" --> G["Ask Core Location for a one-time location"]

    G --> G1{"Location Services enabled?"}
    G1 -- "No" --> LU["Show: Couldn’t get your location"]
    G1 -- "Yes" --> G2{"Authorization status"}
    G2 -- "Not determined" --> G3["Request when-in-use permission"]
    G3 --> G2
    G2 -- "Denied" --> LD["Show: Location access needed"]
    G2 -- "Restricted / unknown" --> LU
    G2 -- "Authorized" --> G4["Start updates at requested accuracy ≈1 km"]
    G4 --> G5{"Usable fix received within 15 seconds?<br/>Choose newest fix with accuracy 0–5 km"}
    G5 -- "Yes" --> G6["Stop updates and save latest accepted location"]
    G5 -- "No / timeout / non-locationUnknown error" --> G7["Stop updates"]
    G7 --> LU
    G5 -- "Task cancelled" --> G8["Stop updates and return to idle"]
    G4 --> G9["Ignore `locationUnknown` errors and continue until fix or timeout"]
    G9 --> G5

    F --> H["Look up saved normalized forecast for this location"]
    G6 --> H
    H --> I{"Stored forecast otherwise usable?<br/>• decodes; valid metadata coordinate<br/>• nonempty hours; finite timestamps<br/>• one valid forecast timezone<br/>• at least one hour from current local hour to day end<br/>• forecast location is within 5 km<br/>• timestamp is not in the future"}
    I -- "No" --> K["Do not show a saved recommendation"]
    I -- "Yes; age under 15 minutes" --> SKIP["Show saved periods + age<br/>Skip network refresh"]
    I -- "Yes; age 15–90 minutes inclusive" --> J["Immediately show saved periods + Updating"]
    I -- "Yes; age over 90 minutes" --> X["Do not show the expired recommendation"]

    J --> L["Request live weather"]
    K --> L
    X --> L
    L --> M{"Live request finishes within 10 seconds?"}
    M -- "Yes" --> N{"Live forecast passes daily evaluation and produces periods?"}
    N -- "Yes" --> O["Save normalized forecast; replace cache display with live periods"]
    N -- "No" --> P["Treat live forecast as incomplete"]
    M -- "No / provider or network failure" --> Q["Refresh/fetch failed"]
    M -- "Cancelled" --> R["Try valid cache; otherwise return to idle"]

    P --> S{"A currently valid, presentable cache exists?"}
    S -- "Yes" --> T["Keep/show cached periods; remove Refreshing"]
    S -- "No, including expired" --> FI["Show: Today’s forecast is incomplete"]

    Q --> U{"A currently valid, presentable cache exists?"}
    U -- "Yes" --> T
    U -- "No; structurally/location invalid, future-dated, wrong day, or absent" --> WU["Show: Weather unavailable"]
    U -- "No; cache is otherwise usable but older than 90 minutes" --> WE["Show: Weather unavailable<br/>Saved forecast is too old; connect and retry"]

    R --> V{"Valid, presentable cache exists?"}
    V -- "Yes" --> T
    V -- "No / expired" --> G8

    LD --> RT["Try Again reruns the flow<br/>30-second cooldown after a failed user retry"]
    LU --> RT
    FI --> RT
    WU --> RT
    WE --> RT
```

The app applies the same weather-age policy on launch, foreground activation and active-screen boundaries. Exactly 15 minutes starts refresh; exactly 90 minutes remains visible while refresh runs; any amount over 90 minutes is stale. A stale forecast is classified as “expired” only after storage, structure, current-day coverage, location match and non-future timestamp checks pass. Other rejected cache entries are unavailable.

Pull-to-refresh uses the same flow but never starts a provider request before 15 minutes, while another request runs, or during the 30-second post-failure cooldown. A blocked pull retains the current recommendation and the home-screen status explains when refresh is available. No two weather requests run concurrently.

## 2. Hourly OK, Caution, and Avoid rules

```mermaid
flowchart TD
    A["Normalized hourly weather"] --> B{"Required data valid?<br/>• amount exists, finite, and ≥0 mm<br/>• chance exists, finite, and 0–100%<br/>• precipitation type is not `unknown`<br/>• at least one temperature exists<br/>• every available temperature is finite<br/>• fog/mist is optional and never inferred"}
    B -- "No" --> NR["No hourly recommendation"]
    B -- "Yes" --> C["Selected temperature = warmer of actual and apparent<br/>If only one exists, use it"]

    C --> D{"Precipitation amount >0 mm<br/>OR explicit type is drizzle, rain, hail, snow, sleet, or mixed?"}
    D -- "Yes" --> AP["AVOID<br/>Reason: precipitation<br/>UI: Don’t wear"]
    D -- "No" --> E{"Precipitation chance ≥20%?"}
    E -- "Yes" --> AP
    E -- "No" --> F{"Explicit provider fog/mist condition?"}
    F -- "Yes" --> AF["AVOID<br/>Reason: fog/mist<br/>UI reason: Fog is expected."]
    F -- "No / unavailable" --> G{"Selected temperature >20°C?"}
    G -- "Yes" --> AH["AVOID<br/>Reason: excessive heat<br/>UI: Don’t wear"]
    G -- "No" --> H{"Precipitation chance ≥10%?"}
    H -- "Yes" --> CP["CAUTION<br/>Reason: precipitation risk<br/>UI: Maybe"]
    H -- "No" --> I{"Selected temperature >15°C?"}
    I -- "Yes; ≤20°C" --> CW["CAUTION<br/>Reason: warm temperature<br/>UI: Maybe"]
    I -- "No; ≤15°C" --> OK["OK<br/>Reason: suitable temperature<br/>UI: Wear"]
```

The ordering implements protective precedence:

1. Invalid data produces no answer.
2. Actual precipitation or an explicit precipitation type overrides everything.
3. A precipitation chance of at least 20% produces Avoid.
4. An explicit fog/mist condition produces Avoid and outranks heat/caution/okay results.
5. Excessive heat outranks a precipitation-only Caution.
6. A 10%–less-than-20% precipitation chance outranks an otherwise OK temperature.

`nil` precipitation type does not by itself invalidate an hour; `unknown` does. Amount and probability are still required.

When multiple recommendations of the same level must be reduced to one reason, the implemented least-to-most-protective reason priority is:

```mermaid
flowchart LR
    A["Suitable temperature"] --> B["Warm temperature"] --> C["Incomplete forecast"] --> D["Precipitation risk"] --> E["Excessive heat"] --> F["Fog/mist"] --> G["Precipitation"]
```

## 3. Daily forecast window and completeness

This separate chart is required because valid hourly classifications are not enough to produce a daily answer or dayparts.

```mermaid
flowchart TD
    A["Normalized forecast + explicit current time"] --> B{"Exactly one non-nil timezone identifier across forecast hours,<br/>and is it a valid system timezone?"}
    B -- "No" --> NR["No daily evaluation / forecast incomplete"]
    B -- "Yes" --> C["Calculate that timezone’s current calendar day and current hour"]
    C --> D["Expected window = start of current local hour through local day end<br/>DST may produce a 23- or 25-hour day"]
    D --> E["Ignore forecast hours before the current hour and at/after day end"]
    E --> F{"Any duplicate timestamp inside the window?"}
    F -- "Yes" --> NR
    F -- "No" --> G["For every expected hourly timestamp, evaluate the matching hour"]
    G --> H["Missing timestamp, mismatched/missing timezone, or invalid hourly inputs = one unusable gap"]
    H --> I{"How many unusable gaps?"}

    I -- "None" --> J["Return ordered hourly evaluations with timestamps and timezone"]
    I -- "Exactly one" --> K{"Valid immediate hour before AND after it?"}
    K -- "No; gap is at either edge" --> NR
    K -- "Yes" --> L["Infer the missing hour at its original timestamp<br/>Level = most protective of Caution and both neighbors<br/>Reason = incomplete forecast"]
    L --> J
    I -- "Two or more" --> NR

    J --> M["DayPeriodEngine creates the result used by the current UI"]
    J --> N["Legacy/basic summary helper, when called, chooses the most protective hour<br/>Avoid > Caution > OK; same-level ties use reason priority"]
```

An empty evaluated window cannot produce a daily evaluation. The current hour is included even when the current time is partway through that hour.

## 4. When dayparts are joined or split

Daypart processing is level-based and runs in this exact order: consolidate noisy alternation, absorb short non-Avoid changes, expand isolated Avoid hours, then group final runs.

```mermaid
flowchart TD
    A["Ordered hourly daily evaluation"] --> B{"Any evaluated hours?"}
    B -- "No" --> Z["No dayparts"]
    B -- "Yes" --> C["Build contiguous runs by level only<br/>A reason change alone does not split a run"]

    C --> D{"Find a span of at least 3 consecutive one-hour runs<br/>(hour-by-hour changing levels)"}
    D -- "Yes" --> E["Replace the entire noisy span with its most protective recommendation<br/>Repeat for each maximal noisy span"]
    D -- "No" --> F["Keep levels unchanged"]
    E --> G["Rebuild level runs"]
    F --> G

    G --> H{"Is there a non-Avoid run shorter than 3 hours?"}
    H -- "No" --> M["Short-change absorption is stable"]
    H -- "Yes" --> I{"Adjacent runs"}
    I -- "Both sides have the same level" --> J["Replace short run from the preceding adjacent run"]
    I -- "Both sides differ" --> K["Replace from the more protective adjacent run"]
    I -- "Only one side exists" --> L["Replace from that adjacent run"]
    J --> H
    K --> H
    L --> H

    M --> N["Rebuild level runs"]
    N --> O{"Any one-hour Avoid run?"}
    O -- "No" --> R["Group final contiguous levels"]
    O -- "Yes, with a preceding hour" --> P["Convert the preceding hour to the same Avoid recommendation<br/>Result: 2-hour safety period"]
    O -- "Yes, at start of window" --> Q["Convert the following hour to the same Avoid recommendation<br/>Result: 2-hour safety period"]
    P --> R
    Q --> R

    R --> S["One daypart per final contiguous level<br/>Ordered and non-overlapping<br/>End = next part’s start, or evaluated day end"]
    S --> T["Choose the most protective reason within each final run"]
    T --> U{"How many final dayparts?"}
    U -- "One" --> V["Show one prominent recommendation without a time-range heading"]
    U -- "More than one" --> W["Show every ordered daypart with its local start–end range"]
```

Additional implemented implications:

- Avoid runs are never absorbed merely because they are shorter than three hours.
- A two-hour Avoid run remains a two-hour Avoid run; only a one-hour Avoid run is expanded.
- Short safer gaps can therefore be absorbed into surrounding risk.
- A normal change must survive for at least three hours to remain a separate part.
- Replacement repeats until there are no more absorbable short non-Avoid runs.

## 5. Provider precipitation and fog normalization

The active Open-Meteo adapter converts provider data before the hourly rules run. The resulting precipitation type and separately normalized explicit fog/mist condition can independently trigger Avoid.

```mermaid
flowchart TD
    A["Open-Meteo hour<br/>Missing rain/showers/snowfall values default to 0"] --> B{"Snowfall >0 AND rain or showers >0?"}
    B -- "Yes" --> MIX["Type = mixed"]
    B -- "No" --> C{"Snowfall >0?"}
    C -- "Yes" --> SNOW["Type = snow"]
    C -- "No" --> D{"Rain >0 OR showers >0?"}
    D -- "Yes" --> RAIN["Type = rain"]
    D -- "No" --> E{"Weather code available?"}
    E -- "No; amount = 0" --> NONE["Type = none"]
    E -- "No; amount missing or nonzero" --> NIL["Type = nil"]
    E -- "Yes" --> F{"Weather-code group"}
    F -- "51–55" --> DRIZZLE["Type = drizzle"]
    F -- "56–57 or 66–67" --> SLEET["Type = sleet"]
    F -- "61–65 or 80–82" --> RAIN
    F -- "71–77 or 85–86" --> SNOW
    F -- "96 or 99" --> HAIL["Type = hail"]
    F -- "Other code; amount = 0" --> NONE
    F -- "Other code; amount missing or nonzero" --> UNKNOWN["Type = unknown → hourly input rejected"]

    MIX --> OUT["Run hourly recommendation rules"]
    SNOW --> OUT
    RAIN --> OUT
    NONE --> OUT
    NIL --> OUT
    DRIZZLE --> OUT
    SLEET --> OUT
    HAIL --> OUT
    UNKNOWN --> OUT
```

Other active mapping rules:

- Open-Meteo precipitation probability is converted from percent to a 0–1 fraction.
- Open-Meteo weather code 45 maps to explicit fog and code 48 to depositing rime fog. Any other present code maps to no fog/mist; a missing code remains unavailable. Humidity, dew point and visibility are not used to infer fog.
- Actual temperature, apparent temperature, precipitation amount, and missing values are preserved by index against the provider’s timestamp array.
- The forecast timezone is copied onto each normalized hour.
- Provider wind speed and gusts are normalized to km/h for diagnostics only. Missing wind is allowed, and wind is never passed into recommendation rules.
- HTTP 401/403 maps to unauthorized; other non-success HTTP responses map to unavailable; URL errors map to network failure; cancellation remains cancellation.
- The WeatherKit adapter maps Apple units, precipitation types, wind and its explicit `foggy` condition into the same normalized model, but it is not the active provider. It currently supplies no forecast timezone, so its output cannot yet pass the implemented daily-evaluation requirement without further integration work.

## 6. Opt-in local diagnostics

```mermaid
flowchart TD
    A["App becomes active"] --> B{"Apple Settings:<br/>Debug Enabled?"}
    B -- "No" --> C["Clear retained diagnostic events and current diagnostic snapshot<br/>Hide diagnostics control"]
    B -- "Yes" --> D["Show subtle Diagnostics control"]
    D --> E["Record structured location/weather/cache/evaluation events locally"]
    E --> F["Retain latest 20 events only"]
    E --> G["Summarize remaining-hour inputs, decisions and final periods<br/>Wind is informational only"]
    E --> H["Reverse-geocode place asynchronously<br/>Street → city/region → unavailable"]
    F --> I["Dismissible diagnostics sheet"]
    G --> I
    H --> I
    I --> J{"User chooses Copy Report?"}
    J -- "No" --> I
    J -- "Yes" --> K["Copy readable local report with visible place/privacy notice<br/>No automatic upload"]
```

## Implementation coverage

The charts cover the implemented behavior in:

- `AppConfiguration.swift`
- `ProviderContracts.swift`
- `CoreLocationProvider.swift`
- `ForecastCache.swift`
- `RecommendationViewModel.swift`
- `OpenMeteoProvider.swift`
- `WeatherKitProvider.swift`
- `JacketDecisionEngine.swift`
- `DayPeriodEngine.swift`
- `ContentView.swift`
- `DebugDiagnostics.swift`
- `Settings.bundle/Root.plist`

Phase 2.9 local diagnostics and the Phase 2 fog/mist protection are implemented. Phase 3’s final wording, palette, layout, permission recovery, and accessibility details remain TBD. The temporary implemented labels and states shown here must not be mistaken for those future approvals.
