//
//  PlaceDetailViewController.swift
//  AllTrailsAtLunch
//
//  Created by Sam Vanderhyden on 1/10/23.
//

import Foundation
import UIKit

final class PlaceDetailViewController: UIViewController {
    
    private let viewModel: PlaceDetailViewModel
    
    init(viewModel: PlaceDetailViewModel) {
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
        self.navigationItem.title = viewModel.title
    }
    
    // TODO: With more time, I'd add a UI here to display basic place info on the details screen.
    // One option to get more detailed info without adding more fields to the place model, would be to add an additional api call to the place details endpoint to get extended info from there
}
