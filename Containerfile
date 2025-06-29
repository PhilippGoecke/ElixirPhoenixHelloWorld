FROM debian:bookworm-slim as build-env

ARG DEBIAN_FRONTEND=noninteractive
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

RUN apt update && apt upgrade -y \
  # install tools
  && apt install -y --no-install-recommends unzip curl ca-certificates git \
  # install node.js/npm
  && apt install -y --no-install-recommends nodejs npm \
  # install phoenix dependencies
  && apt install -y --no-install-recommends inotify-tools \
  # install db
  && apt install -y --no-install-recommends sqlite3 build-essential \
  # install erlang runtime dependencies
  && apt install -y --no-install-recommends libodbc1 libssl3 libsctp1 \
  # install erlang build dependencies
  #&& apt install -y --no-install-recommends procps libncurses5 libncurses5-dev libwxgtk-gl3.2-1 libwxbase3.2-1 libsctp1 \
  && apt install -y --no-install-recommends autoconf dpkg-dev gcc g++ make libncurses-dev unixodbc-dev libssl-dev libsctp-dev \
  # install erlang
  && curl -fSL -o otp-src.tar.gz "https://github.com/erlang/otp/archive/OTP-26.2.5.11.tar.gz" \
  && echo "2eef7aac690a6cedfe0e6a20fc2d700db3490b4e4249683c0e5b812ad71304ed  otp-src.tar.gz" | sha256sum -c - \
  && export ERL_SRC="/usr/src/otp_src" \
  && mkdir -vp $ERL_SRC \
  && tar -xzf otp-src.tar.gz -C $ERL_SRC --strip-components=1 \
  && rm otp-src.tar.gz \
  && ( cd $ERL_SRC \
    && ./otp_build autoconf \
    && gnuArch="$(dpkg-architecture --query DEB_HOST_GNU_TYPE)" \
    && ./configure --build="$gnuArch" \
    && make -j$(nproc) \
    && make install ) \
  && find /usr/local -name examples | xargs rm -rf \
  && erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell \
  # install elixir
  && curl --location https://github.com/elixir-lang/elixir/releases/download/v1.17.3/elixir-otp-26.zip --output elixir.zip \
  && echo "a64260dcc39d21350ebcfa58c633b6535aba2be5ece9523f80d5b4bd7c725f30  elixir.zip" | sha256sum -c - \
  && unzip elixir.zip -d /usr/local \
  && rm elixir.zip \
  && elixir -v \
  # Elixir build tool
  && which mix \
  # install hex & rebar
  && mix local.hex --force \
  && mix local.rebar --force \
  # install phoenix 1.7.21
  && mix archive.install hex phx_new --force \
  && mix phx.new --version \
  # make image smaller
  && apt purge -y --auto-remove curl unzip \
  && rm -rf "/var/lib/apt/lists/*" \
  && rm -rf /var/cache/apt/archives

# https://hexdocs.pm/phoenix/up_and_running.html
RUN mix phx.new --version \
  && mix phx.new hello_app --module Greeting --app helloworld --database sqlite3 --no-dashboard \
  && cd hello_app \
  && export SECRET_KEY_BASE=$(mix phx.gen.secret) \
  && mix deps.get \
  && mix assets.setup \
  && mix deps.compile

WORKDIR /hello_app

RUN sed -i 's/localhost/0.0.0.0/g' config/config.exs \
  && sed -i 's/127, 0, 0, 1/0, 0, 0, 0/g' config/dev.exs

# https://devhints.io/phoenix
RUN mix phx.routes \
  && sed -i "s%get \"/\"%get \"/hello/:name\", HelloController, :world\n    #get \"\/\"%g" lib/helloworld_web/router.ex \
  && echo "defmodule GreetingWeb.HelloController do\n  use GreetingWeb, :controller\n\n  def world(conn, params) do\n    name = params[\"name\"]\n    render(conn, \"world.html\", name: name)\n  end\nend\n" > lib/helloworld_web/controllers/hello_controller.ex \
  && echo "defmodule GreetingWeb.HelloHTML do\n\n  use GreetingWeb, :html\n\n  embed_templates \"hello_html/*\"\nend" > lib/helloworld_web/controllers/hello_html.ex \
  && mkdir -p lib/helloworld_web/controllers/hello_html \
  && echo "<h1>Hello <%= @name %>!</h1>" > lib/helloworld_web/controllers/hello_html/world.html.heex \
  && sed -zi 's/<header.*<\/header>//' lib/helloworld_web/components/layouts/app.html.heex \
  && cat lib/helloworld_web/components/layouts/app.html.heex \
  && mix ecto.migrate \
  && mix phx.routes \
  && mix phx.digest

EXPOSE 4000

CMD MIX_ENV=prod DATABASE_PATH=/my_app_prod.db SECRET_KEY_BASE=`mix phx.gen.secret` mix phx.server

HEALTHCHECK CMD curl -f "http://localhost:4000/" || exit 1
