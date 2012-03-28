require 'spec_helper'
require 'rails'
require "#{File.dirname(__FILE__)}/../lib/vitals/reporters"

module Vitals
  describe DetailedReporter do
    let(:host) {"23.21.142.181"}
    let(:port) {8125}
    let(:company) {"distributedlife"}
    let(:product) {"vitals"}
    let(:environment) {"local"}
    let(:release) {"zero"}
    let(:controller_identifier) {"process_action.action_controller"}
    let(:model_identifier) {"sql.active_record"}
    let(:view_identifier) {"render_partial.action_view"}
    let(:id) {"3491a45768813c1551b5"}
    let(:controller_name) {"Devise::SessionsController"}
    let(:controller_action) {"new"}
    let(:http_response) {"200"}
    let(:view_runtime) {1310.363695}
    let(:db_runtime) {29.178016999999997}
    let(:view_name) {"/path/to/my/file.rb.lol"}
    let(:model_name) {"User Load"}
    let(:start_time) {DateTime.parse "2012-03-23 15:10:27 +1100"}
    let(:finish_time) {DateTime.parse "2012-03-23 15:10:29 +1100"}

    let(:sample_controller) {{:controller => controller_name, :action => controller_action, :status => http_response, :view_runtime => view_runtime, :db_runtime => db_runtime}}
    let(:sample_view) {{:identifier => view_name}}
    let(:sample_model) {{:name => model_name}}

    before(:each) do
      ENV['COMPANY'] = company
      ENV['PRODUCT'] = product
      ENV['ENV'] = environment
      ENV['RELEASE'] = release
    end

    describe 'initialise' do
      it 'should setup a statsd client with the supplied port and host' do
        Statsd.should_receive(:new).with(host, port)

        DetailedReporter.new host, port
      end
    end

    describe 'get_metric_prefix' do
      let(:subject) {DetailedReporter.new host, port}

      it 'should use company, product, env and release environment variables' do
        subject.get_metric_prefix.should == "#{company}.#{product}.#{environment}.#{release}.metrics"
      end
    end

    describe 'report!' do
      let(:subject) {DetailedReporter.new host, port}
      let(:args) {}
      let(:prefix) {"#{company}.#{product}.#{environment}.#{release}.metrics"}

      it 'should create a report_parser' do
        DetailedReporter::ArghParser.should_receive(:new).with(args)

        subject.report! args
      end

      describe 'for controllers' do
        let(:args) {[controller_identifier, start_time, finish_time, id, sample_controller]}

        before(:each) do
          @statsd = mock(Statsd).as_null_object
          Statsd.stub(:new).and_return(@statsd)
        end

        it 'should send the view, db and action runtime' do
          @statsd.should_receive(:timing).with("#{prefix}.controllers.#{controller_name}.#{controller_action}.view", view_runtime)
          @statsd.should_receive(:timing).with("#{prefix}.controllers.#{controller_name}.#{controller_action}.db", db_runtime)
          @statsd.should_receive(:timing).with("#{prefix}.controllers.#{controller_name}.#{controller_action}.action", 2)

          subject.report! args
        end

        it 'should increment response.x where x is the response' do
          @statsd.should_receive(:increment).with("#{prefix}.controllers.#{controller_name}.#{controller_action}.response.#{http_response}")

          subject.report! args
        end
      end

      describe 'for models' do
        let(:args) {[model_identifier, start_time, finish_time, id, sample_model]}
        before(:each) do
          @statsd = mock(Statsd).as_null_object
          Statsd.stub(:new).and_return(@statsd)
        end

        it 'should send the action runtime' do
          @statsd.should_receive(:timing).with("#{prefix}.models.User.find", 2)

          subject.report! args
        end
      end

      describe 'for views' do
        let(:args) {[view_identifier, start_time, finish_time, id, sample_view]}
        before(:each) do
          @statsd = mock(Statsd).as_null_object
          Statsd.stub(:new).and_return(@statsd)
        end

        it 'should send the action runtime' do
          @statsd.should_receive(:timing).with("#{prefix}.views.file_rb_lol", 2)

          subject.report! args
        end
      end
    end

    describe DetailedReporter::ArghParser do

      describe 'initialize' do
        let(:args) {}
        let(:subject) {DetailedReporter::ArghParser.new args}

        it 'should setup defaults' do
          subject.get_start_time.nil?.should == true
          subject.get_finish_time.nil?.should == true
          subject.name.nil?.should == true
          subject.http_response.nil?.should == true
          subject.view_runtime.nil?.should == true
          subject.db_runtime.nil?.should == true
          subject.is_controller?.should == false
          subject.is_model?.should == false
          subject.is_view?.should == false
        end

        it 'should determine if controller' do
          parser = DetailedReporter::ArghParser.new [controller_identifier]
          parser.is_controller?.should == true
        end

        it 'should determine if model' do
          parser = DetailedReporter::ArghParser.new [model_identifier, nil, nil, id, {:name => ""}]
          parser.is_model?.should == true
        end

        it 'should determine if view' do
          parser = DetailedReporter::ArghParser.new [view_identifier]
          parser.is_view?.should == true
        end
      end

      describe 'get_start_time' do
        let(:now) {Time.now}
        let(:args) {["", now]}
        let(:subject) {DetailedReporter::ArghParser.new args}

        it 'should return if defined' do
          subject.get_start_time.should == now
        end

        it 'should return nil if not defined' do
          parser = DetailedReporter::ArghParser.new ["", nil]

          parser.get_start_time.nil?.should == true
        end
      end

      describe 'get_finish_time' do
        let(:now) {Time.now}
        let(:args) {["", nil, now]}
        let(:subject) {DetailedReporter::ArghParser.new args}

        it 'should return if defined' do
          subject.get_finish_time.should == now
        end

        it 'should return nil if not defined' do
          parser = DetailedReporter::ArghParser.new ["", now, nil]

          parser.get_finish_time.nil?.should == true
        end
      end

      describe 'calculate_delta' do
        let(:prior) {Time.now - 1}
        let(:now) {prior + 1}
        let(:args) {["", prior, now]}
        let(:subject) {DetailedReporter::ArghParser.new args}

        it 'should return the difference between finish and start' do
          subject.calculate_delta.should == 86400
        end

        it 'should return zero if the number is negative' do
          parser = DetailedReporter::ArghParser.new ["", now, prior]

          parser.calculate_delta.should == 0
        end

        it 'should return zero if either date is invalid' do
          parser = DetailedReporter::ArghParser.new ["", nil, prior]
          parser.calculate_delta.should == 0
          parser = DetailedReporter::ArghParser.new ["", prior, nil]
          parser.calculate_delta.should == 0
        end
      end

      describe 'is_controller?' do
        let(:valid_args){[controller_identifier]}
        let(:invalid_args){["a#{controller_identifier}"]}

        it 'should return true when args is "process_action.action_controller"' do
          DetailedReporter::ArghParser.new(valid_args).is_controller?.should == true
        end

        it 'should return false when args is not "process_action.action_controller"' do
          DetailedReporter::ArghParser.new(invalid_args).is_controller?.should == false
        end
      end

      describe 'is_model?' do
        let(:valid_args){[model_identifier, nil, nil, id, {:name => ""}]}
        let(:valid_args_but_schema){[model_identifier, nil, nil, id, {:name => "SCHEMA"}]}
        let(:invalid_args){[model_identifier]}

        it 'should return true when args is "sql.active_record"' do
          DetailedReporter::ArghParser.new(valid_args).is_model?.should == true
        end

        it 'should return false when sql.name is SCHEMA' do
          DetailedReporter::ArghParser.new(valid_args_but_schema).is_model?.should == false
        end

        it 'should return false when args is not "sql.active_record"' do
          DetailedReporter::ArghParser.new(invalid_args).is_model?.should == false
        end
      end

      describe 'is_view?' do
        let(:valid_args){[view_identifier]}
        let(:invalid_args){view_identifier}

        it 'should return true when args is "render_partial.action_view"' do
          DetailedReporter::ArghParser.new(valid_args).is_view?.should == true
        end

        it 'should return false when args is not "render_partial.action_view"' do
          DetailedReporter::ArghParser.new(invalid_args).is_view?.should == false
        end
      end

      describe 'name' do

        it 'should return the controller.action for controllers' do
          DetailedReporter::ArghParser.any_instance.should_receive(:extract_controller_name)
          DetailedReporter::ArghParser.any_instance.should_receive(:extract_controller_action)

          DetailedReporter::ArghParser.new [controller_identifier]
        end

        it 'should return the model for models' do
          DetailedReporter::ArghParser.any_instance.should_receive(:extract_model_basename)

          DetailedReporter::ArghParser.new [model_identifier, nil, nil, id, sample_model]
        end

        it 'should return the view name for views' do
          DetailedReporter::ArghParser.any_instance.should_receive(:extract_view_name)

          DetailedReporter::ArghParser.new [view_identifier]
        end
      end

      describe 'extract_controller_name' do
        it 'should return "" if not defined' do
          sample_controller.delete :controller
          DetailedReporter::ArghParser.new([controller_identifier, Time.now, Time.now, id, sample_controller]).extract_controller_name.should == "controller"
        end

        it 'should return the defined value' do
          DetailedReporter::ArghParser.new([controller_identifier, Time.now, Time.now, id, sample_controller]).extract_controller_name.should == controller_name
        end
      end

      describe 'extract_controller_action' do
        it 'should return "" if not defined' do
          sample_controller.delete :action
          DetailedReporter::ArghParser.new([controller_identifier, Time.now, Time.now, id, sample_controller]).extract_controller_action.should == "action"
        end

        it 'should return the defined value' do
          DetailedReporter::ArghParser.new([controller_identifier, Time.now, Time.now, id, sample_controller]).extract_controller_action.should == controller_action
        end
      end

      describe 'extract_view_runtime' do
        it 'should return 0 if not defined' do
          sample_controller.delete :view_runtime
          DetailedReporter::ArghParser.new([controller_identifier, Time.now, Time.now, id, sample_controller]).extract_view_runtime.should == 0
        end

        it 'should return the defined value' do
          DetailedReporter::ArghParser.new([controller_identifier, Time.now, Time.now, id, sample_controller]).extract_view_runtime.should == view_runtime
        end
      end

      describe 'extract_db_runtime' do
        it 'should return 0 if not defined' do
          sample_controller.delete :db_runtime
          DetailedReporter::ArghParser.new([controller_identifier, Time.now, Time.now, id, sample_controller]).extract_db_runtime.should == 0
        end

        it 'should return the defined value' do
          DetailedReporter::ArghParser.new([controller_identifier, Time.now, Time.now, id, sample_controller]).extract_db_runtime.should == db_runtime
        end
      end

      describe 'extract_http_response' do
        it 'should return 0 if not defined' do
          DetailedReporter::ArghParser.new([controller_identifier, Time.now, Time.now, id, {}]).extract_http_response.should == "0"
        end

        it 'should return the defined value' do
          DetailedReporter::ArghParser.new([controller_identifier, Time.now, Time.now, id, {:status => "200"}]).extract_http_response.should == "200"
        end
      end

      describe 'extract_view_name' do
        it 'should return an empty string if not defined' do
          DetailedReporter:: ArghParser.new([view_identifier, Time.now, Time.now, id{}]).extract_view_name.should == ""
        end

        it 'should extract the path from the source file, strip the directory and replace dots with underscores' do
          DetailedReporter::ArghParser.new([view_identifier, Time.now, Time.now, id, sample_view]).extract_view_name.should == "file_rb_lol"
        end
      end

      describe 'extract_model_basename' do
        let(:subject){DetailedReporter::ArghParser.new([model_identifier, Time.now, Time.now, id, sample_model])}

        it 'should return MODEL.find when the name is Model Load and there is not stack trace' do
          subject.name.should == "User.find"
        end

        it 'should return the top of the stack if there is a stack trace' do
          backtrace = ["app/models/project.rb:85:in `get_active_count'", "app/views/projects/_projects.html.haml:9:in `block in _app_views_projects__projects_html_haml___980593303_93929060'", "app/views/projects/_projects.html.haml:2:in `each'", "app/views/projects/_projects.html.haml:2:in `_app_views_projects__projects_html_haml___980593303_93929060'", "app/views/projects/index.html.haml:6:in `_app_views_projects_index_html_haml___148106522_95905030'"]
          Rails.backtrace_cleaner.stub(:clean).and_return(backtrace)

          subject.name.should == "project.get_active_count"
        end
      end

      describe 'extract_metrics_for_controllers' do
        let(:subject){DetailedReporter::ArghParser.new([controller_identifier, Time.now, Time.now, id, sample_controller])}

        it 'sets the name to the controller name.action' do
          subject.name.should == "#{controller_name}.#{controller_action}"
        end

        it 'sets the http response' do
          subject.http_response.should == "200"
        end

        it 'sets the view runtime' do
          subject.view_runtime.should == view_runtime
        end

        it 'sets the db runtime' do
          subject.db_runtime.should == db_runtime
        end
      end

      describe 'extract_metrics_for_models' do
        let(:subject){DetailedReporter::ArghParser.new([model_identifier, Time.now, Time.now, id, sample_model])}

        it 'should set the name' do
          subject.name.should == "User.find"
        end
      end

      describe 'extract_metrics_for_views' do
        let(:subject){DetailedReporter::ArghParser.new([controller_identifier, Time.now, Time.now, id, sample_view])}

        it 'should extract the view name' do
          subject.extract_view_name.should == "file_rb_lol"
        end
      end
    end
  end
end
