import {
  ensureMethod,
  errorResponse,
  HTTPError,
  jsonResponse,
  optionsResponse,
  parseJSON,
} from "../_shared/http.ts";
import { requireUser } from "../_shared/supabase.ts";

const ALLOWED_PERIODS = new Set([7, 30, 90]);

interface FetchInsightsPayload {
  period_days: 7 | 30 | 90;
}

interface DailyRow {
  search_impressions: number;
  profile_views: number;
  gallery_scrolls: number;
  social_link_clicks: number;
  saves: number;
  unsaves: number;
  conversations_started: number;
  bookings_requested: number;
  bookings_confirmed: number;
  bookings_declined: number;
  bookings_cancelled: number;
  bookings_completed: number;
  revenue_confirmed_cents: number;
  revenue_completed_cents: number;
}

function sumRows(rows: DailyRow[]): DailyRow {
  const zero: DailyRow = {
    search_impressions: 0,
    profile_views: 0,
    gallery_scrolls: 0,
    social_link_clicks: 0,
    saves: 0,
    unsaves: 0,
    conversations_started: 0,
    bookings_requested: 0,
    bookings_confirmed: 0,
    bookings_declined: 0,
    bookings_cancelled: 0,
    bookings_completed: 0,
    revenue_confirmed_cents: 0,
    revenue_completed_cents: 0,
  };

  for (const row of rows) {
    for (const key of Object.keys(zero) as (keyof DailyRow)[]) {
      zero[key] += row[key] ?? 0;
    }
  }

  return zero;
}

function safeDivide(numerator: number, denominator: number): number {
  return denominator === 0 ? 0 : numerator / denominator;
}

function trendPercent(current: number, previous: number): number {
  if (previous === 0) return current === 0 ? 0 : 100;
  return ((current - previous) / previous) * 100;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return optionsResponse();
  }

  try {
    ensureMethod(request, "POST");
    const { serviceClient, user } = await requireUser(request);
    const payload = await parseJSON<FetchInsightsPayload>(request);

    if (!ALLOWED_PERIODS.has(payload.period_days)) {
      throw new HTTPError(400, "period_days must be 7, 30, or 90.");
    }

    const days = payload.period_days;
    const now = new Date();

    const currentStart = new Date(now);
    currentStart.setDate(currentStart.getDate() - days);
    const currentStartStr = currentStart.toISOString().split("T")[0];

    const previousStart = new Date(currentStart);
    previousStart.setDate(previousStart.getDate() - days);
    const previousStartStr = previousStart.toISOString().split("T")[0];

    const todayStr = now.toISOString().split("T")[0];

    // Fetch current and previous period data
    const [currentResult, previousResult] = await Promise.all([
      serviceClient
        .from("vendor_analytics_daily")
        .select("*")
        .eq("vendor_id", user.id)
        .gte("day", currentStartStr)
        .lte("day", todayStr),
      serviceClient
        .from("vendor_analytics_daily")
        .select("*")
        .eq("vendor_id", user.id)
        .gte("day", previousStartStr)
        .lt("day", currentStartStr),
    ]);

    if (currentResult.error) throw new HTTPError(500, currentResult.error.message);
    if (previousResult.error) throw new HTTPError(500, previousResult.error.message);

    const current = sumRows(currentResult.data ?? []);
    const previous = sumRows(previousResult.data ?? []);

    // Derived metrics — current period
    const ctr = safeDivide(current.profile_views, current.search_impressions);
    const messageRate = safeDivide(current.conversations_started, current.profile_views);
    const bookingRate = safeDivide(current.bookings_requested, current.profile_views);
    const conversionRate = safeDivide(current.bookings_confirmed, current.bookings_requested);
    const revenue = current.revenue_confirmed_cents + current.revenue_completed_cents;
    const totalBookings = current.bookings_confirmed + current.bookings_completed;
    const avgBookingValue = safeDivide(revenue, totalBookings);

    // Derived metrics — previous period
    const prevCtr = safeDivide(previous.profile_views, previous.search_impressions);
    const prevMessageRate = safeDivide(previous.conversations_started, previous.profile_views);
    const prevBookingRate = safeDivide(previous.bookings_requested, previous.profile_views);
    const prevConversionRate = safeDivide(previous.bookings_confirmed, previous.bookings_requested);
    const prevRevenue = previous.revenue_confirmed_cents + previous.revenue_completed_cents;
    const prevTotalBookings = previous.bookings_confirmed + previous.bookings_completed;
    const prevAvgBookingValue = safeDivide(prevRevenue, prevTotalBookings);

    // Fetch category benchmarks
    const { data: vendorProfile } = await serviceClient
      .from("vendor_profiles")
      .select("category_id")
      .eq("id", user.id)
      .single();

    let benchmarks = null;
    if (vendorProfile?.category_id) {
      const { data: benchmarkRows } = await serviceClient
        .from("category_benchmarks_daily")
        .select("*")
        .eq("category_id", vendorProfile.category_id)
        .gte("day", currentStartStr)
        .lte("day", todayStr);

      if (benchmarkRows && benchmarkRows.length > 0) {
        const bm = sumRows(benchmarkRows);
        const count = benchmarkRows.length || 1;
        benchmarks = {
          avg_daily_impressions: safeDivide(bm.search_impressions, count),
          avg_daily_profile_views: safeDivide(bm.profile_views, count),
          avg_ctr: safeDivide(bm.profile_views, bm.search_impressions),
          avg_message_rate: safeDivide(bm.conversations_started, bm.profile_views),
          avg_booking_rate: safeDivide(bm.bookings_requested, bm.profile_views),
          avg_conversion_rate: safeDivide(bm.bookings_confirmed, bm.bookings_requested),
        };
      }
    }

    return jsonResponse({
      period_days: days,
      discovery: {
        search_impressions: { value: current.search_impressions, trend: trendPercent(current.search_impressions, previous.search_impressions) },
        profile_views: { value: current.profile_views, trend: trendPercent(current.profile_views, previous.profile_views) },
        ctr: { value: ctr, trend: trendPercent(ctr, prevCtr) },
        gallery_scrolls: { value: current.gallery_scrolls, trend: trendPercent(current.gallery_scrolls, previous.gallery_scrolls) },
        social_link_clicks: { value: current.social_link_clicks, trend: trendPercent(current.social_link_clicks, previous.social_link_clicks) },
        saves: { value: current.saves, trend: trendPercent(current.saves, previous.saves) },
      },
      engagement: {
        conversations_started: { value: current.conversations_started, trend: trendPercent(current.conversations_started, previous.conversations_started) },
        message_rate: { value: messageRate, trend: trendPercent(messageRate, prevMessageRate) },
      },
      conversion: {
        bookings_requested: { value: current.bookings_requested, trend: trendPercent(current.bookings_requested, previous.bookings_requested) },
        bookings_confirmed: { value: current.bookings_confirmed, trend: trendPercent(current.bookings_confirmed, previous.bookings_confirmed) },
        bookings_declined: { value: current.bookings_declined, trend: trendPercent(current.bookings_declined, previous.bookings_declined) },
        bookings_cancelled: { value: current.bookings_cancelled, trend: trendPercent(current.bookings_cancelled, previous.bookings_cancelled) },
        bookings_completed: { value: current.bookings_completed, trend: trendPercent(current.bookings_completed, previous.bookings_completed) },
        booking_rate: { value: bookingRate, trend: trendPercent(bookingRate, prevBookingRate) },
        conversion_rate: { value: conversionRate, trend: trendPercent(conversionRate, prevConversionRate) },
      },
      revenue: {
        total_cents: { value: revenue, trend: trendPercent(revenue, prevRevenue) },
        avg_booking_value_cents: { value: avgBookingValue, trend: trendPercent(avgBookingValue, prevAvgBookingValue) },
      },
      benchmarks,
    });
  } catch (error) {
    return errorResponse(error);
  }
});
