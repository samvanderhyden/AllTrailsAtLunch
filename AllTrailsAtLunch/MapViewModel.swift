//
//  MapViewModel.swift
//  AllTrailsAtLunch
//
//  Created by Sam Vanderhyden on 1/6/23.
//

import Combine
import Foundation
import MapKit

final class MapViewModel {
 
    func updateResults(_ places: [Place]) {
        let mapItems = places.compactMap(PlaceMapItem.init)
        results = mapItems
        if !hasFitMapFrame, !mapItems.isEmpty {
            let rect = MKMapRect(coordinates: mapItems.map { $0.coordinate })
            mapFrameSubject.send(rect)
            hasFitMapFrame = true
        }
    }
    
    @Published private(set) var results: [PlaceMapItem] = []
    let mapFrameSubject = PassthroughSubject<MKMapRect, Never>()
    
    private var hasFitMapFrame = false
    private let searchService: PlaceSearchService
    
    init(searchService: PlaceSearchService) {
        self.searchService = searchService
    }

    func loadPhotoForItem(_ item: PlaceListItem, width: CGFloat) -> AnyPublisher<Result<UIImage, PlaceSearchError>, Never>? {
        guard let photoReference = item.thumbnailPhotoReference else { return nil }
        return searchService.fetchPhoto(maxWidth: width, reference: photoReference)
    }
    
    func detailViewModelForItem(_ item: PlaceListItem) -> PlaceDetailViewModel {
        return PlaceDetailViewModel(place: item.place)
    }
}


class PlaceMapItem: NSObject {
    
    private let place: Place
    
    init(place: Place) {
        self.place = place
    }
    
    var listItem: PlaceListItem? {
        return .init(place: place)
    }
}

extension PlaceMapItem: MKAnnotation {
    
    static let reuseIdentifier = "PlaceMapItem"
    
    var coordinate: CLLocationCoordinate2D {
        return place.location
    }
}

private extension MKMapRect {
    init(coordinates: [CLLocationCoordinate2D]) {
        self = coordinates.map({ MKMapPoint($0) }).map({ MKMapRect(origin: $0, size: MKMapSize(width: 0, height: 0)) }).reduce(MKMapRect.null, { r1, r2 in return r1.union(r2) })
    }
}
