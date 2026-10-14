import { BrowserRouter, Routes, Route, Navigate, useParams } from "react-router-dom";
import { Home, Find, SimpleList, Detail, PostWizard, Applications, Broker } from "./screens/main";
import { Auth, Messages, Conversation, Me, Earnings, Reports, Help, Admin, ProfilePage, BookingDetail, ReferralDetail } from "./screens/rest";
import { token } from "./lib/api";
import type { JSX } from "react";

const Req = ({ el, ret }: { el: JSX.Element; ret: string }) => {
  if (token.get()) return el;
  return <Navigate to={`/auth?returnTo=${encodeURIComponent(ret)}`} replace />;
};
function Ret({ el }: { el: JSX.Element }) {
  const p = useParams()["*"] || "";
  return <Req el={el} ret={"/" + p} />;
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/find" element={<Find />} />
        <Route path="/services" element={<SimpleList title="Services" kind="service" />} />
        <Route path="/deals" element={<SimpleList title="Deals" kind="goods" />} />
        <Route path="/listings/:id" element={<Detail />} />
        <Route path="/profiles/:id" element={<ProfilePage />} />
        <Route path="/post" element={<PostWizard />} />
        <Route path="/messages" element={<Messages />} />
        <Route path="/messages/:id" element={<Req el={<Conversation />} ret="/messages" />} />
        <Route path="/applications" element={<Req el={<Applications />} ret="/applications" />} />
        <Route path="/bookings/:id" element={<Req el={<BookingDetail />} ret="/applications" />} />
        <Route path="/broker" element={<Req el={<Broker />} ret="/broker" />} />
        <Route path="/referrals/:id" element={<Req el={<ReferralDetail />} ret="/broker" />} />
        <Route path="/me" element={<Me />} />
        <Route path="/earnings" element={<Req el={<Earnings />} ret="/earnings" />} />
        <Route path="/reports" element={<Reports />} />
        <Route path="/help" element={<Help />} />
        <Route path="/admin" element={<Req el={<Admin />} ret="/admin" />} />
        <Route path="/auth" element={<Auth />} />
        <Route path="*" element={<Ret el={<Home />} />} />
      </Routes>
    </BrowserRouter>
  );
}
