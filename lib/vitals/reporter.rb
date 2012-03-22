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

    def metrics_for_controllers args
      name = "#{args[4][:controller]}.#{args[4][:action]}"

      if args[4][:status] == 200
        @stats.increment("#{get_metric_prefix}.#{name}.response.success")
      else
        @stats.increment("#{get_metric_prefix}.#{name}.response.other")
      end

      @stats.timing("#{get_metric_prefix}.#{name}.view", args[4][:view_runtime])
      @stats.timing("#{get_metric_prefix}.#{name}.db", args[4][:db_runtime])
      @stats.timing("#{get_metric_prefix}.#{name}.action", calculate_delta(args))
    end

    def metrics_for_models args
      return if args[4][:name] == "SCHEMA"

      call_stack = Rails.backtrace_cleaner.clean(caller[2..-1])
      if call_stack.empty?
        name = args[4][:name].gsub(" Load", ".find")
      else
        classname = File.basename(call_stack.first.split(":").first.gsub(".rb", "").gsub(".", "_"))
        method = call_stack.first.scan(/`.*'/).first.gsub("`","").gsub("'","").gsub(" ","_")
        name = "#{classname}.#{method}"
      end

      @stats.timing("#{get_metric_prefix}.#{name}", calculate_delta(args))
    end

    def metrics_for_views args
      name = File.basename(args[4][:identifier].gsub(".", "_"))

      @stats.timing("#{get_metric_prefix}.#{name}", calculate_delta(args))
    end

    def calculate_delta args
      delta = args[2] - args[1]

      (delta > 0) ? delta : 0
    end

    def report!(args)
      case args.first
        when "process_action.action_controller"
          metrics_for_controllers args
        when "sql.active_record"
          metrics_for_models args
        when "render_partial.action_view"
          metrics_for_views args
        else
          # do nothing
      end
    end
  end
end
