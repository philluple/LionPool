//
//  Matches.swift
//  Lion Pool
//
//  Created by Phillip Le on 7/25/23.
//

import Foundation
import Firebase

struct Match: Decodable, Identifiable{
    var id: UUID
    var flightId: UUID
    var matchFlightId: UUID
    var matchUserId: String
    var date: String
    var pfp: String
    var name: String
    var notify: Bool?
    var airport: String
}
