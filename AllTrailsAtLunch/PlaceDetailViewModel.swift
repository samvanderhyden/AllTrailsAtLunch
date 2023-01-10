//
//  PlaceDetailViewModel.swift
//  AllTrailsAtLunch
//
//  Created by Sam Vanderhyden on 1/10/23.
//

import Foundation

final class PlaceDetailViewModel {
    
    private let place: Place
    
    init(place: Place) {
        self.place = place
    }
    
    var title: String? {
        self.place.name
    }
    
}
