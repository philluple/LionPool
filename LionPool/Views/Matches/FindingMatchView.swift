//
//  FindingMatchLoading.swift
//  Lion Pool
//
//  Created by Phillip Le on 7/26/23.
//

import SwiftUI
import Combine

public class RandomNumberGenerator: ObservableObject {
    @Published var randomNumber: Int = 0
    private var timer: AnyCancellable?

    init() {
        startGeneratingRandomNumber()
    }

    private func startGeneratingRandomNumber() {
        timer = Timer.publish(every: 3, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                self.randomNumber = Int.random(in: 0...6)%6
            }
    }

}

struct FindingMatchView: View {
    //variables that need to be passed
    var flightId: UUID
    var airport: String
    var userId: String
    var date: Date
    
    
    @State var isLoading = false
    @State var dots = ""
    @State var showNextView = false
    @State var index = 0
    @State var matchesFound: Bool = false
    @State var goHome: Bool = false
    @State var elapsedTime: TimeInterval = 0
    let maxElapsedTime: TimeInterval = 3 // Set the desired duration in seconds
    
    @StateObject private var randomNumberGenerator = RandomNumberGenerator()
    @EnvironmentObject var matchModel : MatchModel
    
//    let dateFormatter = DateFormatter(dateFormat: "yyyyMMddHHmmss")
    let maxDots = 3
    let animationInterval = 0.5
    
    var thingsToPack = ["sunblock", "underwear", "toothbrush", "to text your mom when your flight takes off", "to download your songs", "to find a plant guardian", "to take out your piercings"]
    
    @State private var isMatchesListActive = false
    @State private var isNoMatchActive = false

    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                Text("Matching in progress" + dots)
                    .font(.system(size: 30, weight: .bold))
                    .padding([.top, .bottom])
                    .frame(width: UIScreen.main.bounds.width, height: 70)
                    .onAppear {
                        startLoadingAnimation()
                    }
                
                Text("Dont forget \(thingsToPack[randomNumberGenerator.randomNumber])")
                Spacer()
                
                NavigationLink("", isActive: $isMatchesListActive) {
                    MatchesListView(date: date, airport: airport)
                }.navigationBarBackButtonHidden()
                
                NavigationLink("", isActive: $isNoMatchActive) {
                    NoMatchView()
                }.navigationBarBackButtonHidden()
                
                Spacer()
            }
            .onAppear {
                matchModel.findMatch(flightId: flightId, userId: userId, airport: airport) { result in
                    switch result {
                    case .success:
                        isMatchesListActive = true
                    case .noMatches:
                        isNoMatchActive = true
                        print("No matches found.")
                    case .failure:
                        print("Failed")
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + maxElapsedTime) {
                    showNextView = true
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    
    private func startLoadingAnimation() {
        let timer = Timer.scheduledTimer(withTimeInterval: animationInterval, repeats: true) { _ in
            isLoading.toggle()
            updateDots()
        }
        timer.fire()
    }
        
    private func updateDots() {
        if isLoading {
            if dots.count < maxDots {
                dots += "."
            } else {
                dots = ""
            }
        }
    }
    
    
}
