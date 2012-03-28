require 'active_support/notifications'
require 'vitals/reporter'

module Vitals
  class Engine < Rails::Engine
    config.vitals = ActiveSupport::OrderedOptions.new

    config.vitals.enabled = true
    config.vitals.host = 'localhost'
    config.vitals.port = 8125
		config.vitals.type = 'normal'

    initializer "vitals.configure" do |app|
			puts config.vitals
			puts app.config.vitals
      Vitals.configure(app.config.vitals.host, app.config.vitals.port, app.config.vitals.type) if app.config.vitals.enabled
    end

    initializer "vitals.subscribe" do |app|
      ActiveSupport::Notifications.subscribe /[^!]$/ do |*args|
        Vitals.report! args 
      end
    end
  end


  @reporter = NullReporter.new

  def self.report!(args)
    @reporter.report!(args)
  end

  def self.configure(host, port, type = 'normal')
		puts host
		puts port
		puts type
		
		case type
		when 'normal'
			puts 'when normal'
    	@reporter = Reporter.new(host, port)
		when 'detailed'
			puts 'when detailed'
			@reporter = DetailedReporter.new(host, post)
		else
			puts 'when neither'
			@reporter = NullReporter.new
		end
  end
end
