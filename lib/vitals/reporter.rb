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

		def get_metric_prefix
  		"#{ENV['COMPANY']}.#{ENV['PRODUCT']}.#{ENV['ENV']}.#{ENV['RELEASE']}.metrics"
		end

    def report!(args)
			if args.first == "process_action.action_controller"
				name = "#{args[4][:controller]}.#{args[4][:action]}"
				#ap args[4][:path]
				#ap args[4][:status]
				#ap "view_runtime: #{args[4][:view_runtime]}ms"
				#ap "db_runtime: #{args[4][:db_runtime]}ms"

				puts "#{get_metric_prefix}.#{name}.view"
				puts "#{get_metric_prefix}.#{name}.db"
				puts "#{get_metric_prefix}.#{name}.action"

				if args[4][:status] == 200
					puts "#{get_metric_prefix}.#{name}.success"
				else
					puts "#{get_metric_prefix}.#{name}.other"
				end					
			elsif args.first == "sql.active_record"
				return if args[4][:name] == "SCHEMA"

				call_stack = Rails.backtrace_cleaner.clean(caller[2..-1])
				if args[4][:name].nil?
					name = call_stack.first.scan(/`.*'/)
				else
					if call_stack.empty?
						name = args[4][:name].gsub(" Load", ".find")
					else
						name = call_stack.first.scan(/`.*'/)
					end
				end
				ap name
				ap args[4][:sql]
			elsif args.first == "render_partial.action_view"
				name = File.basename(args[4][:identifier].gsub(".", "_"))

				puts "#{get_metric_prefix}.#{name}"
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
