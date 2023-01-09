//
//  MapViewController.swift
//  AllTrailsAtLunch
//
//  Created by Sam Vanderhyden on 1/9/23.
//

import Foundation
import UIKit

final class MapViewController: UIViewController {
    
    private let viewModel: MapViewModel
    
    init(viewModel: MapViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
    }
    
    // TODO: Implement map view
}
