"use client";

import { useMemo, useRef, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { Field, inputClasses } from "@/components/Field";
import { IntakeField } from "@/components/IntakeField";
import { submitBookingRequest, SubmitError, type IntakeAnswer } from "@/lib/submit";
import type { VendorSummary } from "@/lib/vendor";

interface Props {
  vendor: VendorSummary;
}

interface FormState {
  firstName: string;
  lastName: string;
  email: string;
  eventDate: string;
  guestCount: string;
  note: string;
  intake: Record<string, string[]>;
}

function todayISO(): string {
  const now = new Date();
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, "0");
  const d = String(now.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function initialState(): FormState {
  return {
    firstName: "",
    lastName: "",
    email: "",
    eventDate: "",
    guestCount: "",
    note: "",
    intake: {},
  };
}

export function BookingForm({ vendor }: Props) {
  const router = useRouter();
  const [state, setState] = useState<FormState>(initialState);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const prefetched = useRef(false);
  const today = useMemo(todayISO, []);

  const canSubmit = useMemo(() => {
    if (submitting) return false;
    if (!state.firstName.trim() || !state.lastName.trim()) return false;
    if (!state.email.includes("@")) return false;
    if (!state.eventDate) return false;
    for (const q of vendor.intakeQuestions) {
      if (!q.isRequired) continue;
      const values = state.intake[q.id] ?? [];
      if (!values.some((v) => v.trim().length > 0)) return false;
    }
    return true;
  }, [state, submitting, vendor.intakeQuestions]);

  function setIntake(id: string, values: string[]) {
    setState((s) => ({ ...s, intake: { ...s.intake, [id]: values } }));
  }

  function prefetchSuccess() {
    if (prefetched.current) return;
    prefetched.current = true;
    router.prefetch(`/book/${vendor.id}/success`);
  }

  async function onSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!canSubmit) return;
    setSubmitting(true);
    setError(null);

    const intakeAnswers: IntakeAnswer[] = vendor.intakeQuestions
      .map((q) => {
        const values = (state.intake[q.id] ?? []).filter((v) => v.trim().length > 0);
        if (values.length === 0) return null;
        return {
          questionID: q.id,
          prompt: q.prompt,
          responseType: q.responseType,
          values,
        };
      })
      .filter((v): v is IntakeAnswer => v !== null);

    try {
      await submitBookingRequest({
        vendor_id: vendor.id,
        first_name: state.firstName.trim(),
        last_name: state.lastName.trim(),
        email: state.email.trim(),
        event_date: state.eventDate,
        guest_count: state.guestCount ? Number(state.guestCount) : null,
        note: state.note.trim() || null,
        intake_answers: intakeAnswers.length ? intakeAnswers : null,
        source: "web",
      });
      router.push(
        `/book/${vendor.id}/success?email=${encodeURIComponent(state.email.trim())}`,
      );
    } catch (err) {
      const message =
        err instanceof SubmitError
          ? err.message
          : "Something went wrong. Please check your connection and try again.";
      setError(message);
      setSubmitting(false);
    }
  }

  return (
    <form
      onSubmit={onSubmit}
      onFocus={prefetchSuccess}
      noValidate
      className="flex flex-col gap-5 pb-28 sm:pb-0"
    >
      <div className="grid grid-cols-1 gap-5 sm:grid-cols-2">
        <Field label="First name" htmlFor="firstName" required>
          <input
            id="firstName"
            type="text"
            autoComplete="given-name"
            autoCapitalize="words"
            autoFocus
            required
            className={inputClasses}
            value={state.firstName}
            onChange={(e) => setState((s) => ({ ...s, firstName: e.target.value }))}
          />
        </Field>
        <Field label="Last name" htmlFor="lastName" required>
          <input
            id="lastName"
            type="text"
            autoComplete="family-name"
            autoCapitalize="words"
            required
            className={inputClasses}
            value={state.lastName}
            onChange={(e) => setState((s) => ({ ...s, lastName: e.target.value }))}
          />
        </Field>
      </div>

      <Field
        label="Email"
        htmlFor="email"
        required
        hint={`${vendor.businessName}'s replies will be emailed to you until you install the app.`}
      >
        <input
          id="email"
          type="email"
          inputMode="email"
          autoComplete="email"
          autoCapitalize="none"
          autoCorrect="off"
          spellCheck={false}
          required
          className={inputClasses}
          value={state.email}
          onChange={(e) => setState((s) => ({ ...s, email: e.target.value }))}
        />
      </Field>

      <div
        className={`grid gap-5 ${vendor.collectsGuestCount ? "grid-cols-1 sm:grid-cols-2" : "grid-cols-1"}`}
      >
        <Field label="Event date" htmlFor="eventDate" required>
          <input
            id="eventDate"
            type="date"
            required
            min={today}
            className={inputClasses}
            value={state.eventDate}
            onChange={(e) => setState((s) => ({ ...s, eventDate: e.target.value }))}
          />
        </Field>
        {vendor.collectsGuestCount ? (
          <Field label="Guest count" htmlFor="guestCount">
            <input
              id="guestCount"
              type="number"
              inputMode="numeric"
              min={1}
              placeholder="e.g. 40"
              className={inputClasses}
              value={state.guestCount}
              onChange={(e) => setState((s) => ({ ...s, guestCount: e.target.value }))}
            />
          </Field>
        ) : null}
      </div>

      {vendor.intakeQuestions.map((q) => (
        <IntakeField
          key={q.id}
          question={q}
          values={state.intake[q.id] ?? []}
          onChange={(values) => setIntake(q.id, values)}
        />
      ))}

      <Field label="Anything else?" htmlFor="note">
        <textarea
          id="note"
          rows={3}
          placeholder={`Tell ${vendor.businessName} about your event`}
          className={`${inputClasses} min-h-[96px] resize-y`}
          value={state.note}
          onChange={(e) => setState((s) => ({ ...s, note: e.target.value }))}
        />
      </Field>

      {error ? (
        <p
          role="alert"
          className="rounded-field border border-danger-border bg-danger-bg px-3.5 py-3 text-sm text-danger-ink"
        >
          {error}
        </p>
      ) : null}

      <div className="pointer-events-none fixed inset-x-0 bottom-0 z-10 bg-gradient-to-t from-surface-page via-surface-page/90 to-transparent px-5 pb-[max(env(safe-area-inset-bottom),1rem)] pt-6 dark:from-surface-dark dark:via-surface-dark/90 sm:static sm:bg-none sm:p-0 sm:pt-2 sm:dark:bg-none">
        <button
          type="submit"
          disabled={!canSubmit}
          className="pointer-events-auto flex h-[52px] w-full items-center justify-center rounded-button bg-accent text-[16px] font-semibold text-accent-on shadow-button transition active:scale-[0.98] enabled:hover:opacity-95 disabled:opacity-50 disabled:shadow-none"
        >
          {submitting ? <Spinner /> : "Send request"}
        </button>
      </div>
    </form>
  );
}

function Spinner() {
  return (
    <span
      aria-label="Sending"
      className="inline-block h-5 w-5 animate-spin rounded-full border-2 border-accent-on/30 border-t-accent-on"
    />
  );
}
