# Phoenix Hello World 🚀

[![Elixir](https://img.shields.io/badge/Elixir-%E2%9C%A8-purple)](https://elixir-lang.org)
[![Phoenix](https://img.shields.io/badge/Phoenix-Framework-FD4F00)](https://www.phoenixframework.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![CI](https://img.shields.io/badge/CI-GitHub%20Actions-grey)](#)
[![LiveView Ready](https://img.shields.io/badge/LiveView-Yes-brightgreen)](https://hexdocs.pm/phoenix_live_view)

A minimal Phoenix starter to verify your Elixir setup and quickly spin up a web server.

## ✨ Features
- Fast development server with code reloading
- LiveDashboard (optional) for metrics
- First endpoint returning a friendly message
- Ready for Docker (sample snippet below)
- IEx friendly for interactive debugging

## 📦 Prerequisites
- Erlang/OTP (recommended: latest stable)  
- Elixir (matching your Erlang)  
- Phoenix archive (mix archive.install hex phx_new)  
- Node.js (if using asset pipeline)  
- PostgreSQL (if you generated with Ecto)

Install Elixir & Erlang: https://elixir-lang.org/install.html  
Docker Erlang images: https://github.com/erlang/docker-erlang-otp/tree/master  
Phoenix Up & Running Guide: https://hexdocs.pm/phoenix/up_and_running.html

## 🚀 Quick Start
```bash
# Create (if not already)
mix phx.new hello_world --no-html --no-assets
cd hello_world

# Install deps
mix deps.get

# (If Ecto) create & migrate
mix ecto.create && mix ecto.migrate

# Run dev server
mix phx.server
# or with IEx
iex -S mix phx.server
```
Visit: http://localhost:4000

## 🗂 Project Structure (core)
```
lib/
    hello_world/        # Domain (contexts)
    hello_world_web/    # Web layer (controllers, views, components, router)
config/               # Runtime & compile-time config
priv/                 # Static assets, migrations, seeds
```

## 🧪 Running Tests
```bash
mix test
mix test.watch   # if you added mix test.watch dep
```

## 🛠 Helpful Mix Tasks
```bash
mix phx.routes
mix ecto.migrate
mix format
mix deps.unlock --check-unused
```

## 🐚 IEx Tips
```elixir
recompile()        # Recompile changed modules
h SomeModule       # Docs
i some_value       # Introspection
```

## 🐳 Docker (example)
Dockerfile:
```dockerfile
FROM elixir:1.17-alpine AS build
RUN apk add --no-cache build-base git
WORKDIR /app
RUN mix local.hex --force && mix local.rebar --force
COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only prod
COPY lib lib
COPY priv priv
RUN MIX_ENV=prod mix compile
RUN MIX_ENV=prod mix phx.digest

FROM alpine:3.19
RUN apk add --no-cache openssl ncurses-libs
WORKDIR /app
COPY --from=build /app/_build/prod/rel/ ./
ENV PHX_SERVER=true
CMD ["bin/hello_world", "start"]
```

## 🔐 Environment (sample)
```bash
export SECRET_KEY_BASE=$(mix phx.gen.secret)
export PHX_HOST=localhost
export PORT=4000
```

## 📊 LiveDashboard (dev only)
Add to router (dev.exs scope):
```elixir
import Phoenix.LiveDashboard.Router
live_dashboard "/dashboard", metrics: HelloWorldWeb.Telemetry
```

## 📚 Further Resources
- Phoenix Guides: https://hexdocs.pm/phoenix
- LiveView: https://hexdocs.pm/phoenix_live_view
- Elixir School: https://elixirschool.com

## 🤝 Contributing
1. Fork
2. Create feature branch
3. mix format && mix test
4. PR

## 📝 License
MIT (add LICENSE file if missing)

Happy hacking! 💜
