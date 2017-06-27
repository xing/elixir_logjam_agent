FROM docker.dc.xing.com/base/elixirbase:1.3.2-otp18.3-ubuntu-trusty

COPY mix* /app/

WORKDIR /app

RUN mix deps.get
RUN MIX_ENV=test mix deps.compile

COPY . /app/