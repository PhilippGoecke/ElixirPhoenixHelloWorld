FROM debian:bookworm-slim as build-env

ARG DEBIAN_FRONTEND=noninteractive
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

RUN apt update && apt upgrade -y \
  # install tools
  && apt install -y --no-install-recommends unzip curl git \
  # install node.js/npm
  && apt install -y --no-install-recommends nodejs npm \
  # install phoenix dependencies
  && apt install -y --no-install-recommends inotify-tools \
  # install db
  && apt install -y --no-install-recommends sqlite3 build-essential \
  # install erlang
  #&& apt install -y --no-install-recommends procps libncurses5 libncurses5-dev libwxgtk-gl3.2-1 libwxbase3.2-1 libsctp1 \
  && apt update && apt install -y erlang \
  && erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell \
  # install elixir
  && curl --location https://github.com/elixir-lang/elixir/releases/download/v1.19-latest/elixir-otp-28.zip --output elixir.zip \
  && echo "e13d11a2a782f25f17fea55d7f780f6d356c7a40b4df0168e110a6c66d6b2e790f2ac7e9a9bff34decd4ee3d2ebfc114d6e01cb5cf0c42acf3df5ea48d9ff70a  elixir.zip" > elixir.zip.sha512 \
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
# mix phx.new "$app_name" $db_option $app_args --install --from-elixir-install
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

CMD MIX_ENV=prod DATABASE_PATH=/my_app_prod.db SECRET_KEY_BASE=`mix phx.gen.secret` mix phx.server

HEALTHCHECK CMD curl -f "http://localhost:4000/" || exit 1
