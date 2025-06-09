FROM debian:bookworm-slim as build-env

ARG DEBIAN_FRONTEND=noninteractive
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

RUN apt update && apt upgrade -y \
  # install tools
  && apt install -y --no-install-recommends unzip curl \
  # install node.js/npm
  && apt install -y --no-install-recommends nodejs npm \
  # install phoenix dependencies
  && apt install -y --no-install-recommends inotify-tools \
  # install db
  && apt install -y --no-install-recommends sqlite3 build-essential \
  # install erlang
  && apt install -y --no-install-recommends procps libncurses5 libncurses5-dev libwxgtk3.0-gtk3-0v5 libwxbase3.0-dev libsctp1 \
  && curl https://packages.erlang-solutions.com/erlang/debian/pool/esl-erlang_25.3-1~debian~bookworm_amd64.deb --output erlang.deb \
  && echo "e3d6766515900b53130aaec1ebaedbe1b5344745aae5bcf9854e3d58699912a224e7f8c4b2071350454949e687456056e5d7f6e7430dba07358c56848c69148d  erlang.deb" > erlang.deb.sha512 \
  && sha512sum -c erlang.deb.sha512 \
  && dpkg -i erlang.deb \
  && apt update && apt install -y erlang \
  && erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell \
  # install elixir
  && curl --location https://github.com/elixir-lang/elixir/releases/download/v1.14.4/elixir-otp-23.zip --output elixir.zip \
  && echo "c626c08b42e29a29aa91fcc744c6f5da9d3c1cb4a7f50fdee1e290217bd03d038fd9fd5e42bf223f48eb2042d5b264384648b84791d07f956979814f6ed02b07  elixir.zip" > elixir.zip.sha512 \
  && sha512sum -c elixir.zip.sha512 \
  && unzip elixir.zip -d /usr/local \
  && rm elixir.zip \
  && elixir -v \
  && which mix \
  # install hex & rebar
  && mix local.hex --force \
  && mix local.rebar --force \
  # install phoenix 1.7.2
  && mix archive.install hex phx_new --force \
  && mix phx.new --version \
  # make image smaller
  && apt purge -y --auto-remove curl unzip \
  && rm -rf "/var/lib/apt/lists/*" \
  && rm -rf /var/cache/apt/archives

# https://hexdocs.pm/phoenix/up_and_running.html
RUN mix phx.new hello_app --database sqlite3 \
  && cd hello_app \
  && mix deps.get

WORKDIR /hello_app

RUN sed -i 's/localhost/0.0.0.0/g' config/config.exs
RUN sed -i 's/127, 0, 0, 1/0, 0, 0, 0/g' config/dev.exs

# https://devhints.io/phoenix
RUN mix phx.routes \
  && mix phx.gen.html Blog Post posts title:string content:text \
  && mix ecto.migrate \
  && mix phx.routes

EXPOSE 4000

#CMD MIX_ENV=dev mix phx.server
CMD MIX_ENV=prod DATABASE_PATH=/my_app_prod.db SECRET_KEY_BASE=`mix phx.gen.secret` mix phx.server

HEALTHCHECK CMD curl -f "http://localhost:4000/" || exit 1
