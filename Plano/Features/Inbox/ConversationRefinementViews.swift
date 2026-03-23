import SwiftUI

struct ThreadAssistantCard: View {
    let brief: ConversationAssistantBrief
    let action: () -> Void

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(brief.title, systemImage: "sparkles.rectangle.stack.fill")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Spacer()

                    StatusBadge(title: "Assistive", tone: brief.tone)
                }

                Text(brief.summary)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Palette.textSecondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Next action")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.subdued)

                    Text(brief.nextAction)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested reply")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Palette.subdued)

                    Text(brief.suggestedReply)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                Button("Use suggested reply") {
                    action()
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        }
    }
}

