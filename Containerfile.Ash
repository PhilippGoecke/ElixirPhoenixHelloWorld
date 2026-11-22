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
  && curl -fSL -o otp-src.tar.gz "https://github.com/erlang/otp/releases/download/OTP-29.1.2/otp_src_29.1.2.tar.gz" \
  && echo "c79966661e35fe4aff8ec003db63682e3b33b10b672220d51bf93c0a9244b049 otp-src.tar.gz" | sha256sum --strict --check - \
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
  && curl --output elixir.zip --location https://github.com/elixir-lang/elixir/releases/download/v1.20.5/elixir-otp-29.zip \
  && echo "f424d6f0bb710a1d4898f2645d8ad6cab3f5eab8d71848c0dda2579d3a8e8a06 elixir.zip" | sha256sum --strict --check - \
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

# install phoenix 1.8.17
RUN mix archive.install hex phx_new --force 1.8.17 \
  && mix phx.new --version

# https://hexdocs.pm/phoenix/up_and_running.html
RUN mix phx.new --version \
  && mix phx.new hello_app --module Greeting --app helloworld --database sqlite3 --no-dashboard \
  && cd hello_app \
  && sed -i 's/{:phoenix,/{:ash, "~> 3.0"},\n      {:phoenix,/' mix.exs \
  && mkdir -p lib/helloworld/greetings \
  && printf '%s\n' 'defmodule Greeting.Greetings do' '  use Ash.Domain' '' '  resources do' '    resource Greeting.Greetings.Hello' '  end' 'end' > lib/helloworld/greetings.ex \
  && printf '%s\n' 'defmodule Greeting.Greetings.Hello do' '  use Ash.Resource, domain: Greeting.Greetings' '' '  actions do' '    action :greet, :string do' '      argument :name, :string, allow_nil?: false' '      run fn input, _context -> {:ok, "Hello #{input.arguments.name}!"} end' '    end' '  end' 'end' > lib/helloworld/greetings/hello.ex \
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
  && echo "defmodule GreetingWeb.HelloController do\n use GreetingWeb, :controller\n\n def world(conn, params) do\n name = params[\"name\"] || conn.assigns[:name]\n greeting = Greeting.Greetings.Hello |> Ash.ActionInput.for_action(:greet, %{name: name}) |> Ash.run_action!()\n render(conn, \"world.html\", greeting: greeting)\n end\nend\n" > lib/helloworld_web/controllers/hello_controller.ex \
  && echo "defmodule GreetingWeb.HelloHTML do\n\n use GreetingWeb, :html\n\n embed_templates \"hello_html/*\"\nend" > lib/helloworld_web/controllers/hello_html.ex \
  && mkdir -p lib/helloworld_web/controllers/hello_html \
  && echo "<h1><%= @greeting %></h1>\n <!-- Phoenix <%= Application.spec(:phoenix, :vsn) %>, Elixir <%= System.version() %>, Erlang/OTP <%= :erlang.system_info(:otp_release) %> (<%= File.read!(Path.join([:code.root_dir(), \"releases\", :erlang.system_info(:otp_release), \"OTP_VERSION\"])) |> String.trim() %>) -->" > lib/helloworld_web/controllers/hello_html/world.html.heex \
  && sed -i 's/ suffix=" · Phoenix Framework"//' lib/helloworld_web/components/layouts/root.html.heex \
  && sed -i '/<header/,/<\/header>/d' lib/helloworld_web/components/layouts.ex \
  && mix ecto.migrate \
  && mix phx.routes \
  && mix phx.digest

EXPOSE 4000

CMD MIX_ENV=prod PHX_HOST=localhost DATABASE_PATH=/phoenix/my_app_prod.db SECRET_KEY_BASE=`mix phx.gen.secret` mix phx.server

HEALTHCHECK CMD curl -f "http://localhost:4000/" || exit 1
