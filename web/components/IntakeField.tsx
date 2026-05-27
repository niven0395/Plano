"use client";

import { Field, inputClasses } from "./Field";
import type { IntakeQuestion } from "@/lib/vendor";

interface IntakeFieldProps {
  question: IntakeQuestion;
  values: string[];
  onChange: (values: string[]) => void;
}

export function IntakeField({ question, values, onChange }: IntakeFieldProps) {
  const fieldId = `intake-${question.id}`;
  const singleValue = values[0] ?? "";

  return (
    <Field
      label={question.prompt}
      htmlFor={fieldId}
      required={question.isRequired}
      hint={question.helperText || undefined}
    >
      {question.responseType === "long_text" ? (
        <textarea
          id={fieldId}
          className={`${inputClasses} min-h-[96px] resize-y`}
          placeholder={question.placeholder || undefined}
          required={question.isRequired}
          value={singleValue}
          onChange={(e) => onChange([e.target.value])}
        />
      ) : question.responseType === "number" ? (
        <input
          id={fieldId}
          type="number"
          inputMode="numeric"
          className={inputClasses}
          placeholder={question.placeholder || undefined}
          required={question.isRequired}
          value={singleValue}
          onChange={(e) => onChange([e.target.value])}
        />
      ) : question.responseType === "single_choice" ? (
        <select
          id={fieldId}
          className={inputClasses}
          required={question.isRequired}
          value={singleValue}
          onChange={(e) => onChange([e.target.value])}
        >
          <option value="">Select…</option>
          {question.options.map((opt) => (
            <option key={opt} value={opt}>
              {opt}
            </option>
          ))}
        </select>
      ) : question.responseType === "multi_choice" ? (
        <div role="group" aria-labelledby={fieldId} className="flex flex-col gap-2">
          {question.options.map((opt) => {
            const checked = values.includes(opt);
            return (
              <label
                key={opt}
                className={`flex cursor-pointer items-center gap-3 rounded-field border px-4 py-3 text-[15px] transition ${
                  checked
                    ? "border-accent/30 bg-white text-ink dark:border-white/30 dark:bg-white/[0.06] dark:text-white"
                    : "border-line bg-white/60 text-ink hover:bg-white dark:border-white/10 dark:bg-white/[0.04] dark:text-white/90"
                }`}
              >
                <input
                  type="checkbox"
                  className="h-4 w-4 accent-accent"
                  checked={checked}
                  onChange={(e) => {
                    const next = new Set(values);
                    if (e.target.checked) next.add(opt);
                    else next.delete(opt);
                    onChange(Array.from(next));
                  }}
                />
                <span>{opt}</span>
              </label>
            );
          })}
        </div>
      ) : (
        <input
          id={fieldId}
          type="text"
          className={inputClasses}
          placeholder={question.placeholder || undefined}
          required={question.isRequired}
          value={singleValue}
          onChange={(e) => onChange([e.target.value])}
        />
      )}
    </Field>
  );
}
