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
    
    enum DataLoadingError: Error {
        case locationNotAuthorized
        case other
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
            listViewModel.updateResults(results)
        }
    }
    @Published var isLoading: Bool = false {
        didSet {
            listViewModel.updateIsLoading(isLoading)
        }
    }
    @Published var viewState: ViewState = .list
    
    let mapViewModel = MapViewModel()
    let listViewModel = ListViewModel()
    
    private var cancellables = Set<AnyCancellable>()
    private var radius: CLLocationDistance = 1000
    
    /// Publishes an error when loading data or accessing location
    let errorSubject = PassthroughSubject<DataLoadingError, Never>()
        
    // MARK: - Lifecycle
    
    func didLoad() {
        locationService.locationStatus.sink { [weak self] status in
            guard let self = self else { return }
            switch status {
            case .authorizing, .loading, .initial:
                self.isLoading = true
            case .authorized(let location):
                self.searchForNearbyRestaurants(location)
            case .notAuthorized:
                // TODO: If I had more time I'd add a screen calling out to authorize location access in settings.
                Logger.appDefault.log(level: .info, "Error getting location: User has not authorized location services")
                self.results = []
                self.isLoading = false
                self.errorSubject.send(.locationNotAuthorized)
            case .failed(let error):
                Logger.appDefault.log(level: .error, "Error getting location: \(error)")
                self.results = []
                self.isLoading = false
                self.errorSubject.send(.other)
            }
        }
        .store(in: &cancellables)
    }
    
    func willAppear() {
        if results.isEmpty {
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
