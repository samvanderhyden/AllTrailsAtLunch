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
        listViewController.delegate = self
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
            button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 8)
        ])
        return button
    }()
    
    private lazy var searchController = UISearchController(searchResultsController: nil)
    private var keyboardHeight: CGFloat = 0
    
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
        view.backgroundColor = UIColor(named: "backgroundColor")
        viewModel.didLoad()
        // TODO: localize
        self.navigationItem.title = "AllTrails at Lunch"
        self.navigationItem.searchController = searchController
        styleNavigationBar()
        searchController.searchResultsUpdater = viewModel.searchViewModel
        searchController.delegate = self
        searchController.searchBar.delegate = self
        setupKeyboardBinding()
        
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
        
        viewModel.errorSubject.receive(on: DispatchQueue.main).sink { [weak self] error in
            self?.showErrorDialog(error: error)
        }
        .store(in: &cancellables)
        
        viewModel.$searchBarQueryDescription.receive(on: DispatchQueue.main).sink { text in
            self.searchController.searchBar.text = nil
            self.searchController.searchBar.placeholder = text
        }
        .store(in: &cancellables)
        
        viewModel.$showViewModeButton.sink { [weak self] show in
            self?.viewModeButton.isHidden = !show
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
        updateSafeAreaInsets()
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
            // TODO: Localize
            viewModeButton.setTitle("Map", for: .normal)
        case .map:
            viewModeButton.setImage(UIImage(systemName: "list.bullet"), for: .normal)
            // TODO: Localize
            viewModeButton.setTitle("List", for: .normal)
        }
    }
    
    private func updateSafeAreaInsets() {
        var additionalInsets = additionalSafeAreaInsets
        additionalInsets.bottom = keyboardHeight + viewModeButton.frame.height + 8
        self.additionalSafeAreaInsets = additionalInsets
    }
    
    private func showErrorDialog(error: RootViewModel.DataLoadingError) {
        let errorText: String
        // TODO: Localize this text
        switch error {
        case .locationNotAuthorized:
            errorText = "Location access not authorized. Please allow access to location services in settings."
        case .other:
            errorText = "An error occurred. Please try again."
        }
        
        let alert = UIAlertController(title: "Error", message: errorText, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in }))
        self.present(alert, animated: true, completion: nil)
    }
    
    private func styleNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white

        // Customizing our navigation bar
        navigationController?.navigationBar.tintColor = .black
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
    }
    
    private func setupKeyboardBinding() {
        NotificationCenter.default
            .publisher(for: UIApplication.keyboardWillShowNotification)
            .sink(receiveValue: { [weak self] notification in
                self?.handleKeyboardUpdate(with: notification)
            })
            .store(in: &cancellables)
        
        
        NotificationCenter.default
            .publisher(for: UIApplication.keyboardWillHideNotification)
            .sink(receiveValue: { [weak self] notification in
                self?.handleKeyboardUpdate(with: notification)
            })
            .store(in: &cancellables)
    }
    
    private func handleKeyboardUpdate(with notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        
        let keyboardFrame = self.view.convert(frame, from: nil)
        keyboardHeight = max(0, view.frame.maxY - view.safeAreaInsets.bottom - keyboardFrame.minY)
        updateSafeAreaInsets()
    }
}

// MARK: -

extension RootViewController: UISearchControllerDelegate {
    func didPresentSearchController(_ searchController: UISearchController) {
        viewModel.updateSearchBarActive(true)
    }
    
    func didDismissSearchController(_ searchController: UISearchController) {
        viewModel.updateSearchBarActive(false)
    }
}

extension RootViewController: UISearchBarDelegate {
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        viewModel.didCancelSearch()
    }
}

// MARK: -

extension RootViewController: ListViewControllerDelegate {
    
    func listViewDidScroll() {
        searchController.dismiss(animated: true)
        viewModel.updateSearchBarActive(false)
    }
    
}
