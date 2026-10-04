# Can I Wear — TODO

> Status: ACTIVE
> Last updated: 2026-10-04
> Source of truth: YES

This is an execution list, not a source of product decisions.

## Remaining decisions / tuning

- [x] Final app name — **Can I Wear**
- [ ] Define measurable "few drops" rain tolerance
- [ ] Decide exact actual-vs-apparent temperature weighting
- [ ] Define dynamic period grouping/noise parameters
- [ ] Define cache freshness
- [ ] Define minimum supported OS versions
- [ ] Decide analytics/telemetry policy

## Technical foundation

- [ ] Initialize native Swift + SwiftUI Xcode project
- [ ] Establish iOS real-device build/run
- [ ] Configure WeatherKit capability
- [ ] Implement location provider
- [ ] Implement weather provider abstraction
- [ ] Define normalized internal weather model independent of provider
- [ ] Implement thin WeatherKit provider adapter
- [ ] Validate WeatherKit against accuracy, rain resolution, speed, reliability, cost and deployment complexity
- [ ] Implement cache
- [ ] Create centralized product configuration
- [ ] Create deterministic jacket decision engine
- [ ] Create period grouping engine

## V1 UX

- [ ] Main recommendation screen
- [ ] Fast first-frame/loading state
- [ ] Short explanation
- [ ] Dynamic periods
- [ ] No-location state
- [ ] No-weather state
- [ ] Stale-data state
- [ ] Permission UX
- [ ] Accessibility
- [ ] Visual polish

## Early follow-up features

- [ ] Decide exact V1 timing/scope for iOS widget
- [ ] Decide exact V1 timing/scope for notifications
- [ ] Implement widget when approved for the active phase
- [ ] Implement notifications when approved for the active phase

## Tests

- [ ] Dry + <=15°C
- [ ] Dry + 15–20°C
- [ ] Dry + >20°C
- [ ] Few drops
- [ ] Normal rain
- [ ] Heavy rain
- [ ] Rain + cold
- [ ] Rain + warm
- [ ] Morning rain only
- [ ] Later-day rain only
- [ ] Noisy alternating forecast
- [ ] Missing weather
- [ ] Missing location
- [ ] Network unavailable
- [ ] Recent cached data
- [ ] Stale cached data
- [ ] Real-device startup
- [ ] Real-device permission flow

## Quality validation

- [ ] Measure startup/perceived startup
- [ ] Measure location acquisition
- [ ] Measure weather fetch
- [ ] Verify no unnecessary location/background work
- [ ] Test on real iPhone
- [ ] Test slow network
- [ ] Test denied permissions
- [ ] Test app relaunch
- [ ] Test forecast changes
- [ ] Test App Store/TestFlight build

## Explicit rule

Do not mark a decision/tuning item complete by making an assumption. Ask for approval when the choice materially affects product behavior.
