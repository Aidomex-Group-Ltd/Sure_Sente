# ---- builder ----
FROM hexpm/elixir:1.17.3-erlang-27.1-alpine-3.20.3 AS builder
RUN apk add --no-cache build-base git
WORKDIR /app
ENV MIX_ENV=prod
COPY mix.exs mix.lock ./
COPY config config
RUN mix local.hex --force && mix local.rebar --force && mix deps.get --only prod && mix deps.compile
COPY priv priv
COPY lib lib
RUN mix compile && mix release

# ---- runtime ----
FROM alpine:3.20.3 AS runtime
RUN apk add --no-cache libstdc++ openssl ncurses-libs libgcc wget && adduser -D -h /app appuser
WORKDIR /app
USER appuser
COPY --from=builder --chown=appuser /app/_build/prod/rel/backend ./
ENV PHX_SERVER=true MIX_ENV=prod
EXPOSE 4000
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s CMD sh -c 'wget -qO- http://127.0.0.1:${PORT:-4000}/health || exit 1'
CMD ["bin/backend", "start"]
