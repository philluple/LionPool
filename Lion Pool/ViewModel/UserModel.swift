//
//  AuthViewModel.swift
//  Lion Pool
//
//  Created by Phillip Le on 7/6/23.
//

import Foundation
import Firebase
import FirebaseFirestoreSwift
import FirebaseAuth
import FirebaseStorage
import SwiftUI


enum VerificationStatus {
    case verified, pending, newUser
}

// Publishes UI changes on the main thread
@MainActor
class UserModel: ObservableObject {

    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User?
    @Published var currentUserProfileImage: Image? = nil
    @Published var verificationStatus: VerificationStatus = .newUser
    var imageUtil = ImageUtils()

    init(){
        self.userSession = Auth.auth().currentUser
        Task {
            await fetchUser()
            await fetchPfp()
        }
    }

//    init(){
//        if let currentUser = Auth.auth().currentUser{
//            self.userSession = currentUser
//        if userSession!.isEmailVerified{
//                print("verified")
//                verificationStatus = .verified
//                Task {
//                    await fetchUser()
//                    await fetchPfp()
//                }
//        } else {
//            verificationStatus = .pending
//            print("pending")
//        }
//        }
//    }
    
    func resendVerification(){
        if let user = self.userSession{
            user.sendEmailVerification()
        }
    }
    
    func checkUserSession() {
        // Add an observer to the Firebase Authentication state
        print("in here")
        Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            guard let self = self else { return }
            if let user = user {
                self.userSession = user
                Task {
                    print(user.email)
                    print(user.isEmailVerified)
                    await self.fetchUser()
                    let isEmailVerified = user.isEmailVerified
                    if isEmailVerified {
                        self.verificationStatus = .verified
                        print("verified 2")
                    } else {
                        self.verificationStatus = .pending
                        print("pending 2")
                    }
                }
            } else {
                // User is signed out, set userSession to nil and reset currentUser data
                self.userSession = nil
                self.currentUser = nil
                self.currentUserProfileImage = nil
            }
        }
    }


    func signIn(withEmail email: String, password: String) async throws{
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.userSession = result.user
            await fetchUser()
            await fetchPfp()
            if let userId = self.currentUser?.id,
               let firstname = self.currentUser?.firstname,
               let lastname = self.currentUser?.lastname {
                   let name = "\(firstname) \(lastname)"
                   UserDefaults.standard.set(userId, forKey: "userId")
                   UserDefaults.standard.set(name, forKey: "name")
            }

            print("SUCCESS: User has signed in")
        } catch {
            print("DEBUG: failed to login")
        }
    }
    
    func createUser(UNI: String, password: String, firstname: String, lastname: String, pfpLocation: String) async throws -> String? {
        let email = UNI + "@columbia.edu"
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            self.userSession = result.user
            UserDefaults.standard.set(result.user.uid, forKey: "userId")
            UserDefaults.standard.set(email, forKey: "email")
            let user = User(id: result.user.uid, firstname:
                                firstname, lastname: lastname, email: email, UNI: UNI, pfpLocation: pfpLocation)
            let encodedUser = try Firestore.Encoder().encode(user)
            try await Firestore.firestore().collection("users").document(user.id).setData(encodedUser)

            do {
                try await result.user.sendEmailVerification()
                verificationStatus = VerificationStatus.pending
                print("Verification email sent successfully")
                return result.user.uid
            } catch {
                print("Failed to send verification email:", error.localizedDescription)
                return nil
            }
        } catch {
            print("DEBUG: could not create account", error.localizedDescription)
            return nil
        }
    }
    
//    func createUser(withEmail email: String, password: String, firstname: String, lastname: String, UNI: String, pfpLocation: String) async throws -> String?{
//        do {
//            let result = try await Auth.auth().createUser(withEmail: email, password: password)
//            result.user.sendEmailVerification { error in
//                if let error = error {
//                    print("Failed to send verification email: \(error.localizedDescription)")
//                } else {
//                    print("Verification email sent successfully")
//                }
//            }
//            self.userSession = result.user
//            let user = User(id: result.user.uid, firstname: firstname, lastname: lastname, email: email, UNI: UNI, pfpLocation: pfpLocation)
//            let encodedUser = try Firestore.Encoder().encode(user)
//            // Storing the data
//            print("DEBUG: before")
//            try await Firestore.firestore().collection("users").document(user.id).setData(encodedUser)
//            await fetchUser()
//            await fetchPfp()
//            print("SUCCESS: \(user.id) has been created")
//            if let userId = self.currentUser?.id,
//               let firstname = self.currentUser?.firstname,
//               let lastname = self.currentUser?.lastname {
//                   let name = "\(firstname) \(lastname)"
//                   UserDefaults.standard.set(userId, forKey: "userId")
//                   UserDefaults.standard.set(name, forKey: "name")
//            }
//            return user.id
//        } catch {
//            print("DEBUG: could not create account", error.localizedDescription)
//            return nil
//        }
//    }
    
    func signOut() {
        // take us back to login screen
        do {
            try Auth.auth().signOut()
            self.userSession = nil
            self.currentUser = nil
            self.currentUserProfileImage = nil
            print ("SUCCESS: User has signed out")
        } catch {
            print ("DEBUG: Could not sign out user")
        }
    }
    
    func fetchUser() async {
        print("Fetching user")
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let snapshot = try? await Firestore.firestore().collection("users").document(uid).getDocument() else {return}
        self.currentUser = try? snapshot.data(as: User.self)
        if let userId = self.currentUser?.id,
           let firstname = self.currentUser?.firstname,
           let lastname = self.currentUser?.lastname {
               let name = "\(firstname) \(lastname)"
               UserDefaults.standard.set(userId, forKey: "userId")
               UserDefaults.standard.set(name, forKey: "name")
        }
        print("SUCCESS: Fetched the user")
    }
    
    func fetchPfp() async {
        print("Fetching image")
        guard let pfp = self.currentUser?.pfpLocation else{
            return
        }
        guard let id = self.currentUser?.id else{
            return
        }
        if pfp == "" {
            return
        }
        DispatchQueue.main.async{
            self.imageUtil.fetchImage(userId: id){ result in
                switch result {
                case .success(let uiImage):
                    self.currentUserProfileImage = Image(uiImage: uiImage)
                case .failure:
                    print("Failed")
                }
            }
        }

    }
}


