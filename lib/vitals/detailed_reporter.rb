require 'statsd'

module Vitals
  class DetailedReporter
    def initialize host, port
      # note: multi threading depends on Statsd's capability for
      # protecting its socket.
      @stats = Statsd.new(host, port)
    end

    def prefix=(prefix)
      @prefix = prefix + '.'
    end

    def get_metric_prefix
      @prefix ||= ''
    end

    def report!(args)
      @report_parser = DetailedReporter::ArghParser.new args

      push_to_statsd @report_parser
    end

    def push_to_statsd report_parser
      return if report_parser.nil?

      if report_parser.is_controller?
        @stats.increment "#{get_metric_prefix}controllers.#{report_parser.name}.response.#{report_parser.http_response}"
        @stats.timing "#{get_metric_prefix}controllers.#{report_parser.name}.view", report_parser.view_runtime
        @stats.timing "#{get_metric_prefix}controllers.#{report_parser.name}.db", report_parser.db_runtime
        @stats.timing "#{get_metric_prefix}controllers.#{report_parser.name}.action", report_parser.calculate_delta

      elsif report_parser.is_model?

        @stats.timing "#{get_metric_prefix}models.#{report_parser.name}", report_parser.calculate_delta

      elsif report_parser.is_view?
        @stats.timing "#{get_metric_prefix}views.#{report_parser.name}", report_parser.calculate_delta
      end
    end

    # ARGH!
    class ArghParser
      def initialize args
        @args = args
        @http_response = nil
        @name = nil
        @type = nil
        @db_runtime = nil
        @view_runtime = nil

        return unless defined? args.first

        case args.first
          when "process_action.action_controller"
            extract_metrics_for_controllers
          when "sql.active_record"
            extract_metrics_for_models
          when "render_partial.action_view"
            extract_metrics_for_views
          else
            # do nothing
        end
      end

      def get_start_time
        return nil unless defined? @args[1]

        @args[1]
      end

      def get_finish_time
        return nil unless defined? @args[2]

        @args[2]
      end

      def calculate_delta
        return 0 if get_finish_time.nil? or get_start_time.nil?

        delta = get_finish_time - get_start_time
        (delta > 0) ? (delta * 24 * 60 * 60).to_i : 0
      end

      def is_controller?
        @type == "controller"
      end

      def is_model?
        @type == "model"
      end

      def is_view?
        @type == "view"
      end

      def name
        @name
      end

      def http_response
        @http_response
      end

      def view_runtime
        @view_runtime
      end

      def db_runtime
        @db_runtime
      end

      def extract_controller_name
        return "controller" if @args[4].nil?
        return "controller" if @args[4][:controller].nil?

        @args[4][:controller]
      end

      def extract_controller_action
        return "action" if @args[4].nil?
        return "action" if @args[4][:action].nil?

        @args[4][:action]
      end

      def extract_view_runtime
        return 0 if @args[4].nil?
        return 0 if @args[4][:view_runtime].nil?

        @args[4][:view_runtime]
      end

      def extract_db_runtime
        return 0 if @args[4].nil?
        return 0 if @args[4][:db_runtime].nil?

        @args[4][:db_runtime]
      end

      def extract_http_response
        return "0" if @args[4].nil?
        return "0" if @args[4][:status].nil?

        @args[4][:status]
      end

      def extract_metrics_for_controllers
        @name = "#{extract_controller_name}.#{extract_controller_action}"
        @http_response = extract_http_response
        @view_runtime = extract_view_runtime
        @db_runtime = extract_db_runtime

        @type = "controller"
      end

      def extract_model_basename
        return nil unless defined? @args[4][:name]

        @args[4][:name]
      end

      def extract_metrics_for_models
        model_basename = extract_model_basename
        return if model_basename == "SCHEMA"

        call_stack = Rails.backtrace_cleaner.clean(caller[2..-1])
        if call_stack.empty?
          return if model_basename.nil?

          @name = model_basename.gsub(" Load", ".find")
        else
          classname = File.basename(call_stack.first.split(":").first.gsub(".rb", "").gsub(".", "_"))
          method = if (parts = call_stack.first.scan(/`.*'/)) && parts.present?
            parts.first.gsub("`","").gsub("'","").gsub(" ","_")
          else
            call_stack.first.split(":").last
          end
          @name = "#{classname}.#{method}"
        end

        @type = "model"
      end

      def extract_view_name
        return "" unless defined? @args[4][:identifier]

        File.basename(@args[4][:identifier].gsub(".", "_"))
      end

      def extract_metrics_for_views
        @name = extract_view_name
        @type = "view"
      end
    end
  end
end
