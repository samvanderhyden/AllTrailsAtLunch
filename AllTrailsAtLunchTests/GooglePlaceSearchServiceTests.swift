//
//  GooglePlaceSearchServiceTests.swift
//  AllTrailsAtLunchTests
//
//  Created by Sam Vanderhyden on 1/6/23.
//

import XCTest
import Combine
@testable import AllTrailsAtLunch

class GooglePlaceSearchServiceTests: XCTestCase {
    
    private var cancellables = Set<AnyCancellable>()
        
    override func setUp() {
        cancellables = []
    }
    
    /// Verify success response from OK status
    func testPlaceServiceStatusOK() {
        let jsonFixture =
"""
{
  "html_attributions": [],
  "results": [],
  "status": "OK",
}

"""
        let expectation = self.expectation(description: "Received service result")
        let service = serviceWithFixture(jsonFixture)
        service.fetchNearbyRestaurants(location: .init(latitude: 0, longitude: 0), radius: 0, keyword: nil).sink { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            }
            expectation.fulfill()
        }
        .store(in: &cancellables)
        waitForExpectations(timeout: 2)
    }
    
    
    /// Verify failure response from invalid request status
    func testPlaceServiceStatusInvalidRequest() {
        let jsonFixture =
"""
{
  "html_attributions": [],
  "results": [],
  "status": "INVALID_REQUEST",
}

"""
        let expectation = self.expectation(description: "Received service result")
        let service = serviceWithFixture(jsonFixture)
        service.fetchNearbyRestaurants(location: .init(latitude: 0, longitude: 0), radius: 0, keyword: nil).sink { result in
            switch result {
            case .success:
                XCTFail("Unexpected success response with invalid request status")
            case .failure(let error):
                switch error {
                case .invalidRequestError:
                    break
                default:
                    XCTFail("Unexpected error type: \(error)")
                }
            }
            expectation.fulfill()
        }
        .store(in: &cancellables)
        waitForExpectations(timeout: 2)
    }
    
    // TODO: With more time I'd add tests for all the possible statuses
    
    private func serviceWithFixture(_ fixture: String) -> GooglePlaceSearchService {
        GooglePlaceSearchService { _ in
            return Just(fixture.data(using: .utf8) ?? Data()).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
    }
    
    
    // This test was used to develop the place service and verify that it can successfully return data from the API.
    // I'm leaving it here (commented out) as a demonstration of how I develop a service and integrate with an API. I would not include a test like this in a production environment.

//    func testPlaceServiceNetwork() {
//        let service = GooglePlaceSearchService()
//        let expectation = self.expectation(description: "Received service result")
//        service.fetchNearbyRestaurants(location: .init(latitude: 40.220999116, longitude: -105.267998928), radius: 1000.0, keyword: nil).sink { result in
//
//            switch result {
//            case .success(let response):
//                XCTAssert(response.results.count > 0)
//            case .failure(let error):
//                XCTFail("Unexpected error: \(error)")
//            }
//            expectation.fulfill()
//        }
//        .store(in: &cancellables)
//        waitForExpectations(timeout: 2)
//    }
}
