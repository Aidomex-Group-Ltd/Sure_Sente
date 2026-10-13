// Storage key migration: sure_sente_* -> sure_sente_* (one-way, preserves drafts).
const OLD = "tugeza_"; const NEW = "sure_sente_";
export function migrateStorageKeys() {
  try {
    let migrated = 0;
    for (let i = localStorage.length - 1; i >= 0; i--) {
      const k = localStorage.key(i);
      if (k && k.startsWith(OLD)) {
        const nk = NEW + k.slice(OLD.length);
        if (localStorage.getItem(nk) === null) {
          localStorage.setItem(nk, localStorage.getItem(k) as string); migrated++;
        }
      }
    }
    if (migrated > 0) {
      for (let i = localStorage.length - 1; i >= 0; i--) {
        const k = localStorage.key(i);
        if (k && k.startsWith(OLD)) localStorage.removeItem(k);
      }
    }
  } catch { /* private mode: ignore */ }
}
export const ssGet = (s: string, d = "") => { try { return localStorage.getItem("sure_sente_" + s) ?? d; } catch { return d; } };
export const ssSet = (s: string, v: string) => { try { localStorage.setItem("sure_sente_" + s, v); } catch {} };
export const ssDel = (s: string) => { try { localStorage.removeItem("sure_sente_" + s); } catch {} };
export const SW_CACHE = "sure-sente-v1";
