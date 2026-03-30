import SwiftUI

struct VendorOnboardingView: View {
    let store: VendorOnboardingStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    slideContent
                        .padding(AppTheme.screenPadding)
                        .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)

                bottomBar
            }
            .background(AppBackdrop())
            .navigationTitle(slideTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if store.currentSlide == 0 {
                        Button("Cancel") {
                            store.cancel()
                        }
                    } else {
                        Button("Back") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                store.goBack()
                            }
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled()
        .onChange(of: store.selectedCategory) { _, newCategory in
            store.handleCategoryChange(to: newCategory)
        }
    }

    @ViewBuilder
    private var slideContent: some View {
        switch store.currentSlide {
        case 0:
            VendorOnboardingSlideOneView(store: store)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
        case 1:
            VendorOnboardingSlideTwoView(store: store)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
        case 2:
            VendorOnboardingSlideFiveView(store: store)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
        case 3:
            VendorOnboardingServicesSlideView(store: store)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
        case 4:
            VendorOnboardingSlideThreeView(store: store)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
        case 5:
            VendorOnboardingSlideFourView(store: store)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
        default:
            EmptyView()
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 16) {
            Divider()

            OnboardingProgressDots(
                totalSteps: VendorOnboardingStore.totalSlides,
                currentStep: store.currentSlide
            )

            if store.currentSlide == 0 {
                Button(store.loadingState.isLoading ? "Setting up..." : "Continue") {
                    Task {
                        await store.submitSlideOne()
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(!store.isSlideOneValid || store.loadingState.isLoading)
                .hapticFeedback(.success, trigger: store.slideOneSubmitted)
            } else {
                HStack(spacing: 12) {
                    Button("Skip") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            store.skipCurrentSlide()
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.subdued)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())

                    Button(store.isLastSlide ? "Done" : "Continue") {
                        Task {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                // Animation wraps the slide transition
                            }
                            await store.saveAndContinue()
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(store.loadingState.isLoading)
                }
            }

            if let message = store.loadingState.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.toneColor(.coral))
            }
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.bottom, 24)
    }

    private var slideTitle: String {
        switch store.currentSlide {
        case 0: "Set up your business"
        case 1: "About your business"
        case 2: "Set your availability"
        case 3: "Your key services"
        case 4: CategoryDetails.empty(for: store.selectedCategory).sectionTitle
        case 5: "Show your work"
        default: "Vendor setup"
        }
    }
}
