//
//  Utils.swift
//  AllTrailsAtLunch
//
//  Created by Sam Vanderhyden on 1/5/23.
//

import CoreLocation
import Foundation
import os.log

/// Convenience subclass of JSONDecoder to set the key decoding strategy
class AllTrailsAtLunchJSONDecoder: JSONDecoder {
    override init() {
        super.init()
        keyDecodingStrategy = .convertFromSnakeCase
    }
}


extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "AllTrailsAtLunch"

    /// Default logging for AllTrailsAtLunch app
    static let appDefault = Logger(subsystem: subsystem, category: "default")
}
