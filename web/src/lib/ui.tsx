import { useEffect, useRef, useState, type ReactNode } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";
import { token, online } from "../lib/api";

export const TOWNS = ["Kampala", "Ntinda", "Entebbe", "Jinja"];
export const townGet = () => localStorage.getItem("sure_sente_town") || "Ntinda";
export const townSet = (t: string) => localStorage.setItem("sure_sente_town", t);
export const ALLOWLIST = ["/", "/find", "/services", "/deals", "/post", "/messages", "/me", "/broker", "/applications"];
export function allowReturnTo(r: string | null): string {
  if (!r) return "/";
  if (ALLOWLIST.includes(r)) return r;
  if (r.startsWith("/listings/") || r.startsWith("/profiles/")) {
    if (/^\/[A-Za-z0-9_\-/]+$/.test(r) && !r.includes("..")) return r;
  }
  return "/";
}
export type Pending = { returnTo: string; action: string; listingId?: string; draft?: Record<string, unknown> };
export const pendingGet = (): Pending | null => { try { return JSON.parse(localStorage.getItem("sure_sente_pending") || "null"); } catch { return null; } };
export const pendingSet = (p: Pending | null) => { if (!p) localStorage.removeItem("sure_sente_pending"); else localStorage.setItem("sure_sente_pending", JSON.stringify(p)); };
export function sanitizeDraft(d?: Record<string, unknown>): Record<string, unknown> | undefined {
  if (!d) return undefined;
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(d)) {
    if (/otp|code|token|password|phone/i.test(k)) continue;
    if (typeof v === "string" || typeof v === "number" || typeof v === "boolean") out[k] = v;
  }
  return out;
}
export function relTime(iso?: string): string {
  if (!iso) return "";
  const ms = Date.now() - new Date(iso).getTime();
  if (isNaN(ms)) return "";
  const d = Math.floor(ms / 864e5);
  if (d <= 0) { const h = Math.floor(ms / 36e5); return h <= 0 ? "posted just now" : `posted ${h}h ago`; }
  return `posted ${d}d ago`;
}
// ---- auth gate ----
let sheetState: { action: string; returnTo: string; listingId?: string; draft?: Record<string, unknown>; trigger?: HTMLElement } | null = null;
const listeners = new Set<() => void>();
const emit = () => listeners.forEach((f) => f());
export function requireAuth(actionLabel: string, returnTo: string, draft?: Record<string, unknown>, trigger?: HTMLElement | null) {
  if (token.get()) return true;
  sheetState = { action: actionLabel, returnTo: allowReturnTo(returnTo), listingId: undefined, draft: sanitizeDraft(draft) };
  if (trigger instanceof HTMLElement) sheetState.trigger = trigger;
  else sheetState.trigger = (document.activeElement as HTMLElement) || undefined;
  pendingSet({ returnTo: sheetState.returnTo, action: actionLabel, draft: sheetState.draft });
  emit();
  return false;
}
export function useAuthSheet() {
  const [, tick] = useState(0);
  useEffect(() => { const f = () => tick((n) => n + 1); listeners.add(f); return () => { listeners.delete(f); }; }, []);
  return sheetState;
}
export function AuthSheet() {
  const nav = useNavigate();
  const s = useAuthSheet();
  const firstBtn = useRef<HTMLButtonElement>(null);
  const sheetRef = useRef<HTMLDivElement>(null);
  // 04-UI keyboard: Esc to dismiss; Tab/Shift-Tab cycles inside the dialog
  // (full tab-cycle focus trap, not just first focus).
  useEffect(() => {
    if (!s) return;
    const t = setTimeout(() => firstBtn.current?.focus(), 30);
    const esc = (e: KeyboardEvent) => { if (e.key === "Escape") close(); };
    const tab = (e: KeyboardEvent) => {
      if (e.key !== "Tab" || !sheetRef.current) return;
      const els = Array.from(sheetRef.current.querySelectorAll<HTMLElement>("button"));
      if (els.length === 0) return;
      const first = els[0];
      const last = els[els.length - 1];
      if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
      else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
    };
    window.addEventListener("keydown", esc);
    window.addEventListener("keydown", tab);
    return () => { window.removeEventListener("keydown", esc); window.removeEventListener("keydown", tab); clearTimeout(t); };
  }, [s]); // eslint-disable-line
  if (!s) return null;
  const close = () => { sheetState = null; emit(); s.trigger?.focus?.(); };
  const go = (path: string) => { const st = sheetState; sheetState = null; emit(); nav(path + `?returnTo=${encodeURIComponent(st?.returnTo || "/")}`); };
  return (
    <div className="sheet-ov" onClick={close}>
      <div ref={sheetRef} className="sheet" role="dialog" aria-modal="true" aria-label="Account needed" onClick={(e) => e.stopPropagation()}>
        <h2 style={{ margin: "0 0 6px" }}>Account needed</h2>
        <p>Create an account to {s.action}.</p>
        <button ref={firstBtn} className="btn primary" onClick={() => go("/auth")}>Continue with phone</button>
        <button className="btn secondary" onClick={() => go("/auth")}>Sign in</button>
        <button className="btn2" onClick={close}>Continue browsing</button>
      </div>
    </div>
  );
}
export function Logo({ size = 30 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 40 40" aria-hidden="true">
      <circle cx="14" cy="20" r="10" fill="none" stroke="#0C5C3C" strokeWidth="4" />
      <circle cx="26" cy="20" r="10" fill="none" stroke="#059669" strokeWidth="4" />
      <circle cx="20" cy="20" r="3.4" fill="#F59E0B" />
    </svg>
  );
}
export function HeroArt() {
  return (
    <svg viewBox="0 0 300 150" width="100%" height="120" role="img" aria-label="Artisan at work illustration">
      <rect x="0" y="0" width="300" height="150" rx="18" fill="#E6F4EC" />
      <circle cx="250" cy="30" r="18" fill="#FCD34D" />
      <rect x="30" y="90" width="240" height="10" rx="5" fill="#0C5C3C" opacity=".25" />
      <rect x="60" y="55" width="70" height="40" rx="8" fill="#0C5C3C" />
      <circle cx="150" cy="48" r="14" fill="#F5C99B" />
      <rect x="138" y="62" width="26" height="34" rx="8" fill="#1E3A5F" />
      <rect x="180" y="70" width="60" height="26" rx="6" fill="#FFFDF8" stroke="#E9DFCC" />
      <rect x="188" y="78" width="30" height="5" rx="2" fill="#059669" />
    </svg>
  );
}
export function useOnline() {
  const [on, setOn] = useState(online());
  useEffect(() => {
    const a = () => setOn(true), b = () => setOn(false);
    window.addEventListener("online", a); window.addEventListener("offline", b);
    return () => { window.removeEventListener("online", a); window.removeEventListener("offline", b); };
  }, []);
  return on;
}
export function TownPill() {
  const [t, setT] = useState(townGet());
  const [open, setOpen] = useState(false);
  const geo = () => {
    if (!navigator.geolocation) return;
    navigator.geolocation.getCurrentPosition(() => { townSet(townGet()); setT(townGet()); }, () => {});
  };
  if (!open) return <button className="locpill" onClick={() => setOpen(true)} aria-label={`Location ${t}, change`}>◈ {t} ▾</button>;
  return (
    <span style={{ display: "inline-flex", gap: 4, alignItems: "center", minWidth: 0 }}>
      <select aria-label="Choose town" value={t} onChange={(e) => { setT(e.target.value); townSet(e.target.value); setOpen(false); }} style={{ width: 130 }}>
        {TOWNS.map((x) => <option key={x}>{x}</option>)}
      </select>
      <button className="btn2" style={{ minHeight: 44 }} onClick={geo}>Use my location</button>
    </span>
  );
}
export function Layout({ children, guest }: { children: ReactNode; guest?: boolean }) {
  const nav = useNavigate(); const loc = useLocation();
  const logged = !!token.get();
  const name = localStorage.getItem("sure_sente_name") || "Friend";
  const cur = (p: string) => (loc.pathname === p ? "page" : undefined);
  const out = () => {
    token.clear();
    localStorage.removeItem("sure_sente_profile");
    Object.keys(localStorage).forEach((k) => { if (k.startsWith("sure_sente_draft_private")) localStorage.removeItem(k); });
    nav("/");
  };
  return (
    <div className="shell">
      <header className="topbar">
        <span className="brandrow"><Logo /> <span>Sure Sente</span></span>
        <span className="topsp" />
        {logged ? (<><TownPill /><Link className="iconbtn" to="/messages" aria-label="Notifications">♪</Link><Link className="avatar" to="/me" aria-label="Profile">{name.slice(0, 1).toUpperCase()}</Link></>)
          : (<><Link className="btn2" to="/auth" style={{ minHeight: 44, margin: 0 }}>Sign in</Link></>)}
      </header>
      <main className="main">{children}</main>
      <nav className="tabs" aria-label="Primary">
        <Link to="/" aria-current={cur("/")}><span className="g">⌂</span>Home</Link>
        <Link to="/find" aria-current={cur("/find")}><span className="g">⌕</span>Find</Link>
        <Link to="/post" aria-current={cur("/post")}><span className="g">＋</span>Post</Link>
        <Link to="/messages" aria-current={loc.pathname.startsWith("/messages") ? "page" : undefined}><span className="g">✉</span>Inbox</Link>
        <Link to="/me" aria-current={cur("/me")}><span className="g">☺</span>Me</Link>
      </nav>
      <AuthSheet />
      {!guest && logged && <div className="foot"><button className="linklike" onClick={out}>Sign out</button></div>}
    </div>
  );
}
export function States({ loading, error, empty, onRetry, children }: { loading?: boolean; error?: string | null; empty?: boolean; onRetry?: () => void; children: ReactNode }) {
  if (loading) return <p aria-live="polite">Loading…</p>;
  if (error) return <div role="alert" className="card"><p>Something went wrong: {error}</p>{onRetry && <button className="btn" onClick={onRetry}>Retry</button>}</div>;
  if (empty) return <div className="card"><p>No results yet.</p>{onRetry && <button className="btn" onClick={onRetry}>Retry</button>}</div>;
  return <>{children}</>;
}
export function PayLine({ l }: { l: Record<string, unknown> }) {
  const pay = (l.pay_amount_minor ?? l.pay_minor ?? l.price_minor ?? l.amount_minor) as number | undefined;
  const basis = String(l.pay_basis ?? l.commission_basis ?? l.commission_rule ?? l.basis ?? "total");
  const comm = (l.commission_amount_minor ?? l.commission_minor) as number | undefined;
  return (
    <p className="pay">UGX {pay != null ? Number(pay).toLocaleString() : "—"} total{comm != null ? ` · Commission UGX ${Number(comm).toLocaleString()} (${basis})` : ""}</p>
  );
}
export function ListingCard({ l, area }: { l: Record<string, any>; area: string }) {
  const loc = String(l.coarse_location ?? l.area ?? area);
  const ago = relTime(String(l.inserted_at ?? l.created_at ?? ""));
  const pay = (l.pay_amount_minor ?? l.pay_minor ?? l.price_minor) as number | undefined;
  return (
    <Link className="lrow" to={`/listings/${l.id}`} aria-label={String(l.title || "Listing")}>
      <span className="icochip" aria-hidden="true">{l.kind === "service" ? "✂" : l.kind === "goods" ? "▣" : l.kind === "deal" ? "▣" : "⚒"}</span>
      <span className="lbody"><b>{String(l.title || "Opportunity")}</b><small>{loc}{ago ? ` · ${ago}` : ""}</small><br /><small style={{ color: "#0C5C3C", fontWeight: 700 }}>UGX {pay != null ? Number(pay).toLocaleString() : "—"} total</small></span>
      <span className="chev" aria-hidden="true">›</span>
    </Link>
  );
}
