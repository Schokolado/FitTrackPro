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

struct OFFProduct: Decodable {
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

actor FoodAPIService {
    func fetchProduct(barcode: String) async throws -> OFFProduct? {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v0/product/\(barcode).json") else {
            throw FoodAPIError.networkError
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
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
}
