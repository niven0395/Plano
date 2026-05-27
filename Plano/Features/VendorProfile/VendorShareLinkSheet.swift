import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

/// Presented from a vendor's own profile/dashboard so they can grab a
/// shareable booking link. Anyone who opens the URL lands on the Next.js
/// booking page (iPhones with the Plano app installed are deep-linked in).
struct VendorShareLinkSheet: View {
    let vendorID: UUID
    let vendorName: String

    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false
    @State private var copyTrigger = 0

    private var bookingURL: URL {
        ExternalBookingURL.bookingURL(vendorID: vendorID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    header
                    qrCard
                    urlRow(url: bookingURL)
                    actionRow(url: bookingURL)
                    tipText
                }
                .padding(.horizontal, 22)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .background(AppTheme.Palette.surface.ignoresSafeArea())
            .navigationTitle("Your booking link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.body.weight(.semibold))
                }
            }
            .sensoryFeedback(.success, trigger: copyTrigger)
        }
        .presentationDetents([.large])
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 6) {
            Text("Share one link. Booked from anywhere.")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.Palette.textPrimary)
            Text("Anyone can tap this link to send \(vendorName) a booking request — no account needed. Post it anywhere you share your work.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
        .padding(.top, 8)
    }

    private var qrCard: some View {
        VStack(spacing: 14) {
            if let qrImage = QRCodeRenderer.image(for: bookingURL) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 220, height: 220)
                    .accessibilityLabel("QR code for your booking link")
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.Palette.inputFill)
                    .frame(width: 220, height: 220)
                    .overlay(
                        Image(systemName: "qrcode")
                            .font(.system(size: 64, weight: .light))
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    )
            }
            Text("Scan or share the link below.")
                .font(.footnote)
                .foregroundStyle(AppTheme.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AppTheme.Palette.elevatedSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(AppTheme.Palette.border, lineWidth: 1)
                )
        )
    }

    private func urlRow(url: URL) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "link")
                .font(.callout)
                .foregroundStyle(AppTheme.Palette.textSecondary)
            Text(url.absoluteString)
                .font(.callout.monospaced())
                .foregroundStyle(AppTheme.Palette.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.Palette.inputFill)
        )
    }

    private func actionRow(url: URL) -> some View {
        VStack(spacing: 12) {
            ShareLink(item: url, subject: Text("Book \(vendorName) on Plano")) {
                Label("Share link", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle())

            Button {
                UIPasteboard.general.string = url.absoluteString
                didCopy = true
                copyTrigger &+= 1
            } label: {
                Label(
                    didCopy ? "Copied" : "Copy link",
                    systemImage: didCopy ? "checkmark" : "doc.on.doc"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
    }

    private var tipText: some View {
        Text("Post this in your Instagram bio or send it to DM inquiries. Every submission lands in your Plano inbox just like an in-app request, and the person gets emails until they install the app.")
            .font(.footnote)
            .multilineTextAlignment(.center)
            .foregroundStyle(AppTheme.Palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - URL builder

enum ExternalBookingURL {
    /// Host pinned by `applinks:` in Plano.entitlements and served by the
    /// Cloudflare Worker that owns the AASA. Changing it requires an
    /// entitlement update + AASA refresh, so it lives here as the single
    /// source of truth for the public booking surface.
    private static let publicHost = "plano-booking.nivensivarajah.workers.dev"

    static func bookingURL(vendorID: UUID) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = publicHost
        components.path = "/book/\(vendorID.uuidString.lowercased())"
        return components.url!
    }

    /// Parses a universal-link URL into one of the external booking routes the
    /// app knows how to handle.
    static func route(from url: URL) -> ExternalBookingLinkRoute? {
        guard let host = url.host else { return nil }
        // Accept both <proj>.supabase.co and any custom domain that proxies to /functions/v1/book/*
        let path = url.path

        // /functions/v1/book/<vendor_id>
        if let range = path.range(of: "/book/") {
            let remainder = String(path[range.upperBound...])
            if remainder.hasPrefix("claim") {
                if let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?
                    .first(where: { $0.name == "token" })?
                    .value, !token.isEmpty {
                    return .claim(token: token)
                }
                return .claim(token: nil)
            }
            if remainder.hasPrefix("success") {
                return nil
            }
            let vendorSegment = remainder.split(separator: "/").first.map(String.init) ?? remainder
            if let vendorID = UUID(uuidString: vendorSegment) {
                return .vendorProfile(vendorID: vendorID)
            }
        }

        // /claim?token=... (when AASA rewrites the canonical path)
        if path == "/claim" || path.hasSuffix("/claim") {
            let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "token" })?
                .value
            return .claim(token: token)
        }

        // /book/<vendor_id> on a custom domain
        if path.hasPrefix("/book/") {
            let remainder = path.replacingOccurrences(of: "/book/", with: "")
            let vendorSegment = remainder.split(separator: "/").first.map(String.init) ?? remainder
            if let vendorID = UUID(uuidString: vendorSegment) {
                return .vendorProfile(vendorID: vendorID)
            }
        }

        _ = host // silence unused warning on custom-domain future use
        return nil
    }
}

enum ExternalBookingLinkRoute: Hashable {
    case vendorProfile(vendorID: UUID)
    case claim(token: String?)
}

// MARK: - QR rendering

enum QRCodeRenderer {
    static func image(for url: URL, scale: CGFloat = 10) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let transformed = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
