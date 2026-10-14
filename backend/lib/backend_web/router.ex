defmodule BackendWeb.Router do
  use BackendWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug BackendWeb.Plugs.CORS
    plug BackendWeb.Plugs.RateLimiter
    plug BackendWeb.Plugs.Auth
    plug BackendWeb.Plugs.SecurityAuditor
  end

  pipeline :authed do
    plug BackendWeb.Plugs.RequireUser
  end

  pipeline :staff do
    plug BackendWeb.Plugs.RequireStaff
  end

  pipeline :web do
    plug :accepts, ["html"]
    plug BackendWeb.Plugs.SecurityHeaders
  end

  scope "/", BackendWeb do
    pipe_through :web
    get "/", PageController, :home
  end

  scope "/api/v1", BackendWeb do
    pipe_through :api
    post "/auth/request-code", ApiController, :request_code
    post "/auth/verify-code", ApiController, :verify_code
    get "/categories", ApiController, :categories
    get "/listings", ApiController, :listings_index
    get "/listings/:id", ApiController, :listing_show
    get "/listings/:id/reviews", ApiController, :reviews_for_listing
    get "/profiles/:id", ApiController, :profile_public
    get "/profiles/:id/reviews", ApiController, :reviews_for_profile
  end

  scope "/api/v1", BackendWeb do
    pipe_through [:api, :authed]
    get "/me", ApiController, :me
    get "/me/profile", ApiController, :profile_get
    put "/me/profile", ApiController, :profile_put
    get "/categories/all", ApiController, :categories_all
    post "/listings", ApiController, :listing_create
    patch "/listings/:id", ApiController, :listing_update
    post "/listings/:id/publish", ApiController, :listing_publish
    post "/listings/:id/draft", ApiController, :listing_draft
    post "/listings/:listing_id/applications", ApiController, :apply
    get "/applications", ApiController, :applications_index
    post "/applications/:application_id/offers", ApiController, :offer
    post "/offers/:offer_id/accept", ApiController, :offer_accept
    post "/listings/:listing_id/quotes", ApiController, :quote_create
    post "/bookings/:booking_id/events", ApiController, :booking_event
    get "/bookings/:id", ApiController, :booking_show
    post "/listings/:listing_id/broker-requests", ApiController, :broker_request
    post "/broker-requests/:id/approve", ApiController, :broker_approve
    post "/agreements/:id/accept", ApiController, :agreement_accept
    post "/agreements/:agreement_id/referrals", ApiController, :referral_create
    post "/referrals/:id/attribution", ApiController, :referral_attr
    get "/referrals/:id", ApiController, :referral_show
    post "/referrals/:id/outcome", ApiController, :referral_outcome
    post "/claims/:id/payment-report", ApiController, :claim_report
    post "/claims/:id/acknowledge", ApiController, :claim_ack
    get "/me/earnings", ApiController, :earnings
    post "/conversations", ApiController, :conv_create
    get "/conversations", ApiController, :conversations_index
    post "/conversations/:id/messages", ApiController, :msg_create
    get "/conversations/:id/messages", ApiController, :msg_list
    post "/reports", ApiController, :report_create
    post "/reviews", ApiController, :review_create
    post "/disputes", ApiController, :dispute_create
    post "/uploads", ApiController, :upload
    post "/me/erasure-request", ApiController, :erasure_request
  end

  scope "/api/v1/admin", BackendWeb do
    pipe_through [:api, :authed, :staff]
    get "/:kind", ApiController, :admin_list
    post "/:kind/:id/decisions", ApiController, :admin_decide
  end
end
