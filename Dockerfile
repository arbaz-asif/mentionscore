# ---- Build stage ----
FROM hexpm/elixir:1.18.1-erlang-27.0.1-alpine-3.21.0 AS build

# Install build tools
RUN apk add --no-cache build-base git npm nodejs

# Set build ENV
ENV MIX_ENV=prod

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && mix local.rebar --force

# Copy deps and fetch them
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# Copy rest of the app
COPY . .

# Compile and build assets
RUN mix deps.compile
RUN npm --prefix assets install --legacy-peer-deps
RUN npm run --prefix assets build
RUN mix assets.deploy
RUN mix release

# ---- Runtime stage ----
FROM alpine:3.19 AS app

RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR /app

COPY --from=build /app/_build/prod/rel/mention_score ./

ENV HOME=/app
ENV MIX_ENV=prod
ENV SHELL=/bin/sh

CMD ["/app/bin/mention_score", "start"]
