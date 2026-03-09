FROM ruby:3.3-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    postgresql-client \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Ruby dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle install --without development test

# Install JS dependencies
COPY package.json package-lock.json ./
RUN npm ci

# Copy application code
COPY . .

# Build frontend via Vite Ruby
RUN bundle exec vite build

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
