//
//  RootViewController.swift
//  AllTrailsAtLunch
//
//  Created by Sam Vanderhyden on 1/4/23.
//

import Combine
import UIKit

final class RootViewController: UIViewController {

    private let viewModel: RootViewModel
    private var cancellables = Set<AnyCancellable>()
    
    private lazy var listViewController: ListViewController = {
        let listViewController = ListViewController(viewModel: viewModel.listViewModel)
        addChild(listViewController)
        listViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        listViewController.view.frame = view.bounds
        view.addSubview(listViewController.view)
        listViewController.didMove(toParent: self)
        return listViewController
    }()
    
    private lazy var mapViewController: MapViewController = {
        let mapViewController = MapViewController(viewModel: viewModel.mapViewModel)
        addChild(mapViewController)
        mapViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapViewController.view.frame = view.bounds
        view.addSubview(mapViewController.view)
        mapViewController.didMove(toParent: self)
        return mapViewController
    }()
    
    private lazy var viewModeButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.imagePadding = 8
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        configuration.baseBackgroundColor = UIColor(named: "actionColor")
        let button = UIButton(configuration: configuration)
        view.addSubview(button)
        button.addTarget(self, action: #selector(didTapViewModeButton(_:)), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.masksToBounds = true
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        return button
    }()
    
    init(viewModel: RootViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.didLoad()
        self.navigationItem.title = viewModel.title
        
        viewModel.$viewState.sink { [weak self] state in
            guard let self = self else { return }
            let viewControllerToShow: UIViewController
            let viewControllerToHide: UIViewController
            switch state {
            case .list:
                viewControllerToShow = self.listViewController
                viewControllerToHide = self.mapViewController
            case .map:
                viewControllerToShow = self.mapViewController
                viewControllerToHide = self.listViewController
            }
            self.showViewController(viewControllerToShow, hidingViewController: viewControllerToHide)
            self.configureViewModeButtonForState(state)
        }
        .store(in: &cancellables)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.willAppear()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        viewModeButton.layer.cornerRadius = viewModeButton.frame.height / 2
    }
    
    // MARK: -
    
    private func showViewController(_ viewController: UIViewController, hidingViewController viewControllerToHide: UIViewController) {
        viewControllerToHide.view.isHidden = true
        viewController.view.isHidden = false
    }
    
    @objc private func didTapViewModeButton(_ sender: Any) {
        viewModel.didTapViewMode()
    }
    
    private func configureViewModeButtonForState(_ viewState: RootViewModel.ViewState) {
        switch viewState {
        case .list:
            viewModeButton.setImage(UIImage(systemName: "map"), for: .normal)
            viewModeButton.setTitle(viewModel.mapButtonTitle, for: .normal)
        case .map:
            viewModeButton.setImage(UIImage(systemName: "list.bullet"), for: .normal)
            viewModeButton.setTitle(viewModel.listButtonTitle, for: .normal)
        }
    }
}
