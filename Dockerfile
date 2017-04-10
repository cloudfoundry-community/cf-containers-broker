FROM ruby:2.3.3
LABEL maintainers Ferran Rodenas <frodenas@gmail.com>, Dr Nic Williams <drnicwilliams@gmail.com>

# Add application code
ADD . /app

# Prepare application (cache gems & precompile assets)
RUN cd /app && \
    bundle package --all && \
    RAILS_ENV=assets bundle exec rake assets:precompile && \
    rm -rf spec && \
    mkdir /config

# Add default configuration files
ADD ./config/unicorn.conf.rb /config/unicorn.conf.rb
ADD ./config/settings.yml /config/settings.yml

# Working directory
WORKDIR /app

# Define Rails environment
ENV RAILS_ENV production

# Define Settings file path
ENV SETTINGS_PATH /config/settings.yml

# Define Docker Remote API
ENV DOCKER_URL unix:///var/run/docker.sock

# Command to run
ENTRYPOINT ["/app/bin/run.sh"]
CMD ["bundle", "exec", "unicorn", "-c", "/config/unicorn.conf.rb"]

# Expose listen port
EXPOSE 80

# Expose the configuration and logs directories
VOLUME ["/config", "/app/log", "/envdir"]
