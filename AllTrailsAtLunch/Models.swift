//
//  Models.swift
//  AllTrailsAtLunch
//
//  Created by Sam Vanderhyden on 1/5/23.
//

import CoreLocation
import Foundation

struct Place: Decodable, Hashable {
    
    struct Photo: Decodable, Hashable {
        let photoReference: String
        let htmlAttributions: [String]
    }
    
    struct Geometry: Decodable, Hashable {

        struct Location: Decodable, Hashable {
            let lat: Double
            let lng: Double
        }

        struct ViewPort: Decodable, Hashable {
            let northeast: Location
            let southwest: Location
        }
        
        let location: Location
        let viewport: ViewPort
    }
    
    struct OpeningHours: Decodable, Hashable {
        let openNow: Bool
    }
    
    // Note: A future improvement might be to add an `unknown` or `unrecognized` case to this enum and implement manual decoding, so that if other cases were added in the future, we could default to a known value (and call it out in the UI)
    enum BusinessStatus: String, Decodable, Hashable {
        case operational = "OPERATIONAL"
        case closedTemporarily = "CLOSED_TEMPORARILY"
        case closedPermanently = "CLOSED_PERMANENTLY"
    }
    
    let placeId: String?
    let name: String?
    let rating: Float?
    let photos: [Photo]?
    let businessStatus: BusinessStatus?
    let userRatingsTotal: Int?
    private let geometry: Geometry
    var location: CLLocationCoordinate2D {
        return .init(latitude: geometry.location.lat, longitude: geometry.location.lng)
    }
    private let currentOpeningHours: OpeningHours?
    private let openingHours: OpeningHours?
    var openNow: Bool {
        currentOpeningHours?.openNow ?? openingHours?.openNow ?? false
    }
    var priceLevel: Int?
    
    init(placeId: String? = nil, name: String? = nil, rating: Float? = nil, photos: [Photo]? = nil, businessStatus: BusinessStatus? = nil, geometry: Geometry, currentOpeningHours: OpeningHours? = nil, userRatingsTotal: Int? = nil, openingHours: OpeningHours?, priceLevel: Int? = nil) {
        self.placeId = placeId
        self.name = name
        self.rating = rating
        self.photos = photos
        self.businessStatus = businessStatus
        self.geometry = geometry
        self.userRatingsTotal = userRatingsTotal
        self.currentOpeningHours = currentOpeningHours
        self.openingHours = openingHours
        self.priceLevel = priceLevel
    }
}
