require 'active_support/notifications'
require 'vitals/reporters'

module Vitals
  class Engine < Rails::Engine
    config.vitals = ActiveSupport::OrderedOptions.new

    config.vitals.enabled = true
    config.vitals.host = 'localhost'
    config.vitals.port = 8125
		config.vitals.reporter = 'reporter'

    initializer "vitals.configure" do |app|
      Vitals.configure(app.config.vitals.host, app.config.vitals.port, app.config.vitals.reporter) if app.config.vitals.enabled
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

  def self.configure(host, port, reporter = 'reporter')
		@reporter = Vitals.const_get(reporter.titleize.gsub(' ', '')).new(host, port)		
  end
end
