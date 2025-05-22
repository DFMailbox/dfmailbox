FROM erlang:27.1.1.0-alpine AS base
COPY --from=ghcr.io/gleam-lang/gleam:v1.9.0-erlang-alpine /bin/gleam /bin/gleam
COPY gleam.toml manifest.toml /app/
WORKDIR /app
RUN mkdir -p src && gleam build

COPY ./test/ test
COPY ./src/ src

FROM base AS dev
CMD ["gleam", "run"]

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

