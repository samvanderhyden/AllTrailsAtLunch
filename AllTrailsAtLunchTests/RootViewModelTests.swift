//
//  RootViewModelTests.swift
//  AllTrailsAtLunchTests
//
//  Created by Sam Vanderhyden on 1/9/23.
//

import Combine
import CoreLocation
import Foundation
import XCTest
@testable import AllTrailsAtLunch

class RootViewModelTests: XCTestCase {
    
    private var cancellables = Set<AnyCancellable>()
        
    override func setUp() {
        cancellables = []
    }
    
    private final class MockLocationService: LocationService {
        var locationStatus: AnyPublisher<AllTrailsAtLunch.LocationStatus, Never> {
            return Just(LocationStatus.authorized(location: .init(latitude: 0, longitude: 0))).eraseToAnyPublisher()
        }
        
        func fetchCurrentLocation() {
            // No op
        }
    }
    
    private final class MockPlaceSearchService: PlaceSearchService {
        func fetchNearbyRestaurants(location: CLLocationCoordinate2D, radius: CLLocationDistance, keyword: String?) -> AnyPublisher<Result<AllTrailsAtLunch.PlaceSearchResponse, AllTrailsAtLunch.PlaceSearchError>, Never> {
            let place = Place(name:"Test", geometry: .init(location: .init(lat: 0, lng: 0), viewport: .init(northeast: .init(lat: 0, lng: 0), southwest: .init(lat: 0, lng: 0))))
            let response = PlaceSearchResponse(results: [place], attributions: [], nextPageToken: nil, request: .location(location: location, radius: radius))
            return Just(.success(response)).eraseToAnyPublisher()
        }
        
        func fetchPhoto(maxWidth: CGFloat, reference: String) -> AnyPublisher<Result<UIImage, PlaceSearchError>, Never> {
            return Just(.failure(PlaceSearchError.imageDecodeError)).eraseToAnyPublisher()
        }
        
        func searchRestaurants(keyword: String) -> AnyPublisher<Result<PlaceSearchResponse, PlaceSearchError>, Never> {
            return Just(.failure(PlaceSearchError.unknownError)).eraseToAnyPublisher()
        }
    }
    
    /// Verify results are populated when willAppear is called for the first time
    func testResultsPopulatedOnAppear() {
        let viewModel = RootViewModel(searchService: MockPlaceSearchService(), locationService: MockLocationService())
        viewModel.didLoad()
        let expectation = self.expectation(description: "Results populated")
        viewModel.$results.sink { results in
            XCTAssertTrue(results.nearbyResults.count > 0, "Results were returned")
            expectation.fulfill()
        }
        .store(in: &cancellables)
        viewModel.willAppear()
        waitForExpectations(timeout: 2)
    }
    
    // TODO: Add more tests for view state transitions, error handling, etc ...
}
