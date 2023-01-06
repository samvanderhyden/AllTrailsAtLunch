//
//  PlaceModelTests.swift
//  AllTrailsAtLunchTests
//
//  Created by Sam Vanderhyden on 1/5/23.
//

import Foundation
import XCTest
@testable import AllTrailsAtLunch

class PlaceModelTests: XCTestCase {
    
    /// Verify decoding place from JSON
    func testDecode() throws {
        let jsonFixture =
"""
      {
               "business_status" : "OPERATIONAL",
               "geometry" : {
                  "location" : {
                     "lat" : -33.8610777,
                     "lng" : 151.209921
                  },
                  "viewport" : {
                     "northeast" : {
                        "lat" : -33.85972787010726,
                        "lng" : 151.2112708298927
                     },
                     "southwest" : {
                        "lat" : -33.86242752989271,
                        "lng" : 151.2085711701072
                     }
                  }
               },
               "icon" : "https://maps.gstatic.com/mapfiles/place_api/icons/v1/png_71/restaurant-71.png",
               "icon_background_color" : "#FF9E67",
               "icon_mask_base_uri" : "https://maps.gstatic.com/mapfiles/place_api/icons/v2/restaurant_pinlet",
               "name" : "Harbour Bar and Restaurant - Circular Quay",
               "opening_hours" : {
                  "open_now" : false
               },
               "photos" : [
                  {
                     "height" : 3024,
                     "html_attributions" : [
      
                     ],
                     "photo_reference" : "ARywPAJYU37NY38BEiIgy3YqgOQSB2CY0GUVe6oj8EEZ7uZ58S5eLxW_t1cXkaArLaZnq5sLi2NH4TtEW9XI7M3Dnq7eFUOTI-2o82INCYwE7xN6E4frHDrhGklhJfBJk_wto37wPbwIN3C-DSr0Prpwa3w-wRY8gOswGdSKzhPrqmVtS4S6",
                     "width" : 4032
                  }
               ],
               "place_id" : "ChIJ-eQdS66vEmsRvh5Vx6UatuM",
               "plus_code" : {
                  "compound_code" : "46Q5+HX Sydney, New South Wales, Australia",
                  "global_code" : "4RRH46Q5+HX"
               },
               "rating" : 4.7,
               "reference" : "ChIJ-eQdS66vEmsRvh5Vx6UatuM",
               "scope" : "GOOGLE",
               "types" : [ "restaurant", "food", "point_of_interest", "establishment" ],
               "user_ratings_total" : 110,
               "vicinity" : "Circular Quay Wharf 6, Sydney"
            }
"""
        guard let data = jsonFixture.data(using: .utf8) else {
            XCTFail("Couldn't convert fixture to utf-8 data")
            return
        }
        
        let place = try AllTrailsAtLunchJSONDecoder().decode(Place.self, from: data)
        XCTAssertEqual(place.placeId, "ChIJ-eQdS66vEmsRvh5Vx6UatuM")
        XCTAssertEqual(place.rating, 4.7)
        XCTAssertEqual(place.name, "Harbour Bar and Restaurant - Circular Quay")
        XCTAssertEqual(place.photos?.count, 1)
        XCTAssertEqual(place.photos?.first?.photoReference, "ARywPAJYU37NY38BEiIgy3YqgOQSB2CY0GUVe6oj8EEZ7uZ58S5eLxW_t1cXkaArLaZnq5sLi2NH4TtEW9XI7M3Dnq7eFUOTI-2o82INCYwE7xN6E4frHDrhGklhJfBJk_wto37wPbwIN3C-DSr0Prpwa3w-wRY8gOswGdSKzhPrqmVtS4S6")
        XCTAssertEqual(place.businessStatus, .operational)
        XCTAssertEqual(place.location, .init(latitude: -33.8610777, longitude: 151.209921))
        XCTAssertEqual(place.userRatingsTotal, 110)
        XCTAssertEqual(place.openNow, false)
    }
    
    // Note: With more time I would add more test cases, such as attempting to decoding invalid JSON
    
}
