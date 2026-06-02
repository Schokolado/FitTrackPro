import Foundation

enum FoodAPIError: Error {
    case notFound
    case networkError
    case decodingError
}

struct OFFNutriments: Decodable {
    let energyKcal100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?
    
    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
    }
}

struct OFFProduct: Decodable, Identifiable {
    let id = UUID()
    let productName: String?
    let nutriments: OFFNutriments?
    
    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case nutriments
    }
}

struct OFFResponse: Decodable {
    let product: OFFProduct?
    let status: Int
}

struct OFFSearchResponse: Decodable {
    let count: Int?
    let page: Int?
    let products: [OFFProduct]?
}

#if DEBUG
class SSLBypassDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
#endif

actor FoodAPIService {
    private let session: URLSession
    
    init() {
        #if DEBUG
        self.session = URLSession(configuration: .default, delegate: SSLBypassDelegate(), delegateQueue: nil)
        #else
        self.session = URLSession.shared
        #endif
    }
    func fetchProduct(barcode: String) async throws -> OFFProduct? {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v0/product/\(barcode).json") else {
            throw FoodAPIError.networkError
        }
        
        var request = URLRequest(url: url)
        request.setValue("FitTrackPro - iOS - Version 1.0 - OpenSourceApp", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw FoodAPIError.networkError
            }
            
            let decoder = JSONDecoder()
            let decodedResponse = try decoder.decode(OFFResponse.self, from: data)
            
            if decodedResponse.status != 1 || decodedResponse.product == nil {
                throw FoodAPIError.notFound
            }
            
            return decodedResponse.product
        } catch let error as DecodingError {
            print("Decoding error: \(error)")
            throw FoodAPIError.decodingError
        } catch {
            print("Network error: \(error)")
            throw FoodAPIError.networkError
        }
    }
    
    func searchProducts(query: String) async throws -> [OFFProduct] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/search?search_terms=\(encodedQuery)&fields=code,product_name,nutriments") else {
            throw FoodAPIError.networkError
        }
        
        var request = URLRequest(url: url)
        request.setValue("FitTrackPro - iOS - Version 1.0 - OpenSourceApp", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw FoodAPIError.networkError
            }
            
            let decoder = JSONDecoder()
            let decodedResponse = try decoder.decode(OFFSearchResponse.self, from: data)
            
            // Filter out products without a name
            return decodedResponse.products?.filter { $0.productName?.isEmpty == false } ?? []
        } catch let error as DecodingError {
            print("Decoding error: \(error)")
            throw FoodAPIError.decodingError
        } catch {
            print("Network error: \(error)")
            throw FoodAPIError.networkError
        }
    }
}
