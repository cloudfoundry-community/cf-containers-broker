require Rails.root.join('app/models/catalog')

unless Rails.env.assets?
  OmniAuth.config.logger = Rails.logger
  OmniAuth.config.failure_raise_out_environments = []
  OmniAuth.config.path_prefix = '/manage/auth'

  DASHBOARD_CLIENT_PROC = lambda do |env|
    request = Rack::Request.new(env)
    service = Catalog.find_service_by_guid(request.session[:service_guid])
    env['omniauth.strategy'].options[:client_id] = service.dashboard_client['id']
    env['omniauth.strategy'].options[:client_secret] = service.dashboard_client['secret']
    env['omniauth.strategy'].options[:auth_server_url] = Configuration.auth_server_url
    env['omniauth.strategy'].options[:token_server_url] = Configuration.token_server_url
    env['omniauth.strategy'].options[:scope] = %w(cloud_controller_service_permissions.read openid)
  end

  Rails.application.config.middleware.use OmniAuth::Builder do
    unless (Rails.env.test? || Rails.env.development?)
      provider :cloudfoundry, :setup => DASHBOARD_CLIENT_PROC
    end
  end
end
