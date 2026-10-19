import XCTest
@testable import Skovader

/// F6: hämta vid start och neddragning, cache i en timme, offline med
/// senaste cachen. F9: ort när platstillstånd saknas.
final class WeatherStoreTests: XCTestCase {
    let now = stockholmDate(2026, 10, 19, 8, 0)
    let bergen = Place(name: "Bergen", coordinate: Coordinate(latitude: 60.39, longitude: 5.32))

    @MainActor
    func makeStore(
        cached: WeatherForecast? = nil,
        result: Result<WeatherForecast, Error>? = nil,
        location: FakeLocation? = nil
    ) throws -> (WeatherStore, FakeWeatherService, WeatherCache) {
        let location = location ?? FakeLocation()
        let cache = makeTemporaryWeatherCache()
        addTeardownBlock { try? FileManager.default.removeItem(at: cache.fileURL.deletingLastPathComponent()) }
        if let cached { try cache.save(cached) }
        let fresh = makeForecast(fetchedAt: now, day: now, temperature: 4)
        let service = FakeWeatherService(result: result ?? .success(fresh))
        let fixedNow = now
        let store = WeatherStore(service: service, location: location, cache: cache, now: { fixedNow })
        return (store, service, cache)
    }

    @MainActor
    func testFirstStartFetchesAndSavesToCache() async throws {
        let (store, service, cache) = try makeStore()

        await store.refresh(preference: .automatic)

        XCTAssertEqual(service.requested, [testCoordinate])
        XCTAssertEqual(store.forecast?.fetchedAt, now)
        XCTAssertEqual(cache.load(), store.forecast)
        XCTAssertNil(store.problem)
        XCTAssertEqual(store.dayWeather()?.feelsLikeMin, 4)
    }

    @MainActor
    func testCacheYoungerThanAnHourIsUsedWithoutFetching() async throws {
        let cached = makeForecast(fetchedAt: now.addingTimeInterval(-50 * 60), day: now)
        let (store, service, _) = try makeStore(cached: cached)

        await store.refresh(preference: .automatic)

        XCTAssertEqual(service.requested, [])
        XCTAssertEqual(store.forecast, cached)
    }

    @MainActor
    func testCacheOlderThanAnHourIsRefetched() async throws {
        let cached = makeForecast(fetchedAt: now.addingTimeInterval(-61 * 60), day: now)
        let (store, service, _) = try makeStore(cached: cached)

        await store.refresh(preference: .automatic)

        XCTAssertEqual(service.requested.count, 1)
        XCTAssertEqual(store.forecast?.fetchedAt, now)
    }

    @MainActor
    func testPullToRefreshAlwaysFetches() async throws {
        let cached = makeForecast(fetchedAt: now.addingTimeInterval(-5 * 60), day: now)
        let (store, service, _) = try makeStore(cached: cached)

        await store.refresh(preference: .automatic, force: true)

        XCTAssertEqual(service.requested.count, 1)
    }

    @MainActor
    func testCacheForAnotherPlaceIsRefetched() async throws {
        let cached = makeForecast(fetchedAt: now.addingTimeInterval(-5 * 60), day: now)
        let (store, service, _) = try makeStore(cached: cached)

        await store.refresh(preference: .manual(bergen))

        XCTAssertEqual(service.requested, [bergen.coordinate])
    }

    @MainActor
    func testCacheFromYesterdayIsRefetchedEvenIfRecent() async throws {
        let yesterday = stockholmDate(2026, 10, 18, 12)
        let cached = makeForecast(fetchedAt: now.addingTimeInterval(-30 * 60), day: yesterday)
        let (store, service, _) = try makeStore(cached: cached)

        await store.refresh(preference: .automatic)

        XCTAssertEqual(service.requested.count, 1)
    }

    @MainActor
    func testOfflineShowsLatestCacheAndSaysSo() async throws {
        let cached = makeForecast(fetchedAt: now.addingTimeInterval(-3 * 60 * 60), day: now)
        let (store, _, _) = try makeStore(cached: cached, result: .failure(TestError()))

        await store.refresh(preference: .automatic)

        XCTAssertEqual(store.forecast, cached)
        XCTAssertEqual(store.problem, .offline)
        XCTAssertNotNil(store.dayWeather())
    }

    @MainActor
    func testOfflineWithoutCache() async throws {
        let (store, _, _) = try makeStore(result: .failure(TestError()))

        await store.refresh(preference: .automatic)

        XCTAssertNil(store.forecast)
        XCTAssertEqual(store.problem, .noForecast)
    }

    @MainActor
    func testNeverPromptsForLocationOnItsOwn() async throws {
        let location = FakeLocation(authorization: .notDetermined)
        let (store, service, _) = try makeStore(location: location)

        await store.refresh(preference: .automatic)

        XCTAssertEqual(location.authorizationRequests, 0)
        XCTAssertEqual(service.requested, [])
        XCTAssertEqual(store.problem, .needsLocationPermission)
    }

    @MainActor
    func testDeniedLocationAsksForPlace() async throws {
        let (store, service, _) = try makeStore(location: FakeLocation(authorization: .denied))

        await store.refresh(preference: .automatic)

        XCTAssertEqual(service.requested, [])
        XCTAssertEqual(store.problem, .needsPlace)
        XCTAssertTrue(store.isLocationDenied)
    }

    @MainActor
    func testManualPlaceWorksWithoutLocationPermission() async throws {
        let (store, service, _) = try makeStore(location: FakeLocation(authorization: .denied))

        await store.refresh(preference: .manual(bergen))

        XCTAssertEqual(service.requested, [bergen.coordinate])
        XCTAssertNil(store.problem)
    }

    @MainActor
    func testManualModeWithoutPlaceAsksForPlace() async throws {
        let (store, service, _) = try makeStore()

        await store.refresh(preference: .manual(nil))

        XCTAssertEqual(service.requested, [])
        XCTAssertEqual(store.problem, .needsPlace)
    }

    @MainActor
    func testLocationFailureFallsBackToLastPosition() async throws {
        let cached = makeForecast(fetchedAt: now.addingTimeInterval(-2 * 60 * 60), day: now)
        let (store, service, _) = try makeStore(cached: cached, location: FakeLocation(coordinate: nil))

        await store.refresh(preference: .automatic)

        XCTAssertEqual(service.requested, [testCoordinate])
    }

    @MainActor
    func testLocationFailureWithoutCache() async throws {
        let (store, _, _) = try makeStore(location: FakeLocation(coordinate: nil))

        await store.refresh(preference: .automatic)

        XCTAssertEqual(store.problem, .locationUnavailable)
    }
}
