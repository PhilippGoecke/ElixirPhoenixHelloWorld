FROM debian:trixie-slim as phoenix_base

ARG DEBIAN_FRONTEND=noninteractive
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

RUN apt update && apt upgrade -y \
  # install tools
  && apt install -y --no-install-recommends unzip curl ca-certificates git \
  # install erlang runtime dependencies
  && apt install -y --no-install-recommends libodbc2 libssl3 libsctp1 \
  # install erlang build dependencies
  && apt install -y --no-install-recommends autoconf dpkg-dev gcc g++ make libncurses-dev unixodbc-dev libssl-dev libsctp-dev \
  # install erlang
  && curl -fSL -o otp-src.tar.gz "https://github.com/erlang/otp/releases/download/OTP-29.0.3/otp_src_29.0.3.tar.gz" \
  && echo "f920c660b16794bcb7270d1cbf680f7747c719650bcd6ac449508a32c2a8972a otp-src.tar.gz" | sha256sum --strict --check - \
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
  && curl --output elixir.zip --location https://github.com/elixir-lang/elixir/releases/download/v1.20.2/elixir-otp-29.zip \
  && echo "a9e88cd41fbbba7da6f6dc237a49dd2ed4e70457121035cc7fc56ad05582f394 elixir.zip" | sha256sum --strict --check - \
  && unzip elixir.zip -d /usr/local \
  && rm elixir.zip \
  && elixir -v \
  # Elixir build tool
  && which mix \
  # install hex & rebar
  && mix local.hex --force \
  && mix local.rebar --force \
  && mix hex.info \
  # make image smaller
  && apt purge -y --auto-remove curl unzip \
  && rm -rf "/var/lib/apt/lists/*" \
  && rm -rf /var/cache/apt/archives

FROM debian:trixie-slim as phoenix_runtime

ARG DEBIAN_FRONTEND=noninteractive
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

RUN apt update && apt upgrade -y \
  # install tools
  && apt install -y --no-install-recommends git \
  # install node.js/npm
  && apt install -y --no-install-recommends nodejs npm \
  # install phoenix dependencies
  && apt install -y --no-install-recommends inotify-tools \
  # install db
  && apt install -y --no-install-recommends sqlite3 \
  # install erlang runtime dependencies
  && apt install -y --no-install-recommends libodbc2 libssl3 libsctp1 \
  # install healthcheck dependencies
  && apt install -y --no-install-recommends curl \
  # make image smaller
  && rm -rf "/var/lib/apt/lists/*" \
  && rm -rf /var/cache/apt/archives

COPY --from=phoenix_base /usr/local /usr/local

# add user and set home directory
ARG USER=phoenix
RUN useradd --create-home --shell /bin/bash $USER
ARG HOME="/home/$USER"
WORKDIR /phoenix
USER $USER

RUN erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell \
  && elixir -v \
  && which mix

# install phoenix 1.8.9
RUN mix archive.install hex phx_new --force 1.8.9 \
  && mix phx.new --version

# https://hexdocs.pm/phoenix/up_and_running.html
RUN mix phx.new --version \
  && mix phx.new hello_app --module Greeting --app helloworld --database sqlite3 --no-dashboard \
  && cd hello_app \
  && export SECRET_KEY_BASE=$(mix phx.gen.secret) \
  && mix deps.get \
  && mix assets.setup \
  && mix deps.compile

WORKDIR /phoenix/hello_app

RUN sed -i 's/localhost/0.0.0.0/g' config/config.exs \
  && sed -i 's/127, 0, 0, 1/0, 0, 0, 0/g' config/dev.exs \
  # disable forcing HTTPS redirects in production
  && { perl -0pi -e 's/force_ssl:\s*(\[(?:[^\[\]]++|(?1))*+\])/force_ssl: false/gs' config/prod.exs || true; } \
  && { sed -i 's/force_ssl:.*/force_ssl: false/' config/runtime.exs || true; }

# https://devhints.io/phoenix
RUN mix phx.routes \
  && sed -i "s%get \"/\"%get \"/\", HelloController, :world, assigns: \%{name: \"World\"}\n    get \"/hello/\", HelloController, :world, assigns: \%{name: \"World\"}\n    get \"/hello/:name\", HelloController, :world\n    #get \"\/\"%g" lib/helloworld_web/router.ex \
  && echo "defmodule GreetingWeb.HelloController do\n use GreetingWeb, :controller\n\n def world(conn, params) do\n name = params[\"name\"] || conn.assigns[:name]\n render(conn, \"world.html\", name: name)\n end\nend\n" > lib/helloworld_web/controllers/hello_controller.ex \
  && echo "defmodule GreetingWeb.HelloHTML do\n\n use GreetingWeb, :html\n\n embed_templates \"hello_html/*\"\nend" > lib/helloworld_web/controllers/hello_html.ex \
  && mkdir -p lib/helloworld_web/controllers/hello_html \
  && echo "<h1>Hello <%= @name %>!</h1>\n <!-- Phoenix <%= Application.spec(:phoenix, :vsn) %>, Elixir <%= System.version() %>, Erlang/OTP <%= :erlang.system_info(:otp_release) %> (<%= File.read!(Path.join([:code.root_dir(), \"releases\", :erlang.system_info(:otp_release), \"OTP_VERSION\"])) |> String.trim() %>) -->" > lib/helloworld_web/controllers/hello_html/world.html.heex \
  && sed -i 's/ suffix=" · Phoenix Framework"//' lib/helloworld_web/components/layouts/root.html.heex \
  && mix ecto.migrate \
  && mix phx.routes \
  && mix phx.digest

EXPOSE 4000

CMD MIX_ENV=prod PHX_HOST=localhost DATABASE_PATH=/phoenix/my_app_prod.db SECRET_KEY_BASE=`mix phx.gen.secret` mix phx.server

HEALTHCHECK CMD curl -f "http://localhost:4000/" || exit 1
