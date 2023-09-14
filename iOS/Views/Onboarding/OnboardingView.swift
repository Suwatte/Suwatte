//
//  OnboardingView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-09-13.
//

import SwiftUI


struct OnboardingView: View {
    @State private var tab = 0
    @State private var savedCommunityList = false
    @Environment(\.presentationMode) private var presentationMode
    var body: some View {
        ZStack (alignment: .topTrailing) {
            TabView(selection: $tab) {
                OnboardingWelcomeTabView(tab: $tab)
                    .tag(0)
                OnboardingSourceTabView(tab: $tab)
                    .tag(1)
                OnboardingSourceInformationTabView(tab: $tab)
                    .tag(2)
                OnboardingAddListsTabView(tab: $tab, savedCommunityList: $savedCommunityList)
                    .tag(3)
                
                if savedCommunityList {
                    
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            
            Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
                    .font(.title2.weight(.semibold))
            }
            .padding(.all)
        }
        .background(GradientView.edgesIgnoringSafeArea(.all))
        .tint(.sttDefault)
        .accentColor(.sttDefault)
        .toast()
        
    }
    
    var GradientView: some View {
        LinearGradient(colors: [.accentColor, .clear], startPoint: .top, endPoint: .center)
    }
}

struct OnboardingWelcomeTabView: View {
    @Binding var tab: Int
    
    
    var body: some View {
        VStack (alignment: .center) {
            Image("stt")
                .resizable()
                .scaledToFit()
                .foregroundColor(.accentColor)
                .frame(width: 80, height: 80)
                .padding(.bottom, 50)
            
            
            VStack (alignment: .leading){
                Text("Welcome to Suwatte")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Suwatte is a comic reader which allows you to read your favorite comics from a variety of sources")
                    .font(.subheadline)
                    .fontWeight(.light)
                
                Button("Continue") {
                    withAnimation {
                        tab += 1
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.horizontal)
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


struct OnboardingSourceTabView: View {
    @Binding var tab: Int
    
    
    var body: some View {
        VStack (alignment: .leading, spacing: 7) {
            Text("A variety of options")
                .font(.title3)
                .fontWeight(.semibold)
            Group {
                Text("Suwatte allows you to read comics from an OPDS Server, Archived Files (CBR, CBZ, RAR, ZIP) and from external runners using custom scripts written in Javascript.")
            }
            .font(.subheadline.weight(.light))
            
            Button("Continue") {
                withAnimation {
                    tab += 1
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.horizontal)
    }
}

struct OnboardingSourceInformationTabView: View {
    @Binding var tab: Int
    
    
    var body: some View {
        VStack (alignment: .leading, spacing: 10) {
            Text("Common Names")
                .font(.title3)
                .fontWeight(.semibold)
            Group {
                Text("**Runners**\nThese refer to the external scripts that extend the reading and tracking options available in the app. Thes can often be downloaded from **Runner Lists** and have their source code uploaded to *Github*\n\n**Sources**\nSources are *Runners* that provide content to read from websites or provide the functionality to fetch & read content from Media Servers such as *[Komga](https://komga.org)*.\n\n**Trackers**\nTrackers are *Runners* that provide a way to keep track of your reading progress on Tracking Sites like *[Anilist](https://anilist.co)*.")
            }
            .font(.subheadline.weight(.light))
            
            Button("Continue") {
                withAnimation {
                    tab += 1
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.horizontal)
    }
}

struct OnboardingAddListsTabView: View {
    @Binding var tab: Int
    @Binding var savedCommunityList: Bool
    
    var body: some View {
        VStack (alignment: .leading, spacing: 10) {
            Text("Adding Lists")
                .font(.title3)
                .fontWeight(.semibold)
            Group {
                Text("You can add lists to Suwatte by simply visiting the website of the List and tapping the *Add To Suwatte* button. Your saved lists will then be available under **Saved Lists** in \(Image(systemName: "ellipsis.circle")).\n\nTo gelp you get started tap the button below to add the Community List containing popular Sources & Trackers directly supported by us.")
            }
            .font(.subheadline.weight(.light))
            
            Button("Add Community List") {
                saveCommunity()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(.horizontal)
    }
    
    func saveCommunity() {
        Task {
            do {
                try await DSK.shared.saveRunnerList(at: "https://community.suwatte.app")
                ToastManager.shared.display(.info("Saved List!"))
                withAnimation {
                    savedCommunityList = true
                    tab += 1
                }
                
            } catch {
                ToastManager.shared.error(error)
                Logger.shared.error(error)
            }
        }
        
    }
}


struct Onboarding_Previews: PreviewProvider {
    
    static var previews: some View {
        OnboardingView()
            .previewLayout(PreviewLayout.sizeThatFits)
            .previewDisplayName("Onboarding")
    }
}
