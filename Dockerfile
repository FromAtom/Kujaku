FROM ruby:2.5.1-alpine

ENV LANG C.UTF-8
ENV RACK_ENV production
ENV PORT 9292

WORKDIR /app
EXPOSE $PORT

RUN gem update bundler
COPY Gemfile* ./
RUN bundle install --jobs=4
COPY . .

CMD bundle exec rackup config.ru -p $PORT
