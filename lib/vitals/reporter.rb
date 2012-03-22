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
				ap "#{args[4][:controller]}.#{args[4][:action]}"
				ap args[4][:path]
				ap args[4][:status]
				ap "view_runtime: #{args[4][:view_runtime]}ms"
				ap "db_runtime: #{args[4][:db_runtime]}ms"
			elsif args.first == "sql.active_record"
				return if args[4][:name] == "SCHEMA"
				ap args[4][:name]
				ap args[4][:sql]
				Rails.backtrace_cleaner.clean(caller[2..-1]).each { |l| ap l}
			elsif args.first == "render_partial.action_view"
				ap File.basename(args[4][:identifier].gsub(".", "_"))
			else
				return
			end		
		
      delta = args[2] - args[1]
      delta = (delta > 0) ? delta : 0
			ap "#{delta}s"
			ap "*" * 80
      @stats.timing(args[0], delta)
    end
  end
end
