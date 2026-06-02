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
    var productName: String?
    let nutriments: OFFNutriments?
    
    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case productNameDe = "product_name_de"
        case productNameEn = "product_name_en"
        case nutriments
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.nutriments = try container.decodeIfPresent(OFFNutriments.self, forKey: .nutriments)
        
        if let name = try container.decodeIfPresent(String.self, forKey: .productName) {
            self.productName = name
        } else if let nameDe = try container.decodeIfPresent(String.self, forKey: .productNameDe) {
            self.productName = nameDe
        } else if let nameEn = try container.decodeIfPresent(String.self, forKey: .productNameEn) {
            self.productName = nameEn
        }
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
    let hits: [OFFProduct]?
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
              let url = URL(string: "https://search.openfoodfacts.org/search?q=\(encodedQuery)") else {
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
            
            let productsList = decodedResponse.hits ?? decodedResponse.products ?? []
            // Filter out products without a name
            return productsList.filter { $0.productName?.isEmpty == false }
        } catch let error as DecodingError {
            print("Decoding error: \(error)")
            throw FoodAPIError.decodingError
        } catch {
            print("Network error: \(error)")
            throw FoodAPIError.networkError
        }
    }
}
