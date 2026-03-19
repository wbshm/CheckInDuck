import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.55, blue: 0.99),
                    Color(red: 0.40, green: 0.73, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("LaunchAppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 112, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 18, y: 10)

                VStack(spacing: 8) {
                    Text("CheckInDuck")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Daily check-ins for what matters today")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.88))
                }
            }
            .padding(.horizontal, 32)
        }
    }
}

#Preview {
    LaunchScreenView()
}
