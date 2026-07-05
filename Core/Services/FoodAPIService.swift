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

struct OFFProduct: Decodable, Identifiable, Hashable {
    let id = UUID()
    var code: String?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: OFFProduct, rhs: OFFProduct) -> Bool {
        return lhs.id == rhs.id
    }
    var productName: String?
    var servingQuantity: Double?
    var nutriments: OFFNutriments?
    
    init(code: String? = nil, productName: String? = nil, servingQuantity: Double? = nil, nutriments: OFFNutriments? = nil) {
        self.code = code
        self.productName = productName
        self.servingQuantity = servingQuantity
        self.nutriments = nutriments
    }
    
    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case productNameDe = "product_name_de"
        case productNameEn = "product_name_en"
        case servingQuantity = "serving_quantity"
        case nutriments
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.code = try container.decodeIfPresent(String.self, forKey: .code)
        self.nutriments = try container.decodeIfPresent(OFFNutriments.self, forKey: .nutriments)
        
        if let sqStr = try? container.decodeIfPresent(String.self, forKey: .servingQuantity), let sq = Double(sqStr) {
            self.servingQuantity = sq
        } else if let sq = try? container.decodeIfPresent(Double.self, forKey: .servingQuantity) {
            self.servingQuantity = sq
        }
        
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
    func fetchProduct(barcode: String, retries: Int = 1) async throws -> OFFProduct? {
        guard let url = URL(string: "https://de.openfoodfacts.org/api/v0/product/\(barcode).json") else {
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
            if retries > 0 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                return try await fetchProduct(barcode: barcode, retries: retries - 1)
            }
            throw FoodAPIError.networkError
        }
    }
    
    func searchProducts(query: String, page: Int = 1) async throws -> [OFFProduct] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://de.openfoodfacts.org/cgi/search.pl?search_terms=\(encodedQuery)&search_simple=1&action=process&json=1&page_size=20&page=\(page)") else {
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
