class HostPortAllocator
  attr_reader :counter_path

  class LockTimeout < StandardError; end

  def initialize(base_dir, counter_start, counter_end)
    @base_dir = base_dir
    @counter_path = File.join(@base_dir, 'host_port_counter')
    @counter_start, @counter_end = counter_start, counter_end
  end

  def allocate_next_port
    port = nil
    File.open(counter_path, File::RDWR|File::CREAT, 0644) do |f|
      # TODO perhaps assume that if lock isn't released then recreate and restart counter
      Timeout::timeout(1, LockTimeout) { f.flock(File::LOCK_EX) }
      previous_port = f.read.to_i
      if previous_port < @counter_start
        port = @counter_start
      else
        port = previous_port + 1
      end
      if port > @counter_end
        port = @counter_start
      end
      f.rewind
      f.write("#{port}\n")
      f.flush
      f.truncate(f.pos)
      f.flock(File::LOCK_UN)
    end
    port
  end
end
