# Use the official Elixir image
FROM hexpm/elixir:1.15.7-erlang-26.1.2-debian-bullseye-20231009-slim

# Install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git curl nodejs npm \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set environment variables
ENV MIX_ENV=prod
ENV PORT=4000
ENV PHX_HOST=localhost

# Create app directory
WORKDIR /app

# Copy mix files
COPY mix.exs mix.lock ./
RUN mix local.hex --force && \
    mix local.rebar --force

# Install mix dependencies
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix do deps.get, deps.compile

# Copy assets
COPY assets/package.json assets/package-lock.json ./assets/
RUN npm --prefix ./assets ci --progress=false --no-audit --loglevel=error

# Copy source code
COPY priv priv
COPY assets assets
COPY lib lib

# Compile assets
RUN npm run --prefix ./assets deploy
RUN mix phx.digest

# Compile the release
RUN mix compile

# Copy runtime configuration
COPY config/runtime.exs config/

# Build the release
RUN mix release

# Start fresh image for runtime
FROM debian:bullseye-slim

RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses5 locales \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# Copy the release from build stage
COPY --from=0 --chown=nobody:root /app/_build/prod/rel/YOUR_APP_NAME ./

USER nobody

EXPOSE 4000

# Start the Phoenix app
CMD ["bin/mention_score", "start"]