unless (Rails.env.test? || Rails.env.assets? || Rails.env.development?)
  max_fixnum = (2**(0.size * 8 -2) -1)

  register_thread = Thread.new do
    NATS.start(:uri => Settings.message_bus_servers, :max_reconnect_attempts => max_fixnum) do
      registrar.register_with_router
    end
  end

  Kernel.at_exit do
    register_thread.kill
    register_thread.join

    NATS.start(:uri => Settings.message_bus_servers) do
      registrar.shutdown { EM.stop }
    end
  end

  def registrar
    Cf::Registrar.new(
      :message_bus_servers => Settings.message_bus_servers,
      :host                => Settings.external_ip,
      :port                => Settings.external_port,
      :uri                 => Settings.external_host,
      :tags                => { 'component' => Settings.component_name },
    )
  end
end
