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
    
    private enum Constants {
        // Default to 5 mile radius
        static let defaultRadius: CLLocationDistance = 8046.72
    }
    
    enum ViewState {
        case list
        case map
    }
    
    enum DataLoadingError: Error {
        case locationNotAuthorized
        case other
    }
    
    struct PlaceResults {
        var searchResults: [Place]
        var nearbyResults: [Place]
    }
    
    private let searchService: PlaceSearchService
    private let locationService: LocationService
    
    init(searchService: PlaceSearchService, locationService: LocationService) {
        self.searchService = searchService
        self.locationService = locationService
    }
    
    @Published private(set) var results: PlaceResults = .init(searchResults: [], nearbyResults: []) {
        didSet {
            mapViewModel.updateResults(results.nearbyResults)
            // Show search results in the list if we have them, but default to nearby if not
            let listResults = !results.searchResults.isEmpty || searchViewModel.isSearchBarActive ? results.searchResults : results.nearbyResults
            listViewModel.updateResults(listResults)
        }
    }
    
    @Published var isLoading: Bool = false {
        didSet {
            listViewModel.updateIsLoading(isLoading)
        }
    }
    
    @Published var viewState: ViewState = .list {
        didSet {
            if viewState == .map {
                // I made the decision to simplify here and not show search results on on the map
                // So when switching to map view, we will clear out the search results
                results.searchResults = []
                // TODO: Localize this
                searchBarQueryDescription = "Nearby"
            }
        }
    }
    
    @Published private(set) var searchBarQueryDescription: String?
    
    @Published private(set) var showViewModeButton: Bool = true
    
    private(set) lazy var mapViewModel = MapViewModel(searchService: searchService)
    private(set) lazy var listViewModel = ListViewModel(searchService: searchService)
    private(set) lazy var searchViewModel = SearchViewModel(searchService: searchService)
    
    private var cancellables = Set<AnyCancellable>()
    
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
                self.results.nearbyResults = []
                self.isLoading = false
                self.errorSubject.send(.locationNotAuthorized)
            case .failed(let error):
                Logger.appDefault.log(level: .error, "Error getting location: \(error)")
                self.results.nearbyResults = []
                self.isLoading = false
                self.errorSubject.send(.other)
            }
        }
        .store(in: &cancellables)
        
        
        searchViewModel.$results.sink { [weak self] results in
            guard let self = self else { return }
            self.results.searchResults = results
        }
        .store(in: &cancellables)
    }
    
    func willAppear() {
        if results.nearbyResults.isEmpty {
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
    
    func updateSearchBarActive(_ isActive: Bool) {
        searchViewModel.updateSearchBarActive(isActive)
        // Switch to list view when search bar is active
        if isActive {
            viewState = .list
        }
        
        // Show the view mode button when the search bar is not active
        showViewModeButton = !isActive
    }
    
    func didCancelSearch() {
        updateSearchBarActive(false)
        results.searchResults = []
    }
        
    // MARK: -
    
    private func searchForNearbyRestaurants(_ location: CLLocationCoordinate2D) {
        searchService.fetchNearbyRestaurants(location: location, radius: Constants.defaultRadius, keyword: nil).sink { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let response):
                self.results.nearbyResults = response.results
                // TODO: Localize
                self.searchBarQueryDescription = "Nearby"
            case .failure(let error):
                Logger.appDefault.log(level: .error, "Error retrieving search results: \(error)")
                self.results.nearbyResults = []
                self.errorSubject.send(.other)
            }
            self.isLoading = false
        }
        .store(in: &cancellables)
    }
}
