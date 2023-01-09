//
//  RootViewModel.swift
//  AllTrailsAtLunch
//
//  Created by Sam Vanderhyden on 1/6/23.
//

import Combine
import CoreLocation
import Foundation
import os.log

final class RootViewModel {
    
    enum ViewState {
        case list
        case map
    }
    
    private let searchService: PlaceSearchService
    private let locationService: LocationService
    
    init(searchService: PlaceSearchService, locationService: LocationService) {
        self.searchService = searchService
        self.locationService = locationService
    }
    
    @Published private(set) var results: [Place] = [] {
        didSet {
            mapViewModel.results = results
            listViewModel.results = results
        }
    }
    @Published var isLoading: Bool = false
    @Published var viewState: ViewState = .list
    
    let mapViewModel = MapViewModel()
    let listViewModel = ListViewModel()
    
    private var cancellables = Set<AnyCancellable>()
    private var radius: CLLocationDistance = 1000
    
    @Published private var currentLocation: CLLocationCoordinate2D?
    
    // MARK: - Lifecycle
    
    func didLoad() {
        locationService.locationStatus.sink { [weak self] status in
            switch status {
            case .authorizing, .loading, .initial:
                self?.isLoading = true
            case .authorized(let location):
                self?.currentLocation = location
            case .notAuthorized:
                // TODO: Error handling
                Logger.appDefault.log(level: .info, "Error getting location: User has not authorized location services")
            case .failed(let error):
                Logger.appDefault.log(level: .error, "Error getting location: \(error)")
                // TODO: Error handling
            }
        }
        .store(in: &cancellables)
        
        $currentLocation.compactMap { $0 }.sink { [weak self] location in
            guard let self = self else {
                return
            }
            
            if self.results.isEmpty {
                self.searchForNearbyRestaurants(location)
            }
        }
        .store(in: &cancellables)
    }
    
    func willAppear() {
        if currentLocation == nil {
            locationService.fetchCurrentLocation()
        }
    }
    
    // MARK: - Actions
    
    func didTapViewMode() {
        switch viewState {
        case .map:
            viewState = .list
        case .list:
            viewState = .map
        }
    }
        
    // MARK: -
    
    private func searchForNearbyRestaurants(_ location: CLLocationCoordinate2D) {
        searchService.fetchNearbyRestaurants(location: location, radius: radius, keyword: nil).sink { [weak self] result in
            switch result {
            case .success(let response):
                self?.results = response.results
            case .failure(let error):
                Logger.appDefault.log(level: .error, "Error retrieving search results: \(error)")
                // TODO: Error handling
            }
            self?.isLoading = false
        }
        .store(in: &cancellables)
    }
}


// MARK: - Strings

extension RootViewModel {
        
    var title: String {
        // TODO: Localize this
        return "AllTrails At Lunch"
    }
    
    var listButtonTitle: String {
        // TODO: Localize this
        return "List"
    }
    
    var mapButtonTitle: String {
        // TODO: Localize this
        return "Map"
    }
    
}
