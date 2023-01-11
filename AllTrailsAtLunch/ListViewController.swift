//
//  ListViewController.swift
//  AllTrailsAtLunch
//
//  Created by Sam Vanderhyden on 1/9/23.
//

import Combine
import Foundation
import UIKit
import os.log

protocol ListViewControllerDelegate: AnyObject {
    func listViewDidScroll()
}

private enum Section {
    case places
}

private typealias DataSource = UICollectionViewDiffableDataSource<Section, PlaceListItem>
private typealias Snapshot = NSDiffableDataSourceSnapshot<Section, PlaceListItem>

final class ListViewController: UIViewController {
    
    weak var delegate: ListViewControllerDelegate?
    
    private let collectionViewLayout = UICollectionViewFlowLayout()
    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: collectionViewLayout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.delegate = self
        return collectionView
    }()
    
    private lazy var dataSource: DataSource = {
        let dataSource = DataSource(collectionView: collectionView) { [weak self] collectionView, indexPath, item in
            guard let self = self else { return nil }
            return collectionView.dequeueConfiguredReusableCell(using: self.cellRegistration, for: indexPath, item: item)
        }
        return dataSource
    }()
    
    private let emptyLoadingView = EmptyLoadingView()
    
    private let cellRegistration = UICollectionView.CellRegistration<UICollectionViewCell, PlaceListItem>{ cell, _, item in
        cell.contentConfiguration = PlaceItemContentConfiguration(item: item)
    }
    
    private let viewModel: ListViewModel
    private var cancellables = Set<AnyCancellable>()
    
    init(viewModel: ListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        emptyLoadingView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        emptyLoadingView.frame = view.bounds
        view.addSubview(emptyLoadingView)
        
        collectionView.backgroundColor = .clear
        view.addSubview(collectionView)
        collectionViewLayout.minimumLineSpacing = 0
                
        viewModel.$viewState.receive(on: DispatchQueue.main).sink(receiveValue: { [weak self] viewState in
            guard let self = self else { return }
            var items: [PlaceListItem] = []
            switch viewState {
            case .results(let results):
                items = results
            case .loading:
                self.emptyLoadingView.setLoading()
            case .empty:
                self.emptyLoadingView.setEmpty()
            }
            self.updateSnapshot(places: items)
            self.emptyLoadingView.isHidden = !(viewState.isEmpty || viewState.isLoading)
        }).store(in: &cancellables)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.collectionViewLayout.invalidateLayout()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.collectionViewLayout.invalidateLayout()
    }
    
    // MARK: -
    
    private func updateSnapshot(places: [PlaceListItem]) {
        var snapshot = Snapshot()
        snapshot.appendSections([.places])
        snapshot.appendItems(places)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - Flow layout delegate
extension ListViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let item = viewModel.itemAtIndexPath(indexPath) else { return .zero }
        let height = PlaceItemContentView.heightForItem(item, targetWidth: collectionView.frame.width)
        return CGSize(width: collectionView.bounds.width, height: height)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let contentView = cell.contentView as? PlaceItemContentView else { return }
        if let imagePublisher = viewModel.loadPhotoForItem(indexPath, width: contentView.bounds.height * UIScreen.main.scale) {
            contentView.loadImageThumbnail(publisher: imagePublisher)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let detailViewModel = viewModel.detailViewModelAtIndexPath(indexPath) {
            let detailViewController = PlaceDetailViewController(viewModel: detailViewModel)
            self.navigationController?.pushViewController(detailViewController, animated: true)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.isTracking {
            // Notify if the user scrolled the scroll view
            delegate?.listViewDidScroll()
        }
    }
}

// MARK: - Content View / Configuration

struct PlaceItemContentConfiguration: UIContentConfiguration, Equatable {
    
    let item: PlaceListItem
    var contentInsets: UIEdgeInsets
    var showShadow: Bool
    
    init(item: PlaceListItem, contentInsets: UIEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16), showShadow: Bool = true) {
        self.item = item
        self.contentInsets = contentInsets
        self.showShadow = showShadow
    }
    
    func makeContentView() -> UIView & UIContentView {
        PlaceItemContentView(currentConfiguration: self)
    }
    
    func updated(for state: UIConfigurationState) -> PlaceItemContentConfiguration {
        PlaceItemContentConfiguration(item: self.item)
    }
}


final class PlaceItemContentView: UIView, UIContentView {
    
    private static var prototypeView: PlaceItemContentView?
    static func heightForItem(_ item: PlaceListItem, targetWidth: CGFloat) -> CGFloat {
        // TODO: If I had more time, I'd add caching height keyed by item / width / traitCollection
        let prototypeView: PlaceItemContentView = prototypeView ?? PlaceItemContentView(currentConfiguration: .init(item: item))
        let size = prototypeView.sizeThatFits(CGSize(width: targetWidth, height: CGFloat.greatestFiniteMagnitude))
        return size.height
    }
    
    var configuration: UIContentConfiguration {
        get {
            currentConfiguration
        }
        set {
            guard let newConfiguration = newValue as? PlaceItemContentConfiguration else {
                return
            }
            currentConfiguration = newConfiguration
        }
    }
        
    private var currentConfiguration: PlaceItemContentConfiguration {
        didSet {
            updateConfiguration(currentConfiguration, oldConfiguration: oldValue)
        }
    }
    
    private let contentView = UIView()
    private let shadowView = UIView()
    private let nameLabel = UILabel()
    private let ratingLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let imageView = UIImageView()
    private let starImageView = UIImageView()
    private var imageCancellable: AnyCancellable?
    
    private func updateConfiguration(_ configuration: PlaceItemContentConfiguration, oldConfiguration: PlaceItemContentConfiguration?) {
        if configuration.item.id != oldConfiguration?.item.id {
            imageView.image = UIImage(systemName: "fork.knife")
            imageView.contentMode = .scaleAspectFit
        }

        if let nameFontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .title3).withSymbolicTraits(.traitBold) {
            nameLabel.font = UIFont(descriptor: nameFontDescriptor, size: 0)
        }
        nameLabel.text = configuration.item.name
        
        ratingLabel.font = UIFont.preferredFont(forTextStyle: .body)
        ratingLabel.text = configuration.item.ratingDescription
        
        descriptionLabel.font = UIFont.preferredFont(forTextStyle: .body)
        descriptionLabel.text = configuration.item.description

        shadowView.isHidden = !configuration.showShadow
        
        setNeedsLayout()
    }
    
    init(currentConfiguration: PlaceItemContentConfiguration) {
        self.currentConfiguration = currentConfiguration
        super.init(frame: .zero)
        addSubview(shadowView)
        shadowView.backgroundColor = .white
        shadowView.layer.cornerRadius = 16
        shadowView.layer.masksToBounds = false
        
        contentView.backgroundColor = .white
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true
        addSubview(contentView)
        
        contentView.addSubview(nameLabel)
        
        contentView.addSubview(imageView)
        imageView.tintColor = UIColor(named: "backgroundColor")
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = 8
        
        contentView.addSubview(starImageView)
        starImageView.tintColor = UIColor(named: "ratingStarColor")
        
        contentView.addSubview(ratingLabel)
        contentView.addSubview(descriptionLabel)
        starImageView.image = UIImage(systemName: "star.fill")
        
        shadowView.layer.shadowOpacity = 0.1
        shadowView.layer.shadowColor = UIColor.gray.cgColor
        shadowView.layer.shadowOffset = CGSize(width: 0, height: 2)
        shadowView.layer.shadowRadius = 2
        
        updateConfiguration(currentConfiguration, oldConfiguration: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        nameLabel.sizeToFit()
        descriptionLabel.sizeToFit()
        ratingLabel.sizeToFit()
        
        let descriptionHeight = descriptionLabel.frame.size.height > 0 ? descriptionLabel.frame.self.height : descriptionLabel.font.lineHeight
        
        var height = nameLabel.frame.height + ratingLabel.frame.height + descriptionHeight + 2
        height += currentConfiguration.contentInsets.top + currentConfiguration.contentInsets.bottom
        height += contentView.directionalLayoutMargins.top + contentView.directionalLayoutMargins.bottom
        return CGSize(width: size.width, height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        contentView.frame = bounds.inset(by: currentConfiguration.contentInsets)
        shadowView.frame = contentView.frame
        
        let imageHeight = contentView.frame.height - (contentView.directionalLayoutMargins.top + contentView.directionalLayoutMargins.bottom)
        imageView.frame = CGRect(x: contentView.directionalLayoutMargins.leading, y: contentView.directionalLayoutMargins.top, width: imageHeight, height: imageHeight)
        
        let remainingWidth = contentView.frame.width - imageView.frame.width - (contentView.directionalLayoutMargins.leading + 2 * contentView.directionalLayoutMargins.trailing)
        
        nameLabel.sizeToFit()
        nameLabel.frame = CGRect(x: imageView.frame.maxX + contentView.directionalLayoutMargins.leading, y: imageView.frame.minY, width: remainingWidth, height: nameLabel.frame.height)
        
        ratingLabel.sizeToFit()
        starImageView.frame = CGRect(x: nameLabel.frame.minX, y: nameLabel.frame.maxY, width: ratingLabel.frame.height, height: ratingLabel.frame.height)
        ratingLabel.frame = CGRect(x: starImageView.frame.maxX + 2, y: starImageView.frame.minY, width: remainingWidth - starImageView.frame.width - 2, height: ratingLabel.frame.height)
        
        descriptionLabel.sizeToFit()
        descriptionLabel.frame = CGRect(x: starImageView.frame.minX, y: starImageView.frame.maxY + 2, width: remainingWidth, height: descriptionLabel.frame.height)
    }
    
    func loadImageThumbnail(publisher: AnyPublisher<Result<UIImage, PlaceSearchError>, Never>) {
        imageCancellable = publisher.receive(on: DispatchQueue.main).sink { [weak self] result in
            switch result {
            case .success(let image):
                self?.imageView.contentMode = .scaleAspectFill
                self?.imageView.image = image
            case .failure(let error):
                Logger.appDefault.error("Error fetching employee thumbnail: \(error)")
            }
        }
    }
}

// MARK: - Empty / loading View

private class EmptyLoadingView: UIView {
    
    private let emptyLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        emptyLabel.textAlignment = .center
        emptyLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        emptyLabel.textColor = .darkGray
        emptyLabel.numberOfLines = 0
        // TODO: Localize this
        emptyLabel.text = "No restaurants found. Try a different area."
        addSubview(emptyLabel)
        addSubview(activityIndicator)
        
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            emptyLabel.widthAnchor.constraint(equalTo: widthAnchor),
            emptyLabel.bottomAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setLoading() {
        activityIndicator.startAnimating()
        activityIndicator.isHidden = false
        emptyLabel.isHidden = true
    }
    
    func setEmpty() {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        emptyLabel.isHidden = false
    }
}
