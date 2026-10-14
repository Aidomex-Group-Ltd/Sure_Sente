const BASE = (import.meta.env.VITE_API_URL as string | undefined)?.replace(/\/$/, "") || "http://localhost:4000/api/v1";
export const token = {
  get: () => localStorage.getItem("sure_sente_token") || "",
  set: (t: string) => localStorage.setItem("sure_sente_token", t),
  clear: () => localStorage.removeItem("sure_sente_token"),
};
export const online = () => navigator.onLine;
function uid() { return Math.random().toString(36).slice(2) + Date.now().toString(36); }
export async function api<T>(path: string, opts: RequestInit = {}, idempotent = false): Promise<T> {
  const headers: Record<string, string> = { "Content-Type": "application/json", ...((opts.headers as Record<string,string>) || {}) };
  const t = token.get();
  if (t) headers["Authorization"] = `Bearer ${t}`;
  if (idempotent) headers["Idempotency-Key"] = uid();
  let res: Response;
  try { res = await fetch(BASE + path, { ...opts, headers }); }
  catch { throw new Error("offline"); }
  const body = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(body?.error?.message || `Error ${res.status}`);
  return body.data as T;
}
export const get = <T,>(p: string) => api<T>(p);
export const post = <T,>(p: string, data: unknown = {}, idem = false) =>
  api<T>(p, { method: "POST", body: JSON.stringify(data) }, idem);
export const put = <T,>(p: string, data: unknown = {}) =>
  api<T>(p, { method: "PUT", body: JSON.stringify(data) });
export const patch = <T,>(p: string, data: unknown = {}) =>
  api<T>(p, { method: "PATCH", body: JSON.stringify(data) });
export const fmtUGX = (minor?: number | null) =>
  minor == null ? "—" : `UGX ${Number(minor).toLocaleString()}`;
// localStorage draft queue for offline note
export function queueDraft(kind: string, payload: unknown) {
  const q = JSON.parse(localStorage.getItem("sure_sente_queue") || "[]");
  q.push({ kind, payload, at: new Date().toISOString() });
  localStorage.setItem("sure_sente_queue", JSON.stringify(q));
}
export function queueCount() {
  try { return (JSON.parse(localStorage.getItem("sure_sente_queue") || "[]") as unknown[]).length; } catch { return 0; }
}
export type Listing = Record<string, unknown> & { id: string; title?: string; kind?: string; area?: string; pay_minor?: number; price_minor?: number; commission_minor?: number; commission_rule?: string; commission_basis?: string; status?: string; category_id?: string; description?: string };
