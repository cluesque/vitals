require 'statsd'

module Vitals
  class Reporter
    def initialize(host, port)
      # note: multi threading depends on Statsd's capability for
      # protecting its socket.
      @stats = Statsd.new(host, port)
    end

    def report!(args)
      delta = args[2] - args[1]
      delta = (delta > 0) ? delta : 0
      @stats.timing(args[0], delta)
    end
  end
end
