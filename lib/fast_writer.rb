module CrazyLogger
  # This is a patched version of ActiveSupport::BufferedLogger 2.2.2
  # The serverity levels have been removed and the message format has been changed to make
  # it cleaner for our purposes
  class FastWriter

    MAX_BUFFER_SIZE = 100000

    # Set to false to disable the silencer

    attr_accessor :level
    attr_reader :auto_flushing

    def initialize(device)
      @buffer        = {}
      @auto_flushing = 1
      @guard = Mutex.new

      if device.respond_to?(:write)
        @device = device
      elsif File.exist?(device)
        @device = open(device, (File::WRONLY | File::APPEND))
        @device.sync = true
      else
        FileUtils.mkdir_p(File.dirname(device))
        @device = open(device, (File::WRONLY | File::APPEND | File::CREAT))
        @device.sync = true
        @device.write("# Output file created on %s" % [Time.now.to_s])
      end
    end

    def add(message = nil)
      # If a newline is necessary then create a new message ending with a newline.
      # Ensures that the original message is not mutated.
      message = "#{message}\n" unless message[-1] == ?\n
      buffer << message
      auto_flush
      message
      return
    end

    # Set the auto-flush period. Set to true to flush after every log message,
    # to an integer to flush every N messages, or to false, nil, or zero to
    # never auto-flush. If you turn auto-flushing off, be sure to regularly
    # flush the log yourself -- it will eat up memory until you do.
    def auto_flushing=(period)
      @auto_flushing =
        case period
        when true;                1
        when false, nil, 0;       MAX_BUFFER_SIZE
        when Integer;             period
        else raise ArgumentError, "Unrecognized auto_flushing period: #{period.inspect}"
        end
    end

    def flush
      @guard.synchronize do
        unless buffer.empty?
          old_buffer = buffer
          clear_buffer
          @device.write(old_buffer.join)
        end
      end
    end

    def close
      flush
      @device.close if @device.respond_to?(:close)
      @device = nil
    end

    protected
      def auto_flush
        flush if buffer.size >= @auto_flushing
      end

      def buffer
        @buffer[Thread.current] ||= []
      end

      def clear_buffer
        @buffer.delete(Thread.current)
      end
  end
end

  