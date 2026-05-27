import type { ReactNode } from "react";

interface FieldProps {
  label: string;
  htmlFor: string;
  required?: boolean;
  hint?: string;
  children: ReactNode;
}

export function Field({ label, htmlFor, required, hint, children }: FieldProps) {
  return (
    <div className="flex flex-col gap-2">
      <label
        htmlFor={htmlFor}
        className="text-[13px] font-semibold tracking-tight text-ink-muted dark:text-white/70"
      >
        {label}
        {required ? <span aria-hidden="true"> *</span> : null}
      </label>
      {children}
      {hint ? (
        <p className="text-[12px] leading-relaxed text-ink-subtle dark:text-white/50">
          {hint}
        </p>
      ) : null}
    </div>
  );
}

// Frosted-white fill over the warm page gradient — matches AppTheme input fill.
export const inputClasses =
  "w-full rounded-field border border-line bg-white/60 px-4 py-3.5 text-[16px] text-ink placeholder:text-ink-subtle backdrop-blur-sm transition focus:border-accent/40 focus:bg-white focus:outline-none focus:ring-4 focus:ring-accent/10 disabled:opacity-60 dark:border-white/10 dark:bg-white/[0.04] dark:text-white dark:placeholder:text-white/30 dark:focus:border-white/30 dark:focus:ring-white/10";
