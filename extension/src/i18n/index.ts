// Runtime dictionary. `chrome.i18n` follows the browser UI language only, but Kıpır lets the user pick System
// Default, Türkçe or English (DECISIONS 029), so strings are resolved here. Native tables are the source of truth.
import native from 'virtual:native-strings';
import { browserStrings } from './browser';
import { resolveLanguage, type LanguagePreference } from '../core/presentation';

export type Lang = 'tr' | 'en';
export const tables: Record<Lang, Record<string, string>> = {
  tr: { ...native.tr, ...browserStrings.tr },
  en: { ...native.en, ...browserStrings.en },
};

/** Apple format strings: `%d`, `%@`, `%%` and positional `%1$d`. */
export function format(template: string, args: readonly (string | number)[]): string {
  let next = 0;
  return template.replace(/%(?:(\d+)\$)?([d@%])/g, (_, pos: string | undefined, kind: string) => {
    if (kind === '%') return '%';
    const value = pos ? args[Number(pos) - 1] : args[next++];
    return value === undefined ? '' : String(value);
  });
}

export function translator(lang: Lang) {
  const table = tables[lang];
  return (key: string, ...args: (string | number)[]): string => {
    const value = table[key] ?? tables.en[key] ?? key;
    return args.length ? format(value, args) : value;
  };
}
export type T = ReturnType<typeof translator>;

export function browserLanguages(): readonly string[] {
  return typeof navigator !== 'undefined' ? (navigator.languages?.length ? navigator.languages : [navigator.language]) : [];
}
export function languageFor(pref: LanguagePreference | undefined, preferred: readonly string[] = browserLanguages()): Lang {
  return resolveLanguage(pref, preferred);
}
