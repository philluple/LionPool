//
//  RequestsModel.swift
//  Lion Pool
//
//  Created by Phillip Le on 8/1/23.
//

import Foundation


class RequestModel: ObservableObject{
    @Published var requests: [UUID: [Request]] = [:]
    @Published var inRequests: [UUID: [Request]] = [:]
    
    let jsonDecoder = JSONDecoder()
    let baseURL = "https://lion-pool.com/api/request"
    
    init(){
        if let userId = UserDefaults.standard.string(forKey: "userId"){
            fetchRequests(userId: userId)
            fetchInRequests(userId: userId)
        }
    }

    enum Result{
        case success(Match)
        case failure
    }
    
    func signOut(){
        self.requests = [:]
        self.inRequests = [:]
    }
    
    func signIn(){
        let userId = UserDefaults.standard.string(forKey: "userId")
        fetchRequests(userId: userId!)
        fetchInRequests(userId: userId!)
    }
    
    func updateNotify (flightId: UUID, userId: String){
        let fullURL = "\(baseURL)/updateNotify?flightId=\(flightId)&userId=\(userId)"
        guard let url = URL(string: fullURL) else {fatalError("Missing URL")}
        let urlRequest = URLRequest(url: url)
        let dataTask = URLSession.shared.dataTask(with: urlRequest) {(data, response, error) in
            if let error = error{
                print("Reject request error", error)
                return
            }
            guard let response = response as? HTTPURLResponse else{
                print("Error withh response")
                return
            }
            if response.statusCode == 200{
                print("Updated notification status")
                return
            }else{
                print("Failed to update notification status")
                return
            }
        }
        dataTask.resume()
    }

    func acceptRequest (request: Request, currentUser: User, completion: @escaping (Result)-> Void){
        // Reciever data
        let fullURL = "\(baseURL)/accept"
        guard let url = URL(string: fullURL) else {fatalError("Missing URL")}
        
        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "POST"
        
        
        let matchData: [String: Any] = [
            "requestId": request.id.uuidString,
            "recieverFlightId": request.recieverFlightId.uuidString,
            "recieverName": String(format: "%@ %@", currentUser.firstname, currentUser.lastname),
            "recieverUserId": request.recieverUserId,
            "recieverPfp":currentUser.pfpLocation,
            "senderFlightId":request.senderFlightId.uuidString,
            "senderName": request.name,
            "senderUserId": request.senderUserId,
            "senderPfp":request.pfp,
            "date": request.flightDate,
            "airport": request.airport
        ]
        
        
        httpRequest.httpBody = try? JSONSerialization.data(withJSONObject: matchData)
        httpRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let dataTask = URLSession.shared.dataTask(with: httpRequest) {data, response, error in
            if let error = error {
                print("Error with accpeting request: \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse {
                print ("Status code: \(httpResponse .statusCode)")
                if httpResponse.statusCode == 200 {
                    if let data = data {
                        do {
                            let decoder = JSONDecoder()
                            let match = try decoder.decode(Match.self, from: data)
                            DispatchQueue.main.async{
                                print("Accepted request")
                                if let requestToReject = self.inRequests[request.recieverFlightId]{
                                    for reject in requestToReject{
                                        if reject.id == request.id{
                                            continue
                                        }
                                        self.rejectRequest(request: reject, userId: currentUser.id)
                                    }
                                }
                                if let existingCounter = UserDefaults.standard.value(forKey: "matches") as? Int{
                                    let incrementedCounter = existingCounter + 1
                                    UserDefaults.standard.set(incrementedCounter, forKey: "matches")
                                } else{
                                    UserDefaults.standard.set(1, forKey: "matches")
                                }
                                completion(.success(match))
                            }
                        } catch {
                            print("Error decoding match object: \(error.localizedDescription)")
                            completion(.failure)
                        }
                    }
                } else{
                    print("Could not accept request!")
                    completion(.failure)
                }
            }
        }
        dataTask.resume()
    }
    
    func rejectRequest (request: Request, userId: String){
        print("Attempting to reject")
        let id = request.id
        let fullURL = "\(baseURL)/reject?id=\(id)&recieverUserId=\(userId)&senderUserId=\(request.senderUserId)"
        guard let url = URL(string: fullURL) else {fatalError("Missing URL")}
        let urlRequest = URLRequest(url: url)
        let dataTask = URLSession.shared.dataTask(with: urlRequest) {(data, response, error) in
            if let error = error{
                print("Reject request error", error)
                return
            }
            
            guard let response = response as? HTTPURLResponse else{
                print("Error withh response")
                return
            }
            
            if response.statusCode == 200{	
                DispatchQueue.main.async{
                    if var inRequestsArray = self.inRequests[request.recieverFlightId] {
                        if let indexToDelete = inRequestsArray.firstIndex(where: {$0 == request}){
                            inRequestsArray.remove(at: indexToDelete)
                            self.inRequests[request.recieverFlightId] = inRequestsArray
                        }
                    }
                    return
                }
            }
        }
        dataTask.resume()
    }
    
    func fetchInRequests(userId: String){
        print("Attempting to fetch incoming requests")
        inRequests = [:]
        let fullURL = "\(baseURL)/fetchInRequests?userId=\(userId)"
        guard let url = URL(string: fullURL) else {fatalError("Missing URL")}
        let urlRequest = URLRequest(url: url)
        let dataTask = URLSession.shared.dataTask(with: urlRequest) {(data, response, error) in
            if let error = error {
                print("Request error: ",error)
                return
            }
            
            guard let response = response as? HTTPURLResponse else{
                print("Error with response")
                return
            }
            
            if response.statusCode == 200 {
                guard let data = data else {
                    return
                }
                do {
                    let decodedRequests = try self.jsonDecoder.decode([Request].self, from: data)
                    DispatchQueue.main.async {
                        for request in decodedRequests {
                            let recieverFlightId = request.recieverFlightId
                            if var existingRequests = self.inRequests[recieverFlightId] {
                                // If there are existing requests for this recieverFlightId, append the new request to the array
                                existingRequests.append(request)
                                self.inRequests[recieverFlightId] = existingRequests
                            } else {
                                // If there are no existing requests for this recieverFlightId, create a new array and add the request
                                self.inRequests[recieverFlightId] = [request]
                            }
                        }
                        return
                    }
                } catch {
                    print("\(error.localizedDescription)")
                    print("Error decoding requests fron Inrequests")
                    return
                }
            }
        }
        dataTask.resume()
    }
    
    func fetchRequests(userId: String){
        print("Attempting to fetch request")
        requests = [:]
        let fullURL = "\(baseURL)/fetchOutRequests?userId=\(userId)"
        guard let url = URL(string: fullURL) else {fatalError("Missing URL")}
        let urlRequest = URLRequest(url: url)
        let dataTask = URLSession.shared.dataTask(with: urlRequest) {(data, response, error) in
            if let error = error {
                print("Request error: ",error)
                return
            }
            
            guard let response = response as? HTTPURLResponse else{
                print("Error with response")
                return
            }
            
            if response.statusCode == 200 {
                guard let data = data else {
                    return
                }
                do {
                    let decodedRequests = try self.jsonDecoder.decode([Request].self, from: data)
                    DispatchQueue.main.async {
                        for request in decodedRequests {
                            let senderFlightId = request.senderFlightId
                            if var existingRequests = self.requests[senderFlightId] {
                                // If there are existing requests for this recieverFlightId, append the new request to the array
                                existingRequests.append(request)
                                self.requests[senderFlightId] = existingRequests
                            } else {
                                // If there are no existing requests for this recieverFlightId, create a new array and add the request
                                self.requests[senderFlightId] = [request]
                            }
                        }
                        print(self.requests)
                    }
                } catch {
                    print("\(error.localizedDescription)")
                    print("Error decoding requests from fetchRequests")
                    return
                }
            }
        }
        dataTask.resume()
    }
    
    func sendRequest(match: Match, senderUserId: String, completion: @escaping (Result)-> Void){
        print("Attempting to send request")
        let fullURL = "\(baseURL)/send?senderFlightId=\(match.flightId)&senderUserId=\(senderUserId)&recieverFlightId=\(match.matchFlightId)&recieverUserId=\(match.matchUserId)"
        guard let url = URL(string: fullURL) else {fatalError("Missing URL")}
        let URLrequest = URLRequest(url: url)
        let dataTask = URLSession.shared.dataTask(with: URLrequest) { (data, response, error) in
            if let error = error {
                print("Request error: ", error)
                return
            }
            
            guard let response = response as? HTTPURLResponse else{
                return
            }
            
            if(response.statusCode == 200){
                guard let data = data else{
                    return
                }
                do {
                    print(data)
                    let decodedRequest = try self.jsonDecoder.decode(Request.self, from: data)
                    DispatchQueue.main.async{
                        print(decodedRequest)
                        let recieverFlightId = decodedRequest.recieverFlightId
                        if var existingRequests = self.requests[recieverFlightId] {
                            // If there are existing requests for this recieverFlightId, append the new request to the array
                            existingRequests.append(decodedRequest)
                            self.requests[recieverFlightId] = existingRequests
                        } else {
                            // If there are no existing requests for this recieverFlightId, create a new array and add the request
                            self.requests[recieverFlightId] = [decodedRequest]
                        }
                    }
                }catch {
                    DispatchQueue.main.async{
                        print("Error from sendrequest: \(error.localizedDescription)")
                        completion(.failure)
                    }
                }
                
            } else{
                DispatchQueue.main.async{
                    completion(.failure)
                }
                
            }
        }
        dataTask.resume()
    }
    
    
}
