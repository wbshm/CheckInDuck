//
//  ContentView.swift
//  CheckInDuck
//
//  Created by wangrq on 2026/3/13.
//

import SwiftUI

struct ContentView: View {
    @State private var isShowingLaunchScreen = true

    var body: some View {
        ZStack {
            RootTabView()
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
}

#Preview {
    ContentView()
}
