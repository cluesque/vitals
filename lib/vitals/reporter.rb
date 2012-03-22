require 'statsd'

module Vitals
  class NullReporter
    def report!(args)
      puts "#{args[0]}: #{args[2]-args[1]}"
      puts "--------------\n#{args.inspect}\n-----------\n"
    end
  end

  class Reporter
    def initialize(host, port)
      # note: multi threading depends on Statsd's capability for
      # protecting its socket.
      @stats = Statsd.new(host, port)
    end
    def report!(args)
			if args.first == "process_action.action_controller"
				ap "CONTROLLER IS FINITO"
				ap args[4]
			elsif args.first == "sql.active_record"
				ap "DAS querize!"
				ap args
			elsif args.first == "partial.action_view"
				ap "MIS VIEWS"
				ap args[4]
			else
				ap "OTHRE"
				ap args			
			end		
		
      delta = args[2] - args[1]
      delta = (delta > 0) ? delta : 0
			ap delta

      @stats.timing(args[0], delta)
    end
  end
end
