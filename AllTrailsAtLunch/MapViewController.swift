//
//  MapViewController.swift
//  AllTrailsAtLunch
//
//  Created by Sam Vanderhyden on 1/9/23.
//

import Combine
import Foundation
import UIKit
import MapKit

final class MapViewController: UIViewController {
    
    private var cancellables = Set<AnyCancellable>()

    private let viewModel: MapViewModel
    private let mapView: MKMapView = {
        let mapView = MKMapView()
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return mapView
    }()
    
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
        mapView.frame = view.bounds
        view.addSubview(mapView)
        
        mapView.register(PlaceAnnotationView.self, forAnnotationViewWithReuseIdentifier: PlaceMapItem.reuseIdentifier)
        mapView.delegate = self
        mapView.showsUserLocation = true
        
        var previousItems: [PlaceMapItem]?
        viewModel.$results.receive(on: DispatchQueue.main).sink { [weak self] items in
            guard let self = self else { return }
            if let previousItems = previousItems {
                self.mapView.removeAnnotations(previousItems)
            }
            self.mapView.addAnnotations(items)
            previousItems = items
        }
        .store(in: &cancellables)
        
        viewModel.mapFrameSubject.receive(on: DispatchQueue.main).sink { [weak self] rect in
            guard let self = self else { return }
            let mapRect = self.mapView.mapRectThatFits(rect, edgePadding: UIEdgeInsets(top: 32, left: 32, bottom: 32, right: 32))
            self.mapView.setVisibleMapRect(mapRect, animated: false)
        }
        .store(in: &cancellables)
        
    }
}


// MARK: - MKMapViewDelegate

extension MapViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
        guard let annotation = annotation as? PlaceMapItem else { return }
        guard let listItem = annotation.listItem else { return }
        guard let annotationView = mapView.view(for: annotation) as? PlaceAnnotationView else { return }
        guard let detailView = annotationView.detailCalloutAccessoryView as? PlaceItemContentView else { return }
        let size = detailView.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        guard let imagePublisher = viewModel.loadPhotoForItem(listItem, width: size.height) else { return }
        detailView.loadImageThumbnail(publisher: imagePublisher)
        
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapCallout(_:)))
        detailView.addGestureRecognizer(gestureRecognizer)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is PlaceMapItem {
            let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: PlaceMapItem.reuseIdentifier, for: annotation)
            annotationView.annotation = annotation
            return annotationView
        } else {
            return nil
        }
    }
        
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        // TODO: If I had more time, I'd call back to the view model to initiate a new search and add more places as annotations
    }
    
    @objc private func didTapCallout(_ sender: Any) {
        guard let sender = sender as? UIGestureRecognizer else { return }
        guard let view = sender.view as? PlaceItemContentView else { return }
        guard let configuration = view.configuration as? PlaceItemContentConfiguration else { return }
        let detailViewModel = viewModel.detailViewModelForItem(configuration.item)
        let detailViewController = PlaceDetailViewController(viewModel: detailViewModel)
        self.navigationController?.pushViewController(detailViewController, animated: true)
    }
}

// MARK: -

private class PlaceAnnotationView: MKMarkerAnnotationView {
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        configureDetailView()
        canShowCallout = true
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var annotation: MKAnnotation? {
        didSet {
            configureDetailView()
        }
    }
    
    private func configureDetailView() {
        guard let placeMapItem = annotation as? PlaceMapItem, let placeListItem = placeMapItem.listItem else {
            return
        }
        
        let placeConfiguration = PlaceItemContentConfiguration(item: placeListItem, contentInsets: .zero, showShadow: false)
        let placeDetailView = PlaceItemContentView(currentConfiguration: placeConfiguration)
        
        let targetWidth: CGFloat = UIScreen.main.bounds.width * 0.9
        let size = placeDetailView.sizeThatFits(CGSize(width: targetWidth, height: CGFloat.greatestFiniteMagnitude))

        placeDetailView.translatesAutoresizingMaskIntoConstraints = false
        // TODO: there is a bug here where the place detail view's contents can overflow the popover bounds. With more time I'd fix this.
        
        NSLayoutConstraint.activate([
            placeDetailView.widthAnchor.constraint(equalToConstant: size.width),
            placeDetailView.heightAnchor.constraint(equalToConstant: size.height)
        ])
        
        self.detailCalloutAccessoryView = placeDetailView
    }
    
}
