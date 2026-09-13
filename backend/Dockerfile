FROM ruby:3.3.5-slim-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential libpq-dev postgresql-client ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile ./
RUN bundle install -j4

COPY . .

RUN chmod +x bin/* && mkdir -p tmp/pids tmp/sockets log storage

EXPOSE 3000

ENTRYPOINT ["./bin/docker-entrypoint"]
CMD ["./bin/start-web"]
