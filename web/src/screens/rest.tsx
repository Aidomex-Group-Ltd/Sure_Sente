import { useEffect, useState } from "react";
import { Link, useNavigate, useParams, useSearchParams } from "react-router-dom";
import { get, post, token, queueDraft, online } from "../lib/api";
import { Layout, States, allowReturnTo, pendingGet, pendingSet } from "../lib/ui";

export function Auth() {
  const nav = useNavigate();
  const [sp] = useSearchParams();
  const returnTo = allowReturnTo(sp.get("returnTo") || pendingGet()?.returnTo || "/");
  const pending = pendingGet();
  const [phone, setPhone] = useState("");
  const [code, setCode] = useState("");
  const [step, setStep] = useState(0);
  const [devCode, setDevCode] = useState("");
  const [err, setErr] = useState("");
  const [notice, setNotice] = useState("");
  const req = async () => {
    setErr("");
    try {
      const d = await post<any>("/auth/request-code", { phone });
      setDevCode(d?.code || d?.data?.code || "");
      pendingSet({ returnTo, action: pending?.action || "continue", draft: pending?.draft });
      setStep(1);
    } catch (e) { setErr(e instanceof Error ? e.message : "failed"); }
  };
  const verify = async () => {
    try {
      const d = await post<any>("/auth/verify-code", { phone, code });
      const t = d?.token || d?.data?.token || "";
      token.set(t);
      const u = d?.user || d?.data?.user || {};
      if (u.display_name || u.name) localStorage.setItem("tugeza_name", String(u.display_name || u.name));
      const p = pendingGet();
      pendingSet(null);
      if (p?.returnTo && p.returnTo !== "/") { setNotice(`Welcome — review and confirm to continue: ${p.action || "your action"}`); setTimeout(() => nav(p.returnTo), 900); }
      else { nav("/"); }
    } catch { setErr("Code expired or invalid. Request another."); }
  };
  return (
    <Layout guest><h2>Sign in</h2>
      {pending && <p className="notice" role="note">Pending: {pending.action} — you will return to {pending.returnTo}. Nothing is submitted automatically.</p>}
      {notice && <p className="notice" role="status">{notice}</p>}
      {step === 0 && <><label>Phone <input value={phone} onChange={(e) => setPhone(e.target.value)} inputMode="tel" placeholder="+256…" /></label><button className="btn primary" onClick={req}>Continue</button></>}
      {step === 1 && <><p>Enter code{devCode && <> (dev code: <strong>{devCode}</strong>)</>}</p><label>Code <input value={code} onChange={(e) => setCode(e.target.value)} inputMode="numeric" /></label><button className="btn primary" onClick={verify}>Verify</button></>}
      {err && <p role="alert">{err}</p>}
      <p><Link className="btn2" to={returnTo}>Continue browsing</Link></p>
    </Layout>
  );
}

export function Messages() {
  const logged = !!token.get();
  const [text, setText] = useState("");
  const [note, setNote] = useState("");
  const [cid, setCid] = useState("");
  if (!logged) {
    return (
      <Layout guest><div className="card"><h2>Inbox</h2>
        <p>You need an account to read and send messages.</p>
        <Link className="btn primary" to="/auth?returnTo=%2Fmessages" style={{ width: "100%" }}>Continue with phone</Link>
        <Link className="btn2" to="/" style={{ width: "100%", textAlign: "center" }}>Continue browsing</Link>
      </div></Layout>
    );
  }
  const create = async () => {
    try {
      const [a, b] = text.split(",").map((s) => s.trim());
      const d = await post<any>("/conversations", { participant_ids: [a, b].filter(Boolean) });
      const id2 = d?.id || JSON.stringify(d);
      setCid(id2); setNote("Conversation opened: " + id2);
    } catch (e) { setNote(e instanceof Error ? e.message : "failed"); }
  };
  return (
    <Layout><h2>Messages</h2>
      <label>Start conversation (participant ids, comma separated) <input value={text} onChange={(e) => setText(e.target.value)} /></label>
      <button className="btn primary" onClick={create}>New conversation</button>
      <label>Open conversation ID <input value={cid} onChange={(e) => setCid(e.target.value)} /></label>
      <p>{cid ? <Link className="btn secondary" to={`/messages/${cid}`}>Open conversation</Link> : "No conversations yet."}</p>
      <p aria-live="polite">{note}</p>
    </Layout>
  );
}

export function Conversation() {
  const { id } = useParams();
  const [rows, setRows] = useState<{ id?: string; body?: string }[]>([]);
  const [body, setBody] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const load = async () => {
    setLoading(true);
    try {
      const d = await get<any>(`/conversations/${id}/messages`);
      setRows(Array.isArray(d) ? d : d.data); setError(null);
    } catch (e) { setError(e instanceof Error ? e.message : "failed"); } finally { setLoading(false); }
  };
  useEffect(() => { load(); /* eslint-disable-next-line */ }, []);
  const send = async () => {
    try { await post(`/conversations/${id}/messages`, { body }, true); setBody(""); load(); }
    catch { if (!online()) { queueDraft("message", { conv: id, body }); setBody(""); } }
  };
  return (
    <Layout><h2>Conversation</h2>
      <States loading={loading} error={error} empty={!loading && !error && rows.length === 0} onRetry={load}>
        <>{rows.map((m, i) => <p key={String(m.id || i)} className="card">{String(m.body || "(message)")}</p>)}</>
      </States>
      <form onSubmit={(e) => { e.preventDefault(); send(); }}><label>Message <input value={body} onChange={(e) => setBody(e.target.value)} /></label><button className="btn primary" type="submit">Send</button></form>
    </Layout>
  );
}

export function Me() {
  const nav = useNavigate();
  const logged = !!token.get();
  const [p, setP] = useState<Record<string, string>>({ name: "", skills: "", area: "" });
  const [note, setNote] = useState("");
  useEffect(() => {
    if (!logged) return;
    get<any>("/me/profile").then((d) => {
      const v = d?.data ?? d;
      if (v && typeof v === "object") setP({ name: String(v.name || ""), skills: String(v.skills || ""), area: String(v.area || "") });
    }).catch(() => {});
  }, [logged]);
  if (!logged) {
    return (
      <Layout guest><div className="card"><h2>You</h2>
        <p>Sign in to manage your profile, applications and earnings.</p>
        <Link className="btn primary" to="/auth?returnTo=%2Fme" style={{ width: "100%" }}>Sign in</Link>
        <Link className="btn secondary" to="/auth?returnTo=%2Fme" style={{ width: "100%", textAlign: "center" }}>Join free</Link>
        <p><Link to="/help">Help &amp; settings</Link> · <Link to="/">Continue browsing</Link></p>
      </div></Layout>
    );
  }
  const save = async () => { try { await post("/me/profile", p); localStorage.setItem("tugeza_name", p.name); setNote("Profile saved."); } catch (e) { setNote(e instanceof Error ? e.message : "failed"); } };
  const out = () => {
    token.clear(); localStorage.removeItem("tugeza_profile");
    Object.keys(localStorage).forEach((k) => { if (k.startsWith("tugeza_draft_private")) localStorage.removeItem(k); });
    nav("/");
  };
  return (
    <Layout><h2>Profile &amp; activity</h2>
      <label>Name <input value={p.name} onChange={(e) => setP({ ...p, name: e.target.value })} /></label>
      <label>Skills <input value={p.skills} onChange={(e) => setP({ ...p, skills: e.target.value })} placeholder="Add one skill to help people find you" /></label>
      <label>Area <input value={p.area} onChange={(e) => setP({ ...p, area: e.target.value })} /></label>
      <button className="btn primary" onClick={save}>Save profile</button>
      <p aria-live="polite">{note}</p>
      <p><Link className="btn2" to="/earnings">Earnings</Link> <Link className="btn2" to="/applications">Applications</Link> <Link className="btn2" to="/reports">Reports</Link> <Link className="btn2" to="/help">Help</Link> <Link className="btn2" to="/admin">Admin</Link></p>
      <p><button className="linklike" onClick={out}>Sign out</button></p>
    </Layout>
  );
}

export function ProfilePage() {
  const { id } = useParams();
  const [p, setP] = useState<any | null>(null);
  const [reviews, setReviews] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  useEffect(() => {
    (async () => {
      try {
        const d = await get<any>(`/profiles/${id}`);
        setP(d?.data ?? d);
        try { const r = await get<any>(`/profiles/${id}/reviews`); setReviews(Array.isArray(r) ? r : r.data || []); } catch { /* ignore */ }
        setError(null);
      } catch (e) { setError(e instanceof Error ? e.message : "failed"); } finally { setLoading(false); }
    })();
  }, [id]);
  return (
    <Layout guest><States loading={loading} error={error} empty={!loading && !error && !p} onRetry={() => location.reload()}>
      {p && <>
        <h2>{String(p.display_name || p.name || "Profile")}</h2>
        <p><span className="verified-tag">{p.verification ? String(p.verification) : "Unverified"}</span></p>
        <p className="muted">Roles: {Array.isArray(p.roles) ? p.roles.join(", ") : String(p.roles || "—")}</p>
        <div className="card"><h3>Skills</h3><p>{Array.isArray(p.skills) ? p.skills.join(", ") : String(p.skills || "None listed")}</p></div>
        <div className="card"><h3>Service areas</h3><p>{Array.isArray(p.service_areas) ? p.service_areas.join(", ") : String(p.service_areas || p.area || "—")}</p></div>
        <div className="card"><h3>Reviews</h3>{reviews.length === 0 ? <p className="muted">No public reviews yet.</p> : reviews.slice(0, 10).map((r: any, i: number) => <p key={String(r.id || i)}>{String(r.body || r.comment || "(review)")} {r.rating ? `· ${r.rating}/5` : ""}</p>)}</div>
      </>}
    </States></Layout>
  );
}

export function Earnings() {
  const [d, setD] = useState<{ expected?: unknown[]; earned?: unknown[]; reported?: unknown[]; received?: unknown[] } | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  useEffect(() => { get<any>("/me/earnings").then((r) => setD(r?.data ?? r)).catch((e) => setError(e instanceof Error ? e.message : "failed")).finally(() => setLoading(false)); }, []);
  const Row = ({ t, arr }: { t: string; arr?: unknown[] }) => (
    <section className="card"><h3>{t}</h3><p>{!arr?.length ? "None yet." : `${arr.length} record(s).`}</p>{arr?.slice(0, 5).map((c, i) => <p key={i} className="mono">{JSON.stringify(c).slice(0, 160)}</p>)}</section>
  );
  return (
    <Layout><h2>Earnings</h2>
      <States loading={loading} error={error} empty={!loading && !error && !d?.expected?.length && !d?.earned?.length} onRetry={() => location.reload()}>
        <><Row t="Expected (claim created, outcome recorded)" arr={d?.expected} /><Row t="Earned (attribution confirmed)" arr={d?.earned} /><Row t="Payment reported (seller says paid — not yet confirmed)" arr={d?.reported} /><Row t="Received (acknowledged)" arr={d?.received} /></>
      </States>
    </Layout>
  );
}

export function Reports() {
  const [f, setF] = useState({ target_type: "listing", target_id: "", reason: "" });
  const [note, setNote] = useState("");
  const send = async (dispute: boolean) => {
    try { await post(dispute ? "/disputes" : "/reports", dispute ? { referral_id: f.target_id, reason: f.reason } : f); setNote(dispute ? "Dispute opened. Status: pending." : "Report submitted."); }
    catch (e) { setNote(e instanceof Error ? e.message : "failed"); }
  };
  return (
    <Layout guest><h2>Reports &amp; disputes</h2>
      <label>Target type <input value={f.target_type} onChange={(e) => setF({ ...f, target_type: e.target.value })} /></label>
      <label>Target ID <input value={f.target_id} onChange={(e) => setF({ ...f, target_id: e.target.value })} /></label>
      <label>Reason <textarea value={f.reason} onChange={(e) => setF({ ...f, reason: e.target.value })} /></label>
      <button className="btn primary" onClick={() => send(false)}>Submit report</button>
      <button className="btn2" onClick={() => send(true)}>Open dispute</button>
      <p aria-live="polite">{note}</p>
    </Layout>
  );
}

export function Help() {
  useEffect(() => {
    const h = location.hash.replace("#", "");
    if (h) setTimeout(() => document.getElementById(h)?.scrollIntoView(), 50);
  }, []);
  return (
    <Layout guest><h2>Help</h2>
      <div className="card"><h3>Commission</h3><p>Commission = what the seller agrees to pay you for a successful introduction. It becomes earned when the agreed trigger happens.</p></div>
      <div className="card"><h3>Safety</h3><p>Phone confirmed means phone possession only. Never share ID documents or exact home address by default.</p></div>
      <div className="card"><h3>Disputes</h3><p>Outcome disputed? Payment is not confirmed until acknowledged.</p></div>
      <div className="card" id="terms"><h3>Terms</h3><p>Browsing Sure Sente is free. An account is needed to apply, message, quote, post, or refer. No wallet or escrow is offered — payments happen directly between parties. Commission rules: the rate and trigger stated on the listing apply; attribution must be confirmed before payout is expected. Contact support via Reports for help.</p></div>
      <div className="card" id="privacy"><h3>Privacy</h3><p>Public pages show only display names, approximate areas, and public reviews — never phone numbers or exact addresses. We store your phone for sign-in, your town preference, and safe drafts on your device. Contact support to correct or remove account data.</p></div>
    </Layout>
  );
}

export function Admin() {
  const [kind, setKind] = useState("reports");
  const [rows, setRows] = useState<{ id: string }[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const load = async () => {
    setLoading(true);
    try { const d = await get<any>(`/admin/${kind}`); setRows(Array.isArray(d) ? d : d.data || []); setError(null); }
    catch (e) { setError(e instanceof Error ? e.message : "failed (staff only)"); } finally { setLoading(false); }
  };
  useEffect(() => { load(); /* eslint-disable-next-line */ }, [kind]);
  return (
    <Layout><h2>Admin queues (staff)</h2>
      <label>Queue <select value={kind} onChange={(e) => setKind(e.target.value)}><option value="reports">Reports</option><option value="disputes">Disputes</option></select></label>
      <States loading={loading} error={error} empty={!loading && !error && rows.length === 0} onRetry={load}>
        <>{rows.map((r) => <div key={r.id} className="card"><p className="mono">{JSON.stringify(r).slice(0, 200)}</p><button className="btn2" onClick={() => post(`/admin/${kind}/${r.id}/decisions`, { status: "resolved", action: "resolve" }).then(load)}>Record decision</button></div>)}</>
      </States>
    </Layout>
  );
}
