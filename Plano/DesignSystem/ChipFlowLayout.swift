import SwiftUI

struct ChipFlowLayout: View {
    let options: [String]
    let selected: [String]
    let onToggle: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button {
                    onToggle(option)
                } label: {
                    FilterChip(title: option, isSelected: selected.contains(option))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
