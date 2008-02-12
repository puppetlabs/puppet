require "drb/drb"

module Spec
  module Runner
    # Facade to run specs by connecting to a DRB server
    class DrbCommandLine
      # Runs specs on a DRB server. Note that this API is similar to that of
      # CommandLine - making it possible for clients to use both interchangeably.
      def self.run(argv, stderr, stdout, exit=true, warn_if_no_files=true)
        begin
          DRb.start_service
          spec_server = DRbObject.new_with_uri("druby://localhost:8989")
          spec_server.run(argv, stderr, stdout)
        rescue DRb::DRbConnError
          stderr.puts "No server is running"
          exit 1 if exit
        end
      end
    end
  end
end
