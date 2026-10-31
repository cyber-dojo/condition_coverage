FROM ruby:4.0.5-alpine3.24@sha256:f48938e9ae72a4d32e728b03c306e7a7ff21f0cb6c2ed33f44a078c700b2aea6

RUN gem install --no-document rake minitest minitest-reporters simplecov rubocop

# The repo is bind-mounted here, so source edits need no rebuild.
WORKDIR /gem
