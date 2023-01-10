//
//  ListViewModel.swift
//  AllTrailsAtLunch
//
//  Created by Sam Vanderhyden on 1/6/23.
//

import Combine
import Foundation
import os.log
import UIKit

final class ListViewModel {
    
    enum ViewState {
        case loading
        case empty
        case results([PlaceListItem])
        
        var isLoading: Bool {
            switch self {
            case .loading:
                return true
            case .empty, .results:
                return false
            }
        }
        
        var isEmpty: Bool {
            switch self {
            case .empty:
                return true
            case .loading, .results:
                return false
            }
        }
    }
    
    @Published private(set) var viewState: ViewState = .loading
    private let searchService: PlaceSearchService
    
    init(searchService: PlaceSearchService) {
        self.searchService = searchService
    }
    
    func updateResults(_ places: [Place]) {
        let placesItems = places.compactMap(PlaceListItem.init)
        self.viewState = placesItems.count > 0 ? .results(placesItems) : .empty
    }
    
    func updateIsLoading(_ isLoading: Bool) {
        if isLoading && viewState.isEmpty {
            // Only transition to loading if we are in an empty state
            viewState = .loading
        }
    }
    
    func itemAtIndexPath(_ indexPath: IndexPath) -> PlaceListItem? {
        switch viewState {
        case .loading, .empty:
            assertionFailure("Logic error, item request while in loading or empty state")
            return nil
        case .results(let results):
            return results[indexPath.item]
        }
    }
    
    func loadPhotoForItem(_ indexPath: IndexPath, width: CGFloat) -> AnyPublisher<Result<UIImage, PlaceSearchError>, Never>? {
        guard let item = self.itemAtIndexPath(indexPath) else { return nil }
        guard let photoReference = item.thumbnailPhotoReference else { return nil }
        return searchService.fetchPhoto(maxWidth: width, reference: photoReference)
    }
    
    func detailViewModelAtIndexPath(_ indexPath: IndexPath) -> PlaceDetailViewModel? {
        guard let item = self.itemAtIndexPath(indexPath) else { return nil }
        return PlaceDetailViewModel(place: item.place)
    }
}

struct PlaceListItem: Hashable {
    
    static let numRatingsFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
    
    static let userRatingFormatter: NumberFormatter = {
       let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumIntegerDigits = 1
        formatter.minimumIntegerDigits = 1
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter
    }()
    
    var id: String
    var name: String
    var description: String
    var ratingDescription: String
    var thumbnailPhotoReference: String?
    let place: Place
    
    init?(place: Place) {
        guard let id = place.placeId else {
            Logger.appDefault.info("Skipping place `\(place.name ?? "")` without an id")
            return nil
        }
        self.id = id
        self.place = place
        
        // TODO: Localize the placeholder text
        self.name = place.name ?? "?"
        
        var descriptionComponents = [String]()
        if let priceLevel = place.priceLevel, priceLevel > 0 {
            // TODO: Localize this
            descriptionComponents.append((1...priceLevel).map({ _ in "$" }).joined())
        }
        if place.openNow {
            // TODO: Localize this
            descriptionComponents.append("Open Now")
        }
        
        self.description = descriptionComponents.joined(separator: " • ")
        
        // TODO: This should be localized into different string depending "review" pluralization
        self.ratingDescription = String(format: "\(Self.userRatingFormatter.string(from: NSNumber(value: place.rating ?? 0)) ?? "0") • \(Self.numRatingsFormatter.string(from: NSNumber(value: place.userRatingsTotal ?? 0)) ?? "0") review\(place.userRatingsTotal != 1 ? "s" : "")", place.rating ?? 0)
        
        self.thumbnailPhotoReference = place.photos?.first?.photoReference
    }
}
