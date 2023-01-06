//
//  LocationService.swift
//  AllTrailsAtLunch
//
//  Created by Sam Vanderhyden on 1/6/23.
//

import Foundation
import CoreLocation
import Combine

protocol LocationService {
    var locationStatus: AnyPublisher<LocationStatus, Never> { get }
    func fetchCurrentLocation()
}

enum LocationError: Error, Equatable {
    case locationNotAvailable
    case unknownError
}

enum LocationStatus: Equatable {
    case initial
    case authorizing
    case loading
    case authorized(location: CLLocationCoordinate2D)
    case failed(error: LocationError)
    case notAuthorized
}

final class CLLocationService: NSObject, LocationService, CLLocationManagerDelegate {
    
    @Published
    private var status: LocationStatus = .initial
    
    private lazy var locationManager: CLLocationManager = {
        let locationManager = CLLocationManager()
        locationManager.delegate = self
        return locationManager
    }()
    
    var locationStatus: AnyPublisher<LocationStatus, Never> {
        return $status.eraseToAnyPublisher()
    }
    
    func fetchCurrentLocation() {
        syncWithAuthorizationStatus(locationManager.authorizationStatus)
    }
    
    private func syncWithAuthorizationStatus(_ authorizationStatus: CLAuthorizationStatus) {
        switch authorizationStatus {
        case .notDetermined:
            if status != .authorizing {
                status = .authorizing
                locationManager.requestWhenInUseAuthorization()
            }
        case .restricted, .denied:
            status = .notAuthorized
        case .authorizedAlways ,.authorizedWhenInUse:
            if status != .notAuthorized && status != .loading {
                status = .loading
                locationManager.requestLocation()
            }
        @unknown default:
            status = .failed(error: .unknownError)
        }
    }
        
    // MARK: - CLLocationManagerDelegate
        
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        syncWithAuthorizationStatus(manager.authorizationStatus)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard status == .loading else {
            return
        }
        status = .failed(error: .locationNotAvailable)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            status = .authorized(location: location.coordinate)
        } else {
            status = .failed(error: .locationNotAvailable)
        }
    }
}
