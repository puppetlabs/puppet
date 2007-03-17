require 'spec/runner/option_parser'

module Spec
  module Runner
    # Facade to run specs without having to fork a new ruby process (using `spec ...`)
    class CommandLine
      # Runs specs. +argv+ is the commandline args as per the spec commandline API, +err+ 
      # and +out+ are the streams output will be written to. +exit+ tells whether or
      # not a system exit should be called after the specs are run and
      # +warn_if_no_files+ tells whether or not a warning (the help message)
      # should be printed to +err+ in case no files are specified.
      def self.run(argv, err, out, exit=true, warn_if_no_files=true)
        old_context_runner = defined?($context_runner) ? $context_runner : nil
        $context_runner = OptionParser.new.create_context_runner(argv, err, out, warn_if_no_files)
        return if $context_runner.nil? # This is the case if we use --drb

        # If ARGV is a glob, it will actually each over each one of the matching files.
        argv.each do |file_or_dir|
          if File.directory?(file_or_dir)
            Dir["#{file_or_dir}/**/*.rb"].each do |file| 
              load file
            end
          elsif File.file?(file_or_dir)
            load file_or_dir
          else
            raise "File or directory not found: #{file_or_dir}"
          end
        end
        $context_runner.run(exit)
        $context_runner = old_context_runner
      end
    end
  end
end