//
//  ContentView.swift
//  CheckInDuck
//
//  Created by wangrq on 2026/3/13.
//

import SwiftUI

struct ContentView: View {
    @State private var isShowingLaunchScreen = true
    @State private var hasCompletedOnboarding = AppPreferences.hasCompletedOnboarding()

    var body: some View {
        ZStack {
            mainContent
                .allowsHitTesting(!isShowingLaunchScreen)

            if isShowingLaunchScreen {
                LaunchScreenView()
                    .transition(.opacity)
            }
        }
        .task {
            guard isShowingLaunchScreen else { return }

            try? await Task.sleep(for: .milliseconds(900))

            withAnimation(.easeOut(duration: 0.22)) {
                isShowingLaunchScreen = false
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if hasCompletedOnboarding {
            RootTabView()
        } else {
            OnboardingView {
                AppPreferences.setHasCompletedOnboarding(true)
                withAnimation(.easeInOut(duration: 0.22)) {
                    hasCompletedOnboarding = true
                }
            }
            .transition(.opacity)
        }
    }
}

#Preview {
    ContentView()
}
