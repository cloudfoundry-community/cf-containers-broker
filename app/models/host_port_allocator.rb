# HostPortAllocator allows a server to allocate ports for containers
# It uses a local /var/vcap/store/cf-containers-broker/host_port_counter
# file to store the last port allocated. It uses lsof to confirm that a port
# to be allocated is not currently being used.
class HostPortAllocator
  attr_reader :counter_path

  class LockTimeout < StandardError; end
  class NoAvailablePort < StandardError; end

  def initialize(base_dir, counter_start, counter_end)
    @base_dir = base_dir
    @counter_path = File.join(@base_dir, 'host_port_counter')
    @counter_start, @counter_end = counter_start, counter_end
  end

  def allocate_next_port
    port = nil
    File.open(counter_path, File::RDWR|File::CREAT, 0644) do |f|
      # TODO perhaps assume that if lock isn't released then recreate and restart counter
      Timeout::timeout(timeout_seconds, LockTimeout) { f.flock(File::LOCK_EX) }
      Timeout::timeout(timeout_seconds, NoAvailablePort) do
        previous_port = f.read.to_i
        port = next_available_port(previous_port)
        until port_available?(port)
          port = next_available_port(port)
        end
      end
      f.rewind
      f.write("#{port}\n")
      f.flush
      f.truncate(f.pos)
      f.flock(File::LOCK_UN)
    end
    port
  end

  def timeout_seconds
    2
  end

  private
  def next_available_port(previous_port)
    if previous_port < @counter_start
      port = @counter_start
    else
      port = previous_port + 1
    end
    if port > @counter_end
      port = @counter_start
    end
    port
  end

  def port_available?(port)
    port_open?(port)
  end

  # http://stackoverflow.com/a/22752150/36170
  def port_open?(port)
    !system("lsof -i:#{port}", out: '/dev/null')
  end
end
