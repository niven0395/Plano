import Foundation

nonisolated struct VendorInsightsRecord: Codable, Hashable, Sendable {
    let discovery: DiscoveryInsights
    let engagement: EngagementInsights
    let conversion: ConversionInsights
    let revenue: RevenueInsights
    let benchmarks: CategoryBenchmarkInsights?

    struct DiscoveryInsights: Codable, Hashable, Sendable {
        let profileViews: Int
        let profileViewsTrend: Double
        let uniqueViewers: Int
        let searchImpressions: Int
        let searchImpressionsTrend: Double
        let clickThroughRate: Double
        let clickThroughRateTrend: Double
        let topSearchQueries: [SearchQueryEntry]
        let avgSearchPosition: Double?

        enum CodingKeys: String, CodingKey {
            case profileViews = "profile_views"
            case profileViewsTrend = "profile_views_trend"
            case uniqueViewers = "unique_viewers"
            case searchImpressions = "search_impressions"
            case searchImpressionsTrend = "search_impressions_trend"
            case clickThroughRate = "click_through_rate"
            case clickThroughRateTrend = "click_through_rate_trend"
            case topSearchQueries = "top_search_queries"
            case avgSearchPosition = "avg_search_position"
        }
    }

    struct EngagementInsights: Codable, Hashable, Sendable {
        let saveCount: Int
        let saveRate: Double
        let saveRateTrend: Double
        let galleryEngagements: Int
        let socialLinkClicks: Int

        enum CodingKeys: String, CodingKey {
            case saveCount = "save_count"
            case saveRate = "save_rate"
            case saveRateTrend = "save_rate_trend"
            case galleryEngagements = "gallery_engagements"
            case socialLinkClicks = "social_link_clicks"
        }
    }

    struct ConversionInsights: Codable, Hashable, Sendable {
        let messageInitiationRate: Double
        let messageInitiationRateTrend: Double
        let bookingRequestRate: Double
        let bookingRequestRateTrend: Double
        let leadToBookingConversion: Double
        let leadToBookingConversionTrend: Double
        let avgResponseMinutes: Double?
        let avgResponseMinutesTrend: Double
        let conversationsStarted: Int
        let bookingsRequested: Int
        let bookingsConfirmed: Int

        enum CodingKeys: String, CodingKey {
            case messageInitiationRate = "message_initiation_rate"
            case messageInitiationRateTrend = "message_initiation_rate_trend"
            case bookingRequestRate = "booking_request_rate"
            case bookingRequestRateTrend = "booking_request_rate_trend"
            case leadToBookingConversion = "lead_to_booking_conversion"
            case leadToBookingConversionTrend = "lead_to_booking_conversion_trend"
            case avgResponseMinutes = "avg_response_minutes"
            case avgResponseMinutesTrend = "avg_response_minutes_trend"
            case conversationsStarted = "conversations_started"
            case bookingsRequested = "bookings_requested"
            case bookingsConfirmed = "bookings_confirmed"
        }
    }

    struct RevenueInsights: Codable, Hashable, Sendable {
        let totalRevenueCents: Int
        let totalRevenueTrend: Double
        let avgBookingValueCents: Int
        let avgBookingValueTrend: Double
        let bookingVolume: Int
        let bookingVolumeTrend: Double

        enum CodingKeys: String, CodingKey {
            case totalRevenueCents = "total_revenue_cents"
            case totalRevenueTrend = "total_revenue_trend"
            case avgBookingValueCents = "avg_booking_value_cents"
            case avgBookingValueTrend = "avg_booking_value_trend"
            case bookingVolume = "booking_volume"
            case bookingVolumeTrend = "booking_volume_trend"
        }
    }

    struct CategoryBenchmarkInsights: Codable, Hashable, Sendable {
        let category: String
        let categoryAvgResponseMinutes: Double?
        let categoryAvgConversionRate: Double?
        let categoryAvgProfileViews: Double?
        let categoryMedianRating: Double?
        let categoryVendorCount: Int

        enum CodingKeys: String, CodingKey {
            case category
            case categoryAvgResponseMinutes = "category_avg_response_minutes"
            case categoryAvgConversionRate = "category_avg_conversion_rate"
            case categoryAvgProfileViews = "category_avg_profile_views"
            case categoryMedianRating = "category_median_rating"
            case categoryVendorCount = "category_vendor_count"
        }
    }

    struct SearchQueryEntry: Codable, Hashable, Sendable {
        let query: String
        let count: Int
    }
}
