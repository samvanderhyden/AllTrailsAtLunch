//
//  SearchViewModel.swift
//  AllTrailsAtLunch
//
//  Created by Sam Vanderhyden on 1/11/23.
//

import Combine
import Foundation
import UIKit
import os.log


final class SearchViewModel: NSObject {
    
    private let searchService: PlaceSearchService
    private var cancellables = Set<AnyCancellable>()
    @Published private(set) var searchText: String?
    private(set) var isSearchBarActive = false
    
    @Published
    private(set) var results: [Place] = []
    
    init(searchService: PlaceSearchService) {
        self.searchService = searchService
        super.init()
        
        $searchText
            .compactMap { $0 }
            .debounce(for: 0.3, scheduler: DispatchQueue.main)
            .removeDuplicates()
            .drop(while: { [weak self] _ in self?.isSearchBarActive != true })
            .filter { $0.isEmpty == false }
            .map({ [searchService] (text: String) -> AnyPublisher<Result<PlaceSearchResponse, PlaceSearchError>, Never> in
                searchService.searchRestaurants(keyword: text)
            })
            .switchToLatest()
            .sink { [weak self] result in
                switch result {
                case .success(let response):
                    self?.results = response.results
                case .failure(let error):
                    Logger.appDefault.error("Error searching: \(error)")
                    // TODO: With more time, I'd add better error handling here
                }
            }
            .store(in: &cancellables)
    }
    
    func updateSearchBarActive(_ isActive: Bool) {
        isSearchBarActive = isActive
    }
}

extension SearchViewModel: UISearchResultsUpdating {
    
    func updateSearchResults(for searchController: UISearchController) {
        searchText = searchController.searchBar.text
    }
}
