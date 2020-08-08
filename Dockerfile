FROM ruby:2.5-buster

COPY . /app

RUN apt-get update \
  && apt-get install git mecab libmecab-dev mecab-ipadic-utf8 make curl xz-utils file sudo --no-install-recommends -y \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && cd /opt \
  && git clone --depth 1 https://github.com/neologd/mecab-ipadic-neologd.git \
  && cd /opt/mecab-ipadic-neologd \
  && ./bin/install-mecab-ipadic-neologd -n -y \
  && rm -rf /opt/mecab-ipadic-neologd \
  && echo "dicdir = /usr/lib/x86_64-linux-gnu/mecab/dic/mecab-ipadic-neologd/" > /etc/mecabrc \
# install app
  && cd /app \
  && bundle install \
  && apt-get purge git make curl xz-utils file -y \
  && apt-get autoremove -y

WORKDIR /app
ENV RUBYOPT -EUTF-8
CMD bundle exec ruby main.rb
