import SwiftUI

struct SplashScreenView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            AppBackdrop()

            VStack(spacing: 20) {
                if let uiImage = UIImage(named: "AppIcon") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .clipShape(.rect(cornerRadius: 18, style: .continuous))
                        .shadow(color: AppTheme.Palette.shadow, radius: 12, y: 6)
                }

                Text("Plano")
                    .font(.system(size: 34, weight: .light))
                    .tracking(-1.2)
                    .foregroundStyle(AppTheme.Palette.textPrimary)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.92)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.smooth(duration: 0.4)) {
                appeared = true
            }
        }
    }
}
