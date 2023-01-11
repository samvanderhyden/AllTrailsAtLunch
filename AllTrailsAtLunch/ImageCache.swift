//
//  ImageCache.swift
//  AllTrailsAtLunch
//
//  Created by Sam Vanderhyden on 1/11/23.
//

import Combine
import CryptoKit
import Foundation
import UIKit
import os.log

protocol ImageCacheKey: AnyObject {
    var fileName: String { get }
}

/// A cache key for photo reference and width combo
class PhotoReferenceKey: NSObject, ImageCacheKey {
    private let photoReference: String
    private let width: String
    
    init(photoReference: String, width: CGFloat) {
        self.photoReference = photoReference
        self.width = String(Int(width))
    }
    
    var fileName: String {
        return "\(photoReference)_\(width)"
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? PhotoReferenceKey else { return false }
        return object.photoReference == self.photoReference && object.width == self.width
    }
    
    override var hash: Int {
        return photoReference.hash ^ String(width).hash
    }
}

/// A basic in memory and disk cache
class ImageCache<T> where T: ImageCacheKey {
    
    private let memoryCache = NSCache<T, UIImage>()
    private let diskCacheQueue = DispatchQueue(label: "alltrailsatlunch.diskcache")
    
    init(maxImages: Int) {
        memoryCache.countLimit = maxImages
    }
    
    /// Insert an image into the cache
    func insertImage(image: UIImage, forKey key: T) {
        memoryCache.setObject(image, forKey: key)
        diskCacheQueue.async {
            self.writeImageToDiskSync(image: image, key: key)
        }
    }
    
    /// Get an image from the cache given a url
    func imageForKey(_ key: T, completion: @escaping (UIImage?) -> Void) {
        if let image = memoryCache.object(forKey: key) {
            completion(image)
        }
        diskCacheQueue.async {
            let image = self.readImageFromDiskSync(forKey: key)
            if let image = image {
                self.memoryCache.setObject(image, forKey: key)
            }
            completion(image)
        }
    }
    
    private func writeImageToDiskSync(image: UIImage, key: T) {
        do {
            let cacheFolder = try self.cacheFolder()
            let filePath = cacheFolder.appendingPathComponent(key.fileName)
            if FileManager.default.fileExists(atPath: filePath.path) {
                try FileManager.default.removeItem(at: filePath)
            }
            try image.pngData()?.write(to: filePath)
        } catch let error {
            Logger.appDefault.error("Error writing image to disk: \(error)")
        }
    }
    
    private func readImageFromDiskSync(forKey key: T) -> UIImage? {
        do {
            let cacheFolder = try self.cacheFolder()
            let filePath = cacheFolder.appendingPathComponent(key.fileName)
            return UIImage(contentsOfFile: filePath.path)
        } catch let error {
            Logger.appDefault.error("Error reading image from disk: \(error)")
            return nil
        }
    }
    
    private func cacheFolder() throws -> URL {
        return try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    }
}

extension ImageCache {
    /// A publisher interface to retrieving a image from the cache
    func imageForKey(_ key: T) -> AnyPublisher<UIImage?, Never> {
        Future({ promise in
            self.imageForKey(key) { image in
                promise(.success(image))
            }
        })
        .eraseToAnyPublisher()
    }
}
