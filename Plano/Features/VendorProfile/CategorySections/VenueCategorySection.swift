import SwiftUI

struct VenueCategorySection: View {
    let details: VenueDetails
    @State private var showAllAmenities = false

    private let previewCount = 4

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 0) {
                // MARK: - Quick stats

                VStack(alignment: .leading, spacing: 6) {
                    if let seated = details.seatedCapacity, let standing = details.standingCapacity {
                        Label("\(seated) seated · \(standing) standing", systemImage: "person.2.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                    } else if let seated = details.seatedCapacity {
                        Label("Seats \(seated)", systemImage: "person.2.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                    } else if let standing = details.standingCapacity {
                        Label("Standing \(standing)", systemImage: "person.2.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.Palette.textPrimary)
                    }

                    if hasQuickInfo {
                        HStack(spacing: 6) {
                            if !details.venueStyle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Label(details.venueStyle, systemImage: "building.2")
                            }

                            if !details.venueStyle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                               !details.parkingNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            {
                                Text("·")
                            }

                            if !details.parkingNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Label("\(details.parkingNote) parking", systemImage: "p.square.fill")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }

                // MARK: - Offers

                if !offers.isEmpty {
                    Divider()
                        .padding(.vertical, 14)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("What this venue offers")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        ForEach(offers, id: \.self) { offer in
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(offer)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.Palette.textPrimary)
                            }
                        }
                    }
                }

                // MARK: - Amenities

                if !details.includedAmenities.isEmpty {
                    Divider()
                        .padding(.vertical, 14)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Amenities")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        let visible = showAllAmenities
                            ? details.includedAmenities
                            : Array(details.includedAmenities.prefix(previewCount))
                        let overflow = details.includedAmenities.count - previewCount

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 90), spacing: 8)],
                            alignment: .leading,
                            spacing: 8
                        ) {
                            ForEach(visible, id: \.self) { amenity in
                                VenueAmenityChip(
                                    title: amenityShortName(amenity),
                                    systemImage: amenityIcon(amenity)
                                )
                            }

                            if !showAllAmenities, overflow > 0 {
                                Text("+ \(overflow)")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.Palette.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(AppTheme.Palette.chipFill, in: Capsule())
                                    .overlay {
                                        Capsule().stroke(AppTheme.Palette.border, lineWidth: 1)
                                    }
                            }
                        }

                        if !showAllAmenities, overflow > 0 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showAllAmenities = true
                                }
                            } label: {
                                Text("Show all \(details.includedAmenities.count) amenities")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.Palette.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(AppTheme.Palette.chipFill, in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var hasQuickInfo: Bool {
        !details.venueStyle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !details.parkingNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var offers: [String] {
        var result: [String] = []
        if details.setupTeardownIncluded { result.append("Setup & teardown included") }
        if details.bartenderIncluded { result.append("Bartender included") }
        switch details.cateringPolicy {
        case "Any outside vendor": result.append("Outside vendors allowed")
        case "In-house catering only": result.append("In-house catering")
        case "Approved vendors list": result.append("Approved vendor list")
        default: break
        }
        if !details.alcoholPolicy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.append(details.alcoholPolicy)
        }
        if !details.noiseRestriction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.append(details.noiseRestriction)
        }
        return result
    }

    private func amenityShortName(_ amenity: String) -> String {
        switch amenity {
        case "Sound system": "Sound"
        case "Heating/AC": "HVAC"
        case "Bridal suite": "Suite"
        case "Decorations": "Decor"
        default: amenity
        }
    }

    private func amenityIcon(_ amenity: String) -> String {
        switch amenity {
        case "Tables": "table.furniture"
        case "Chairs": "chair.fill"
        case "Sound system": "speaker.wave.2.fill"
        case "Projector": "videoprojector.fill"
        case "Wi-Fi": "wifi"
        case "Kitchen": "refrigerator.fill"
        case "Restrooms": "toilet.fill"
        case "Parking": "car.fill"
        case "Decorations": "sparkles"
        case "Stage": "music.mic"
        case "Dance floor": "figure.dance"
        case "Lighting": "lightbulb.fill"
        case "Heating/AC": "thermometer.medium"
        case "Bridal suite": "door.left.hand.open"
        default: "checkmark"
        }
    }
}

private struct VenueAmenityChip: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline)
            .lineLimit(1)
            .foregroundStyle(AppTheme.Palette.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppTheme.Palette.chipFill, in: Capsule())
            .overlay {
                Capsule().stroke(AppTheme.Palette.border, lineWidth: 1)
            }
    }
}
