import Foundation
import UIKit

class MediaStorageService {
    static let shared = MediaStorageService()
    
    private let fileManager = FileManager.default
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private var mediaDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("ExerciseMedia", isDirectory: true)
        if !fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                print("Error creating media directory: \(error)")
            }
        }
        return url
    }
    
    private init() {}
    
    /// Speichert ein UIImage und gibt den relativen Dateinamen zurück
    func saveImage(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        
        let fileName = UUID().uuidString + ".jpg"
        let fileURL = mediaDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileName
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }
    
    /// Lädt ein UIImage anhand des relativen Dateinamens
    func loadImage(named fileName: String) -> UIImage? {
        let fileURL = mediaDirectory.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: fileURL)
            return UIImage(data: data)
        } catch {
            print("Error loading image \(fileName): \(error)")
            return nil
        }
    }
    
    /// Löscht eine Mediendatei
    func deleteMedia(named fileName: String) {
        let fileURL = mediaDirectory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                try fileManager.removeItem(at: fileURL)
            } catch {
                print("Error deleting media \(fileName): \(error)")
            }
        }
    }
}
