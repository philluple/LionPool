//
//  ProfileView.swift
//  Lion Pool
//
//  Created by Phillip Le on 7/7/23.
//

import SwiftUI
import Firebase
import FirebaseStorage
import FirebaseAuth
import PartialSheet

struct ImageWrapper: Identifiable {
    var id: UUID = UUID()
    var image: Image
}
func returnDate(date: Date) -> String{
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
//    print(dateFormatter.string(from: date))
    return dateFormatter.string(from: date)
}

struct ProfileView: View {
    @EnvironmentObject var userModel : UserModel
    @EnvironmentObject var matchModel : MatchModel
    @EnvironmentObject var requestModel : RequestModel
    @EnvironmentObject var flightModel : FlightModel
    @EnvironmentObject var instagramModel: InstagramAPI
    @Environment(\.presentationMode) var presentationMode
    @State var username: String = ""
//    @ObservedObject var imageLoader = ImageLoader() // Replace with your ViewModel

    let columns: [GridItem] = [
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 2)
    ]
    
    var imageUitl = ImageUtils()
    
    @State private var displayedImage: Image?
    
    @State private var changedPfp: Bool = false
    @State private var camera: Bool = false // Add this state
    @State private var library: Bool = false // Add this state
    @State private var selected: Bool = false // Add this state
    @State private var isSheetPresented = false
    @State private var signOutSheet: Bool = false
    @State private var settingSheet: Bool = false
    @State private var isPresentView: Bool = false
    @State private var showInstaButton: Bool = true

    var body: some View {
        VStack{
            AccountInfo
            Divider()
                .padding(.horizontal,40)
                .padding(.bottom, 10)
                .padding(.top, 20)
            AccountStats
            
            Divider()
                .padding(.horizontal,40)
                .padding(.top, 10)
                .padding(.bottom, 20)
            if (instagramModel.displayPost){
                GeometryReader { geometry in
                    VStack{
                        HStack{
                            Text("Recent Instagram Photos")
                                .font(.system(size: 18, weight: .bold))
                            Spacer()
                        }
                        LazyVGrid(columns: columns, spacing: 4){
                            ForEach(instagramModel.feed){ post in
                                AsyncImage(url: URL(string: post.imageURL)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: geometry.size.width/3-15, height: geometry.size.width/3-15) // Adjust size based on GeometryReader
                                        .cornerRadius(5)
                                        .clipped()
                                } placeholder: {
                                    Color.clear // Using an empty color as a placeholder
                                        .frame(width: geometry.size.width/3-15, height: geometry.size.width/3-15)
                                        .cornerRadius(5)
                                }
                            }
                        }
                    }.padding(.horizontal)
                    
                }
            }
            
            
            Spacer()

            signOut
            
            
            .partialSheet(isPresented: $isSheetPresented){
                ChooseImageMedium(camera: $camera, library: $library, selected: $selected, showSheet: $isSheetPresented, changedPfp: $changedPfp)
            }
            .partialSheet(isPresented: $signOutSheet){
                ChoiceView(isPresented: $signOutSheet, firstAction: signOutAction, firstOption: "Sign out", secondOption: "Cancel", title: "Would you like to sign out")
            }
        }
    }
    
    private var AccountInfo: some View{
        HStack{
            VStack(alignment: .leading, spacing: 0){
                Button{
                        isSheetPresented.toggle()
                } label: {
                    profilePicture
                }
                VStack(alignment: .leading, spacing: 4){
                    if let name = UserDefaults.standard.string(forKey: "name"){
                            Text(name)
                                .font(.system(size:16, weight: .semibold))
                    } else{
                        Text("Phillip Le")
                            .font(.system(size:16, weight: .semibold))
                    }
                    if instagramModel.displayPost == false{
                        InstagramButton
                    }else{
                        if let username = UserDefaults.standard.string(forKey: "instagram_handle"){
                            Text("@\(username)")
                                .padding(5)
                                .font(.system(size: 14, weight: .semibold))
                                .background(Color("Gray Blue "), in: RoundedRectangle(cornerRadius: 10))
                                .foregroundColor(Color.white)
                        }
                    }
                }.padding(.leading, 20)
            }
            Spacer()
        }.padding(.leading, 20)
    }
    
    
    private var InstagramButton: some View{
        Link(destination: URL(string: "https://api.instagram.com/oauth/authorize?client_id=1326528034640707&redirect_uri=https://lion-pool.com/app&scope=user_profile,user_media&response_type=code")!)
        {
            HStack{
                Image("instagram-logo")
                    .resizable()
                    .frame(width: 20, height: 20)
                Text("Connect your Instagram")
                    .font(.system(size: 14, weight: .semibold))
            }
            
        }.frame(width: 210, height: 30)
            .background(Color("Gray Blue "))
            .cornerRadius(10)
        .accentColor(Color.white)
    }
    
    private var AccountStats: some View{
        HStack(spacing: 40){
            VStack{
                Group{
                    if let flightCount = UserDefaults.standard.value(forKey: "flights") as? Int {
                        Text("\(flightCount)")
                            .font(.system(size:16, weight: .semibold))
                    }else{
                        Text("0")
                            .font(.system(size:16, weight: .semibold))
                    }
                }
                Text("Flights")
                    .font(.system(size:14))
                
            }
            
            VStack{
                Group{
                    if let matchCount = UserDefaults.standard.value(forKey: "matches") as? Int {
                        Text("\(matchCount)")
                            .font(.system(size:16, weight: .semibold))
                        
                    }else{
                        Text("0")
                            .font(.system(size:16, weight: .semibold))
                    }
                }
                Text("Matches")
                    .font(.system(size:14))
            }
            
            
        }
    }
    private var profilePicture: some View {
        Group {
            if let displayedImage = userModel.currentUserProfileImage {
                displayedImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .overlay(Circle().stroke(Color("Text Box"), lineWidth: 4))
                    .clipShape(Circle())
                    .padding()
                    .overlay {
                        ZStack(alignment: .topLeading) {
                            Image(systemName: "pencil.circle.fill")
                                .resizable()
                                .foregroundColor(Color("Gold"))
                                .frame(width: 20, height: 20)
                                .offset(x: 30, y: 40) // Adjust these values to move the pencil icon
                        }
                    }
            } else {
                Circle()
                    .frame(width: 100, height: 100)
                    .foregroundColor(Color("Text Box"))
                    .padding()
                    .overlay {
                        Image(systemName: "pawprint.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(Color.gray)
                            .opacity(0.4)
//                            .offset(x: 100, y: -10) // Adjust these values to move the pawprint icon
                            .overlay(alignment: .topLeading) {
                                Image(systemName: "pencil.circle.fill")
                                    .resizable()
                                    .foregroundColor(Color("Gold"))
                                    .frame(width: 20, height: 20)
                                    .offset(x: 50, y: 40) // Adjust these values to move the pencil icon
                            }
                    }
            }
        }
    }

    private var signOut: some View{
        HStack{
            Spacer()
            Button {
                signOutSheet.toggle()
            } label: {
                ZStack{
                    Circle()
                        .fill(Color("Gold"))
                        .frame(width: 40)
                    Image(systemName: "gear")
                        .resizable()
                        .frame(width: 25, height: 25)
                        .foregroundColor(Color.white)
                }
            }
        }.padding(.horizontal)
        

    }
    
    
    private func signOutAction() {
        matchModel.signOut()
        flightModel.signOut()
        requestModel.signOut()
        instagramModel.signOut()
        UserDefaults.resetStandardUserDefaults()
        userModel.signOut()

        
    }
    
}


struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview for iPhone SE (1st generation)
            NavigationView {
                ProfileView()
                    .environmentObject(UserModel())
                    .environmentObject(InstagramAPI())
            }
            .previewDevice(PreviewDevice(rawValue: "iPhone 13 Pro"))
        }
    }
}



