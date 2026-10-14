import { useEffect, useRef, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { get, post, patch, token, queueDraft, online, fmtUGX, type Listing } from "../lib/api";
import { Layout, States, PayLine, ListingCard, TownPill, Logo, requireAuth, townGet } from "../lib/ui";

function useListings(kind?: string) {
  const [rows, setRows] = useState<Listing[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const load = async () => {
    setLoading(true); setError(null);
    try {
      const r = await get<any>(`/listings?limit=20${kind ? `&kind=${kind}` : ""}`);
      const data: Listing[] = Array.isArray(r) ? r : (r.data || r.items || []);
      setRows(data);
    } catch (e) { setError(e instanceof Error ? e.message : "failed"); }
    finally { setLoading(false); }
  };
  useEffect(() => { load(); /* eslint-disable-next-line */ }, [kind]);
  return { rows, loading, error, load };
}

// Hero at very top (mobile + desktop): dynamic promo carousel with
// transparent claymorphism, pause-on-hover, dots + prev/next.
const SLIDES = [
  {
    tag: "Instant Liquidity",
    title: "Find Deals. Earn More. Move Money Forward.",
    subtitle: "Discover quick gigs, earn commissions, and buy or sell products in one marketplace built around opportunity.",
    image: "https://images.unsplash.com/photo-1507679799987-c73779587ccf?auto=format&fit=crop&w=1200&q=70",
    alt: "Business professional",
    badge: "Verified Deals",
    primary: { label: "Explore Deals", to: "/deals" },
    secondary: { label: "Start Earning", to: "/earnings" },
  },
  {
    tag: "Earn Commissions",
    title: "Connect Buyers. Earn Fast Rewards.",
    subtitle: "Promote verified items and business deals to earn instant commissions directly to your wallet.",
    image: "https://images.unsplash.com/photo-1559136555-9303baea8ebd?auto=format&fit=crop&w=1200&q=70",
    alt: "Handshake deal",
    badge: "Up to 15% Comm.",
    primary: { label: "View Commissions", to: "/broker" },
    secondary: { label: "Post an Item", to: "/post" },
  },
  {
    tag: "Quick Gigs",
    title: "High-Paying Short-Term Opportunities.",
    subtitle: "Access curated tasks, consulting gigs, and local quick sales right from your mobile device.",
    image: "https://images.unsplash.com/photo-1521737604893-d14cc237f11d?auto=format&fit=crop&w=1200&q=70",
    alt: "Team collaborating",
    badge: "Immediate Payout",
    primary: { label: "Find Gigs", to: "/find" },
    secondary: { label: "Start Earning", to: "/earnings" },
  },
];

function HeroLux() {
  const [i, setI] = useState(0);
  const [paused, setPaused] = useState(false);
  useEffect(() => {
    if (paused) return;
    const t = setInterval(() => setI((p) => (p + 1) % SLIDES.length), 6000);
    return () => clearInterval(t);
  }, [paused]);
  const s = SLIDES[i];
  return (
    <section className="luxhero" aria-label="Sure Sente highlights" onMouseEnter={() => setPaused(true)} onMouseLeave={() => setPaused(false)}>
      <div className="blob glow-em" style={{ width: 240, height: 240, top: -50, left: -70 }} />
      <div className="blob glow-gold" style={{ width: 220, height: 220, bottom: -60, right: -50 }} />
      <div className="luxgrid">
        <div key={i} className="slide-fade" style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <Logo />
          <span className="tagchip">{s.tag}</span>
        </div>
        <h1 key={"t" + i} className="gold-gradient-text slide-fade">{s.title}</h1>
        <p key={"s" + i} className="muted slide-fade" style={{ maxWidth: "46ch", fontSize: 17, marginTop: 0 }}>{s.subtitle}</p>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
          <Link className="btn primary" to={s.primary.to} style={{ flex: 1 }}>{s.primary.label} →</Link>
          <Link className="btn secondary" to={s.secondary.to} style={{ flex: 1, textAlign: "center" }}>{s.secondary.label}</Link>
        </div>
        <div>
          <div className="clay-card luximgcard">
            <img key={i} src={s.image} alt={s.alt} loading="eager" />
            <div className="clay-card luxoverlay">
              <div><p className="tagchip" style={{ fontSize: 10, padding: "2px 10px", marginBottom: 2 }}>Opportunity Status</p><p style={{ margin: 0, fontWeight: 700 }}>{s.badge}</p></div>
              <Link className="tagchip" style={{ textDecoration: "none" }} to="/deals">View →</Link>
            </div>
          </div>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginTop: 14 }}>
            <div className="dots" style={{ marginTop: 0 }} role="group" aria-label="Carousel slides">
              {SLIDES.map((_, idx) => (
                <button key={idx} aria-label={`Show slide ${idx + 1}`} aria-pressed={idx === i} onClick={() => setI(idx)} />
              ))}
            </div>
            <div style={{ display: "flex", gap: 8 }}>
              <button className="btn2" style={{ minHeight: 44, minWidth: 44, margin: 0 }} aria-label="Previous slide" onClick={() => setI((i - 1 + SLIDES.length) % SLIDES.length)}>‹</button>
              <button className="btn2" style={{ minHeight: 44, minWidth: 44, margin: 0 }} aria-label="Next slide" onClick={() => setI((i + 1) % SLIDES.length)}>›</button>
            </div>
          </div>
        </div>
        <Link className="btn primary" to={token.get() ? "/earnings" : "/auth"} style={{ width: "100%", marginTop: 4 }}>Start Earning →</Link>
        <p style={{ textAlign: "center", margin: 0 }}><small className="muted">Browse first. Sign up only to apply or connect.</small></p>
      </div>
    </section>
  );
}

function ChipRow({ tab, setTab }: { tab: string; setTab: (t: string) => void }) {
  return (
    <div className="chiprow" role="group" aria-label="Category">
      {(["work", "service", "deal"] as const).map((t) => (
        <button key={t} className={"chip" + (tab === t ? " on" : "")} aria-pressed={tab === t} onClick={() => setTab(t)}>
          {t === "work" ? "Work" : t === "service" ? "Services" : "Deals"}
        </button>
      ))}
    </div>
  );
}

function filterRows(rows: Listing[], tab: string) {
  return rows.filter((l) => {
    const k = String((l as any).kind || "");
    if (!k) return true;
    if (tab === "deal") return k.includes("deal") || k.includes("goods");
    return k.includes(tab);
  });
}

export function Home() {
  const logged = !!token.get();
  const [tab, setTab] = useState("work");
  const [area] = useState(townGet());
  const name = localStorage.getItem("sure_sente_name") || "there";
  const [nudgeOff, setNudgeOff] = useState(() => localStorage.getItem("sure_sente_nudge") === "1");
  const { rows, loading, error, load } = useListings();
  const listRef = useRef<HTMLDivElement>(null);
  const filtered = filterRows(rows, tab);
  const seeAll = tab === "deal" ? "/deals" : tab === "service" ? "/services" : "/find";

  if (!logged) {
    const deals = rows.filter((l) => String((l as any).kind || "").includes("goods") || String((l as any).kind || "").includes("deal")).slice(0, 8);
    const gigs = rows.filter((l) => String((l as any).kind || "").includes("work")).slice(0, 4);
    return (
      <Layout guest>
        <HeroLux />
        <div className="secttl"><h2>Featured Marketplace Deals</h2><Link to="/deals">View All →</Link></div>
        <div style={{ display: "flex", gap: 12, overflowX: "auto", paddingBottom: 8, scrollSnapType: "x mandatory" }}>
          {(deals.length ? deals : rows.slice(0, 6)).map((l) => (
            <div key={String(l.id)} className="clay-card" style={{ minWidth: 240, maxWidth: 260, borderRadius: 16, overflow: "hidden", scrollSnapAlign: "start" }}>
              <div style={{ height: 120, background: "rgba(255,255,255,.06)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 32 }} aria-hidden="true">▣</div>
              <div style={{ padding: 12 }}>
                <b style={{ display: "block", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{String((l as any).title || "Deal")}</b>
                <p className="pay" style={{ margin: "4px 0" }}>{fmtUGX(Number((l as any).pay_amount_minor ?? (l as any).price_minor ?? 0))}</p>
                <Link className="btn2" to={`/listings/${(l as any).id}`} style={{ width: "100%", textAlign: "center", minHeight: 40 }}>View Details</Link>
              </div>
            </div>
          ))}
        </div>
        <div className="card"><h3>⚡ High Commission Deals</h3>
          {gigs.slice(0, 3).map((l) => (
            <div key={String(l.id)} className="lrow"><span className="lbody"><b>{String((l as any).title)}</b><small>Earn commission per sale</small></span><Link className="btn primary" style={{ minHeight: 40 }} to={`/listings/${(l as any).id}`}>Promote</Link></div>
          ))}
          <p><Link to="/broker">Explore →</Link></p>
        </div>
        <ChipRow tab={tab} setTab={setTab} />
        <div className="secttl"><h2>Explore near you</h2><TownPill /></div>
        <div className="card" id="explore" ref={listRef}><States loading={loading} error={error} empty={!loading && !error && filtered.length === 0} onRetry={load}>
          <>{filtered.slice(0, 6).map((l) => <ListingCard key={String(l.id)} l={l as any} area={area} />)}</>
        </States></div>
        <p><Link className="btn2" to={seeAll}>See all</Link></p>
        <div className="foot"><Link to="/help#terms">Terms</Link> | <Link to="/help#privacy">Privacy</Link> | <Link to="/help">Help</Link><p><small className="muted">Sure Sente™ by Aidomex Group Ltd · © 2026 All rights reserved.</small></p></div>
      </Layout>
    );
  }
  return (
    <Layout>
      <h2 style={{ margin: "6px 0 0", fontSize: 16, fontWeight: 500 }}>Welcome, {name}</h2>
      <h1 style={{ margin: "0 0 6px", fontSize: 24 }}>Your next opportunity</h1>
      {!nudgeOff && (
        <div className="nudge" role="note"><span aria-hidden="true">✦</span>
          <span style={{ flex: 1 }}>Add your skills to find better matches. <Link to="/me">Complete profile →</Link></span>
          <button className="linklike" aria-label="Dismiss" onClick={() => { setNudgeOff(true); localStorage.setItem("sure_sente_nudge", "1"); }}>✕</button>
        </div>
      )}
      <ChipRow tab={tab} setTab={setTab} />
      <div className="secttl"><h2>Near you</h2><Link to={seeAll}>See all</Link></div>
      <div className="card"><States loading={loading} error={error} empty={!loading && !error && filtered.length === 0} onRetry={load}>
        <>{filtered.slice(0, 8).map((l) => <ListingCard key={String(l.id)} l={l as any} area={area} />)}</>
      </States></div>
      <Link className="btn primary" to="/post" style={{ width: "100%" }}>Post a need</Link>
    </Layout>
  );
}

export function Find() {
  const [q, setQ] = useState("");
  const [rows, setRows] = useState<Listing[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [area] = useState(townGet());
  const go = async () => {
    setLoading(true); setError(null);
    try {
      const r = await get<any>(`/listings?limit=20&q=${encodeURIComponent(q)}`);
      setRows(Array.isArray(r) ? r : r.data || []);
    } catch (e) { setError(e instanceof Error ? e.message : "failed"); } finally { setLoading(false); }
  };
  useEffect(() => { go(); /* eslint-disable-next-line */ }, []);
  return (
    <Layout guest>
      <h2>Find Work</h2>
      <form onSubmit={(e) => { e.preventDefault(); go(); }}>
        <label>Search <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Find work, services or deals" /></label>
        <button className="btn primary" type="submit">Search</button>
      </form>
      <States loading={loading} error={error} empty={!loading && !error && rows.length === 0} onRetry={go}>
        <div className="card">{rows.map((l) => <ListingCard key={String(l.id)} l={l as any} area={area} />)}</div>
      </States>
      <p><Link className="btn2" to="/services">Services</Link> <Link className="btn2" to="/deals">Deals</Link></p>
    </Layout>
  );
}

export function SimpleList({ title, kind }: { title: string; kind: string }) {
  const { rows, loading, error, load } = useListings(kind);
  const [area] = useState(townGet());
  return <Layout guest><h2>{title}</h2><div className="card"><States loading={loading} error={error} empty={!loading && !error && rows.length === 0} onRetry={load}>
    <>{rows.map((l) => <ListingCard key={String(l.id)} l={l as any} area={area} />)}</>
  </States></div></Layout>;
}

export function Detail() {
  const { id } = useParams();
  const nav = useNavigate();
  const [l, setL] = useState<any | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [msg, setMsg] = useState("");
  const [reviews, setReviews] = useState<any[]>([]);
  const load = async () => {
    setLoading(true);
    try {
      const d = await get<any>(`/listings/${id}`);
      setL((d as any).data ?? d);
      try {
        const r = await get<any>(`/listings/${id}/reviews`);
        setReviews(Array.isArray(r) ? r : r.data || []);
      } catch { /* ignore */ }
      setError(null);
    } catch (e) { setError(e instanceof Error ? e.message : "failed"); } finally { setLoading(false); }
  };
  useEffect(() => { load(); /* eslint-disable-next-line */ }, [id]);
  const gate = (label: string, draft?: Record<string, unknown>) => (e: React.MouseEvent) =>
    requireAuth(label, `/listings/${id}`, draft, e.currentTarget as HTMLElement);
  const applyAuthed = async () => {
    try { await post(`/listings/${id}/applications`, { cover_note: "I am available." }); setMsg("Application sent. Status: pending.");    } catch (e) { if (!online()) { queueDraft("application", { listing_id: id }); setMsg("Offline. Draft saved on device."); } else setMsg(e instanceof Error ? e.message : "failed"); }
  };
  // Authenticated actions (04-UI: auth at action boundary, then real actions).
  const messageSeller = async () => {
    try {
      const c = await post<any>("/conversations", { subject_type: "listing", subject_id: id, participant_ids: [(l as any)?.owner?.id].filter(Boolean) });
      const cid = c?.id || c?.data?.id;
      if (cid) nav(`/messages/${cid}`); else setMsg("Conversation opened.");
    } catch (e) { setMsg(e instanceof Error ? e.message : "failed"); }
  };
  const quoteRequest = async () => {
    const amt = prompt("Requested price in UGX (e.g. 50000):", "50000");
    if (!amt) return;
    try { await post(`/listings/${id}/quotes`, { amount_minor: Number(amt) || 0, currency: "UGX" }); setMsg("Quote request sent. Status: pending."); }
    catch (e) { setMsg(e instanceof Error ? e.message : "failed"); }
  };
  const brokerAccess = async () => {
    try { await post(`/listings/${id}/broker-requests`, {}); setMsg("Brokerage authorisation requested. Pending until the seller approves."); }
    catch (e) { setMsg(e instanceof Error ? e.message : "failed"); }
  };
  const owner = (l?.owner || {}) as any;
  const rolesTxt = owner.roles && typeof owner.roles === "object"
    ? Object.entries(owner.roles).filter(([, v]) => v).map(([k]) => k).join(", ") || "—"
    : String(owner.roles || "—");
  return (
    <Layout guest><States loading={loading} error={error} empty={!loading && !error && !l} onRetry={load}>
      {l && <>
        <h2>{String(l.title || "Detail")}</h2>
        <p className="muted">{String(l.coarse_location || l.area || townGet())} · {String(l.status || "published")}</p>
        <PayLine l={l} />
        <p>Schedule: {String(l.schedule || l.pay_basis || "see description")}</p>
        <p>{String(l.description || "Scope, hours, tools shown when available.")}</p>
        <p className="muted">Approximate area only — exact address is never shown publicly.</p>
        <div className="card">
          <h3>Seller</h3>
          <p><Link to={`/profiles/${owner.id || ""}`}>{String(owner.display_name || "Seller")}</Link> · <span className="verified-tag">{owner.verification ? String(owner.verification) : "Unverified"}</span></p>
          <p className="muted">Roles: {rolesTxt}</p>
        </div>
        <div className="card"><h3>Reviews</h3>{reviews.length === 0 ? <p className="muted">No public reviews yet.</p> : reviews.slice(0, 10).map((r: any, i: number) => <p key={String(r.id || i)}>{String(r.body || r.comment || "(review)")} {r.rating ? `· ${r.rating}/5` : ""}</p>)}</div>
        <div className="row">
          <button className="btn primary" onClick={(e) => { if (token.get()) applyAuthed(); else gate("apply to this job")(e); }}>Apply</button>
          <button className="btn secondary" onClick={(e) => { if (token.get()) messageSeller(); else gate("message the seller")(e); }}>Message</button>
          <button className="btn2" onClick={(e) => { if (token.get()) quoteRequest(); else gate("request a quote")(e); }}>Quote</button>
          <button className="btn2" onClick={(e) => { if (token.get()) brokerAccess(); else gate("request brokerage")(e); }}>Broker request</button>
          <button className="btn2" onClick={(e) => { if (token.get()) nav("/broker"); else gate("send a referral")(e); }}>Referral</button>
        </div>
        <p aria-live="polite">{msg}</p>
      </>}
    </States></Layout>
  );
}

export function PostWizard() {
  const logged = !!token.get();
  const [step, setStep] = useState(0);
  const [cats, setCats] = useState<any[]>([]);
  const [f, setF] = useState<any>(() => { try { return JSON.parse(localStorage.getItem("sure_sente_draft") || '{"title":"","kind":"work","category_id":"","pay_amount_minor":"","area":"Ntinda","description":""}'); } catch { return { title: "", kind: "work" }; } });
  const [id, setId] = useState<string | null>(null);
  const [err, setErr] = useState("");
  useEffect(() => { localStorage.setItem("sure_sente_draft", JSON.stringify(f)); }, [f]);
  // 06-CATEGORIES: only open pilot categories are selectable server-side.
  useEffect(() => {
    if (logged && cats.length === 0) get<any>("/categories").then((d) => setCats(Array.isArray(d) ? d : d?.data || d || [])).catch(() => {});
  }, [logged, cats.length]);
  const set = (k: string, v: string) => setF((p: any) => ({ ...p, [k]: v }));
  if (!logged) {
    return (
      <Layout guest>
        <div className="card"><h2>Post a need</h2>
          <p>You need an account to post. Your browsing stays intact.</p>
          <button className="btn primary" style={{ width: "100%" }} onClick={(e) => requireAuth("post a need", "/post", { kind: f.kind, title: f.title }, e.currentTarget)}>Continue with phone</button>
          <Link className="btn2" to="/" style={{ width: "100%", textAlign: "center" }}>Continue browsing</Link>
        </div>
      </Layout>
    );
  }
  const draft = async () => {
    setErr("");
    try {
      // 02-Q01: pay and scope must be visible — send spec field names
      // (pay_amount_minor, coarse_location); server validates aliases too.
      const payload = {
        title: f.title,
        kind: f.kind,
        category_id: f.category_id || undefined,
        pay_amount_minor: Number(f.pay_amount_minor) || 30000,
        coarse_location: f.area,
        description: f.description,
      };
      const d = await post<any>("/listings", payload);
      setId(String((d as any).data?.id ?? (d as any).id)); setStep(3);
    } catch (e) { if (!online()) { queueDraft("listing", f); setErr("Offline. Draft saved on device, not published."); } else setErr(e instanceof Error ? e.message : "failed"); }
  };
  const publish = async (e: React.MouseEvent) => {
    if (!token.get()) { requireAuth("publish this listing", "/post", undefined, e.currentTarget as HTMLElement); return; }
    if (!id) return;
    await post(`/listings/${id}/publish`, {});
    localStorage.removeItem("sure_sente_draft");
    location.hash = "";
    window.location.href = `/listings/${id}`;
  };
  return (
    <Layout>
      <h2>Post a need ({step + 1}/4)</h2>
      {step === 0 && <><label>Type <select value={f.kind} onChange={(e) => set("kind", e.target.value)}><option value="work">Work</option><option value="service">Service</option><option value="deal">Goods/Deal</option></select></label><button className="btn primary" onClick={() => setStep(1)}>Continue</button></>}
      {step === 1 && <><label>Title <input value={f.title} onChange={(e) => set("title", e.target.value)} /></label>
        <label>Category <select value={f.category_id || ""} onChange={(e) => set("category_id", e.target.value)} aria-label="Category"><option value="">(auto — first open pilot)</option>{cats.map((c: any) => <option key={c.id} value={c.id}>{String(c.name || c.key)}</option>)}</select></label>
        <label>Pay/price UGX <input inputMode="numeric" value={f.pay_amount_minor} onChange={(e) => set("pay_amount_minor", e.target.value)} /></label><label>Area <input value={f.area} onChange={(e) => set("area", e.target.value)} /></label><button className="btn primary" onClick={() => setStep(2)}>Continue</button></>}
      {step === 2 && <><label>Details <textarea value={f.description} onChange={(e) => set("description", e.target.value)} /></label><p className="hint">Small photos only (jpg/png/webp, max 5MB).</p><button className="btn primary" onClick={draft}>Save draft</button></>}
      {step === 3 && <><div className="card"><h3>{f.title || "(untitled)"}</h3><p>Pay: {fmtUGX(Number(f.pay_amount_minor) || 0)} · basis: total</p><p>Draft saved. It has not been published.</p></div><button className="btn primary" onClick={publish}>Publish</button></>}
      {err && <p role="alert">{err}</p>}
    </Layout>
  );
}

export function Applications() {
  const [note, setNote] = useState("");
  const [aid, setAid] = useState("");
  const [rows, setRows] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  // 03-IA ownership: workers see their applications; employers see
  // applications to their own listings — server scopes both.
  const load = () => {
    get<any>("/applications")
      .then((d) => { setRows((d?.applications ?? d?.data?.applications ?? d) || []); setLoading(false); })
      .catch(() => setLoading(false));
  };
  useEffect(() => { load(); /* eslint-disable-next-line */ }, []);
  const sendOffer = async (accept: boolean) => {
    try {
      if (accept) await post(`/offers/${aid}/accept`, {}, true);
      else await post(`/applications/${aid}/offers`, { pay_minor: 30000, scope_text: "Offer v1" });
      setNote(accept ? "Accepted. Confirm: scope for amount, payable on completion." : "Offer sent. Status: pending.");
    } catch (e) { setNote(e instanceof Error ? e.message : "failed"); }
  };
  const booking = async (to: string) => { try { await post(`/bookings/${aid}/events`, { to }); setNote(`Booking: ${to}.`); } catch (e) { setNote(e instanceof Error ? e.message : "failed"); } };
  return (
    <Layout><h2>Applications &amp; offers</h2>
      <div className="card"><h3>Your applications and offers</h3>
        {loading ? <p className="muted">Loading…</p> : rows.length === 0 ? <p className="muted">No applications yet. Apply from a listing page.</p> : rows.slice(0, 12).map((r) => (
          <div key={r.id} className="card" style={{ margin: "6px 0" }}>
            <p><b>{String(r.listing_title || "Listing")}</b> <span className="muted">({String(r.listing_kind || "")})</span></p>
            <p className="muted">Status: <strong>{String(r.status || "submitted")}</strong> · {r.role === "owner" ? "Application to your listing" : "Your application"} · Pay {fmtUGX(r.pay_amount_minor)}</p>
            {r.cover_note ? <p className="muted">Note: {String(r.cover_note)}</p> : null}
            <p><button className="btn2" onClick={() => { setAid(String(r.id)); setNote(`Using ID ${String(r.id).slice(0, 8)}… for the actions below.`); }}>Use this ID</button></p>
          </div>
        ))}
      </div>
      <label>Application/offer/booking ID <input value={aid} onChange={(e) => setAid(e.target.value)} placeholder="paste id" /></label>
      <div className="row"><button className="btn primary" onClick={() => sendOffer(false)}>Send offer</button>
        <button className="btn secondary" onClick={() => sendOffer(true)}>Accept offer</button></div>
      <div className="row"><button className="btn2" onClick={() => booking("accepted")}>Accept booking</button>
        <button className="btn2" onClick={() => booking("completed")}>Complete</button>
        <button className="btn2" onClick={() => booking("cancelled")}>Cancel</button></div>
      <p aria-live="polite">{note}</p>
      <label>Quote for service listing <input id="qid" placeholder="listing id" /></label>
      <button className="btn2" onClick={async () => { const v = (document.getElementById("qid") as HTMLInputElement).value; try { await post(`/listings/${v}/quotes`, { amount_minor: 50000, currency: "UGX" }); setNote("Quote sent. Status: pending."); } catch (e) { setNote(e instanceof Error ? e.message : "failed"); } }}>Request quote</button>
      <p><button className="btn2" onClick={async () => { try { await patch(`/listings/${aid}`, { title: "Updated" }); setNote("Listing updated."); } catch (e) { setNote(e instanceof Error ? e.message : "failed"); } }}>Update listing</button></p>
    </Layout>
  );
}

export function Broker() {
  const [ids, setIds] = useState({ listing: "", agreement: "", referral: "", claim: "" });
  const [note, setNote] = useState("");
  const [attr, setAttr] = useState("");
  const s = (k: keyof typeof ids) => ({ value: ids[k], onChange: (e: React.ChangeEvent<HTMLInputElement>) => setIds((p) => ({ ...p, [k]: e.target.value })) });
  const run = async (fn: () => Promise<unknown>, ok: string) => { try { const r = await fn(); setNote(ok + " " + JSON.stringify(r).slice(0, 200)); } catch (e) { setNote(e instanceof Error ? e.message : "failed"); } };
  return (
    <Layout><h2>Broker flow</h2>
      <label>Listing ID <input {...s("listing")} /></label>
      <button className="btn primary" onClick={() => run(() => post(`/listings/${ids.listing}/broker-requests`, {}), "Authorisation requested. Status: pending.")}>Request authorisation</button>
      <label>Agreement ID <input {...s("agreement")} /></label>
      <button className="btn2" onClick={() => run(() => post(`/agreements/${ids.agreement}/accept`, {}, true), "Agreement version accepted.")}>Accept agreement</button>
      <label>Referral fields: use agreement ID + buyer consent ref <input {...s("referral")} placeholder="referral id (for attribution)" /></label>
      <button className="btn2" onClick={() => {
        const ref = prompt("Buyer consent ref (required):"); if (!ref) { setNote("Buyer consent required."); return; }
        const phone = prompt("Buyer phone (required):"); if (!phone) { setNote("Buyer phone required."); return; }
        run(() => post(`/agreements/${ids.agreement}/referrals`, { listing_id: ids.listing, buyer_phone: phone, buyer_consent_at: new Date().toISOString(), consent_ref: ref }, true), "Referral recorded.");
      }}>Record consented referral</button>
      <div className="row"><button className="btn2" onClick={() => run(() => post(`/referrals/${ids.referral}/attribution`, { decision: "accepted" }), "Attribution confirmed.")}>Confirm attribution</button>
        <button className="btn2" onClick={async () => { try { const r = await post(`/referrals/${ids.referral}/outcome`, { milestone: "completed", amount_minor: 40000, currency: "UGX" }); setAttr(JSON.stringify(r).slice(0, 200)); } catch (e) { setAttr(e instanceof Error ? e.message : "failed"); } }}>Record outcome/claim</button></div>
      <p>Attribution: {attr || "pending"}</p>
      <label>Claim ID <input {...s("claim")} /></label>
      <button className="btn2" onClick={() => run(() => post(`/claims/${ids.claim}/payment-report`, { amount_minor: 40000 }, true), "Payment reported (not yet received).")}>Report payment</button>
      <button className="btn2" onClick={() => run(() => post(`/claims/${ids.claim}/acknowledge`, {}), "Payment acknowledged as received.")}>Acknowledge receipt</button>
      <p aria-live="polite">{note}</p>
    </Layout>
  );
}
