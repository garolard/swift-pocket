//
//  Pocket.swift
//  Pocket
//
//  Created by Sören Gade on 28.10.21.
//


import Foundation


public class Pocket {

    public var accessToken: String?
    public var username: String?

    let consumerKey: String

    var isAuthenticated: Bool {
        accessToken != nil
    }

    public init(consumerKey: String) {
        self.consumerKey = consumerKey
    }

}

// MARK: - Network request

extension Pocket {

    func request<T: Decodable>(url: URL, jsonData: [String: String], completion: @escaping (Result<T, Error>) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "X-Accept")
        do {
            request.httpBody = try JSONEncoder().encode(jsonData)
        } catch {
            return completion(.failure(error))
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                return completion(.failure(Errors.network(error!)))
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  let data = data
            else {
                return completion(.failure(Errors.unsuccessfulResponse))
            }
            guard httpResponse.statusCode == 200 else {
                // see https://getpocket.com/developer/docs/errors
                let errorCode = Int(httpResponse.value(forHTTPHeaderField: "X-Error-Code") ?? "") ?? 0
                let message = httpResponse.value(forHTTPHeaderField: "X-Error") ?? ""
                return completion(.failure(self.error(for: httpResponse.statusCode,
                                                         errorCode: errorCode,
                                                         message: message)))
            }

            do {
                let body = try JSONDecoder().decode(T.self, from: data)
                return completion(.success(body))
            } catch {
                return completion(.failure(error))
            }
        }
        task.resume()
    }

    private func error(for statusCode: Int, errorCode: Int, message: String) -> Error {
        switch statusCode {
        case 400: return Errors.invalidRequest(code: errorCode, message: message)
        case 401: return Errors.authenticationFailed(code: errorCode, message: message)
        case 403: return Errors.lackingPermission(code: errorCode, message: message)
        case 503: return Errors.serverDownForMaintenance
        default:  return Errors.errorResponse(status: statusCode,
                                              code: errorCode,
                                              message: message)
        }
    }

    func requestAuthenticated<T: Decodable>(url: URL, data: [String: String], completion: @escaping (Result<T, Error>) -> Void) {
        guard isAuthenticated else {
            return completion(.failure(Errors.notAuthenticated))
        }

        var authenticatedData = data
        authenticatedData["consumer_key"] = consumerKey
        authenticatedData["access_token"] = accessToken ?? ""

        request(url: url, jsonData: authenticatedData, completion: completion)
    }

}
