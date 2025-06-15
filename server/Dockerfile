ARG TESTING

FROM elixir:1.18.4-otp-27-alpine AS base
RUN apk --no-cache add curl
RUN mix local.hex --force
COPY --from=ghcr.io/gleam-lang/gleam:v1.9.0-erlang-alpine /bin/gleam /bin/gleam
COPY gleam.toml manifest.toml /app/

WORKDIR /app
RUN mkdir -p src && gleam build

COPY ./test/ test
COPY ./src/ src


# Dev
FROM base AS dev-true
# Testing is true
COPY ./testing.gleam src/compile_time.gleam

FROM base AS dev-false

FROM dev-${TESTING} AS dev
ENTRYPOINT ["gleam"]
CMD ["run"]

# Prod
FROM base AS build
RUN gleam export erlang-shipment

FROM erlang:27.1.1.0-alpine AS prod
RUN \
  addgroup --system webapp && \
  adduser --system webapp -g webapp
COPY --from=build /app/build/erlang-shipment /app
WORKDIR /app
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run"]
