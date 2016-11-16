FROM docker.dc.xing.com/xingbox/xing-base-elixir:latest

COPY mix* /app/

WORKDIR /app

RUN mix deps.get
RUN MIX_ENV=test mix deps.compile

COPY . /app/