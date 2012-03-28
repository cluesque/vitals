module Vitals
  class NullReporter
		def initialize hosti = nil, port = nil
		end

    def report!(args)
      puts "#{args[0]}: #{args[2]-args[1]}"
      puts "--------------\n#{args.inspect}\n-----------\n"
    end
  end
end
