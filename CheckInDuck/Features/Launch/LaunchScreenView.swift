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
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 112, height: 112)

                    Image(systemName: "checklist.checked")
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(.white)
                }

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
