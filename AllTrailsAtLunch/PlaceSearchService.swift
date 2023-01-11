//
//  PlaceSearchService.swift
//  AllTrailsAtLunch
//
//  Created by Sam Vanderhyden on 1/5/23.
//

import Foundation
import CoreLocation
import Combine
import UIKit

enum PlaceSearchError: Error {
    case urlConstructionError
    case invalidRequestError
    case overQueryLimitError
    case requestDeniedError
    case unknownError
    case urlSessionError(Error)
    case imageDecodeError
}

struct PlaceSearchResponse {
    let results: [Place]
    let attributions: [String]
    let nextPageToken: String?
    let request: Request

    enum Request {
        case textSearch(keyword: String)
        case location(location: CLLocationCoordinate2D, radius: CLLocationDistance)
    }
}

protocol PlaceSearchService {
    func fetchNearbyRestaurants(location: CLLocationCoordinate2D, radius: CLLocationDistance, keyword: String?) -> AnyPublisher<Result<PlaceSearchResponse, PlaceSearchError>, Never>
    
    func fetchPhoto(maxWidth: CGFloat, reference: String) -> AnyPublisher<Result<UIImage, PlaceSearchError>, Never>

    func searchRestaurants(keyword: String) -> AnyPublisher<Result<PlaceSearchResponse, PlaceSearchError>, Never>
}

final class GooglePlaceSearchService: PlaceSearchService {
    
    private struct GooglePlaceSearchResponse: Decodable {
        
        // An improvement here might be to implement decoding and check for an
        // unrecognized status value and default to `unknownError` if so
        enum Status: String, Decodable {
            case ok = "OK"
            case zeroResults = "ZERO_RESULTS"
            case invalidRequest = "INVALID_REQUEST"
            case overQueryLimit = "OVER_QUERY_LIMIT"
            case requestDenied = "REQUEST_DENIED"
            case unknownError = "UNKNOWN_ERROR"
        }
        
        let results: [Place]
        let errorMessage: String?
        let infoMessage: [String]?
        let nextPageToken: String?
        let status: Status
        let htmlAttributions: [String]
    }
    
    typealias DataProvider = (URL) -> AnyPublisher<Data, Error>
    private let dataProvider: DataProvider
    
    init(_ dataProvider: DataProvider? = nil) {
        self.dataProvider = dataProvider ?? { url in
            URLSession.shared.dataTaskPublisher(for: url)
                .mapError { $0 as Error }
                .map { $0.data }
                .eraseToAnyPublisher()
        }
    }
    
    func fetchNearbyRestaurants(location: CLLocationCoordinate2D, radius: CLLocationDistance, keyword: String?) -> AnyPublisher<Result<PlaceSearchResponse, PlaceSearchError>, Never> {
        let endpoint = GooglePlaceAPIEndpoint.nearbySearch(location: location, radius: radius, keyword: keyword, type: "restaurant")
        
        guard let url = endpoint.url else {
            return Just(Result.failure(PlaceSearchError.urlConstructionError)).eraseToAnyPublisher()
        }
        
        return executeApiRequest(url: url, request: .location(location: location, radius: radius))
    }
    
    func searchRestaurants(keyword: String) -> AnyPublisher<Result<PlaceSearchResponse, PlaceSearchError>, Never> {
        let endpoint = GooglePlaceAPIEndpoint.textSearch(keyword: keyword, type: "restaurant")
        
        guard let url = endpoint.url else {
            return Just(Result.failure(PlaceSearchError.urlConstructionError)).eraseToAnyPublisher()
        }
        
        return executeApiRequest(url: url, request: .textSearch(keyword: keyword))
    }
    
    private func executeApiRequest(url: URL, request: PlaceSearchResponse.Request) -> AnyPublisher<Result<PlaceSearchResponse, PlaceSearchError>, Never> {
        return dataProvider(url)
            .decode(type: GooglePlaceSearchResponse.self, decoder: AllTrailsAtLunchJSONDecoder())
            .map { response -> Result<PlaceSearchResponse, PlaceSearchError> in
                switch response.status {
                case .ok, .zeroResults:
                    return .success(.init(results: response.results, attributions: response.htmlAttributions, nextPageToken: response.nextPageToken, request: request))
                case .invalidRequest:
                    return .failure(.invalidRequestError)
                case .overQueryLimit:
                    return .failure(.overQueryLimitError)
                case .requestDenied:
                    return .failure(.requestDeniedError)
                case .unknownError:
                    return .failure(.unknownError)
                }
            }
            .catch { error in
                Just(.failure(.urlSessionError(error)))
            }
            .eraseToAnyPublisher()
    }
    
    func fetchPhoto(maxWidth: CGFloat, reference: String) -> AnyPublisher<Result<UIImage, PlaceSearchError>, Never> {
        let endpoint = GooglePlaceAPIEndpoint.photo(maxWidth: maxWidth, reference: reference)
        guard let url = endpoint.url else {
            return Just(Result.failure(PlaceSearchError.urlConstructionError)).eraseToAnyPublisher()
        }
        // TODO: With more time, I would definitely cache the images, and possibly pre-render for the target size.
        return dataProvider(url)
            .map { data -> Result<UIImage, PlaceSearchError> in
                if let image = UIImage(data: data) {
                    return .success(image)
                } else {
                    return .failure(PlaceSearchError.imageDecodeError)
                }
            }
            .catch { error in
                Just(.failure(.urlSessionError(error)))
            }
            .eraseToAnyPublisher()
    }
}

private struct GooglePlaceAPIEndpoint {
    
    enum Action: String {
        case nearbySearch = "nearbysearch/json"
        case photo = "photo"
        case textSearch = "textsearch/json"
    }
    
    private static let host = "maps.googleapis.com"
    private static let basePath = "/maps/api/place/"
    private static let apiKey = "AIzaSyCqWHKkgLxJiSwS63bxfWpQ-XhSQs65H5c"
    
    let path: String
    let queryItems: [URLQueryItem]
    
    init(action: Action, params: [URLQueryItem]) {
        var params = params
        params.append(.init(name: "key", value: Self.apiKey))
        params.append(.init(name: "language", value: Locale.current.language.languageCode?.identifier))
        path = Self.basePath + action.rawValue
        queryItems = params
    }

    var url: URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Self.host
        components.path = path
        components.queryItems = queryItems
        return components.url
    }
}

private extension GooglePlaceAPIEndpoint {
    static func nearbySearch(location: CLLocationCoordinate2D, radius: CLLocationDistance, keyword: String?, type: String?) -> GooglePlaceAPIEndpoint {
        let locationParam = URLQueryItem(name: "location", value: "\(location.latitude),\(location.longitude)")
        let radiusParam = URLQueryItem(name: "radius", value: String(radius))
        var params = [locationParam, radiusParam]
        if let keyword = keyword {
            params.append(.init(name: "keyword", value: keyword))
        }
        if let type = type, type != keyword {
            params.append(.init(name: "type", value: type))
        }
        return GooglePlaceAPIEndpoint(action: .nearbySearch, params: params)
    }
    
    static func photo(maxWidth: CGFloat, reference: String) -> GooglePlaceAPIEndpoint {
        let photoReferenceParam = URLQueryItem(name: "photo_reference", value: reference)
        let maxWidthParam = URLQueryItem(name: "maxwidth", value: String(Int(maxWidth)))
        return GooglePlaceAPIEndpoint(action: .photo, params: [photoReferenceParam, maxWidthParam])
    }
    
    static func textSearch(keyword: String, type: String?) -> GooglePlaceAPIEndpoint {
        var params = [URLQueryItem(name: "query", value: keyword)]
        if let type = type, type != keyword {
            params.append(.init(name: "type", value: type))
        }
        return GooglePlaceAPIEndpoint(action: .textSearch, params: params)
    }
}
