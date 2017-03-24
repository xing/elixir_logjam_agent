FROM docker.dc.xing.com/xingbox/xing-base-elixir:1.3.2-otp18.3

COPY mix* /app/

WORKDIR /app

RUN mix deps.get
RUN MIX_ENV=test mix deps.compile

COPY . /app/