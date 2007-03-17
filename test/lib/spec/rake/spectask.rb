#!/usr/bin/env ruby

# Define a task library for running RSpec contexts.

require 'rake'
require 'rake/tasklib'

module Spec
  module Rake

    # A Rake task that runs a set of RSpec contexts.
    #
    # Example:
    #  
    #   Spec::Rake::SpecTask.new do |t|
    #     t.warning = true
    #     t.rcov = true
    #   end
    #
    # This will create a task that can be run with:
    #
    #   rake spec
    #
    class SpecTask < ::Rake::TaskLib

      # Name of spec task. (default is :spec)
      attr_accessor :name

      # Array of directories to be added to $LOAD_PATH before running the
      # specs. Defaults to ['<the absolute path to RSpec's lib directory>']
      attr_accessor :libs

      # If true, requests that the specs be run with the warning flag set.
      # E.g. warning=true implies "ruby -w" used to run the specs. Defaults to false.
      attr_accessor :warning

      # Glob pattern to match spec files. (default is 'spec/**/*_spec.rb')
      attr_accessor :pattern

      # Array of commandline options to pass to RSpec. Defaults to [].
      attr_accessor :spec_opts

      # Where RSpec's output is written. Defaults to STDOUT.
      attr_accessor :out

      # Whether or not to use RCov (default is false)
      # See http://eigenclass.org/hiki.rb?rcov
      attr_accessor :rcov
      
      # Array of commandline options to pass to RCov. Defaults to ['--exclude', 'lib\/spec,bin\/spec'].
      # Ignored if rcov=false
      attr_accessor :rcov_opts

      # Directory where the RCov report is written. Defaults to "coverage"
      # Ignored if rcov=false
      attr_accessor :rcov_dir

      # Array of commandline options to pass to ruby. Defaults to [].
      attr_accessor :ruby_opts

      # Whether or not to fail Rake when an error occurs (typically when specs fail).
      # Defaults to true.
      attr_accessor :fail_on_error

      # A message to print to stdout when there are failures.
      attr_accessor :failure_message

      # Explicitly define the list of spec files to be included in a
      # spec.  +list+ is expected to be an array of file names (a
      # FileList is acceptable).  If both +pattern+ and +spec_files+ are
      # used, then the list of spec files is the union of the two.
      def spec_files=(list)
        @spec_files = list
      end

      # Create a specing task.
      def initialize(name=:spec)
        @name = name
        @libs = [File.expand_path(File.dirname(__FILE__) + '/../../../lib')]
        @pattern = nil
        @spec_files = nil
        @spec_opts = []
        @warning = false
        @ruby_opts = []
        @out = nil
        @fail_on_error = true
        @rcov = false
        @rcov_opts = ['--exclude', 'lib\/spec,bin\/spec,config\/boot.rb']
        @rcov_dir = "coverage"

        yield self if block_given?
        @pattern = 'spec/**/*_spec.rb' if @pattern.nil? && @spec_files.nil?
        define
      end

      def define
        spec_script = File.expand_path(File.dirname(__FILE__) + '/../../../bin/spec')

        lib_path = @libs.join(File::PATH_SEPARATOR)
        actual_name = Hash === name ? name.keys.first : name
        unless ::Rake.application.last_comment
          desc "Run RSpec for #{actual_name}" + (@rcov ? " using RCov" : "")
        end
        task @name do
          RakeFileUtils.verbose(@verbose) do
            ruby_opts = @ruby_opts.clone
            ruby_opts.push( "-I\"#{lib_path}\"" )
            ruby_opts.push( "-S rcov" ) if @rcov
            ruby_opts.push( "-w" ) if @warning

            redirect = @out.nil? ? "" : " > \"#{@out}\""

            unless spec_file_list.empty?
              # ruby [ruby_opts] -Ilib -S rcov [rcov_opts] bin/spec -- [spec_opts] examples
              # or
              # ruby [ruby_opts] -Ilib bin/spec [spec_opts] examples
              begin
                ruby(
                  ruby_opts.join(" ") + " " + 
                  rcov_option_list +
                  (@rcov ? %[ -o "#{@rcov_dir}" ] : "") + 
                  '"' + spec_script + '"' + " " +
                  (@rcov ? "-- " : "") + 
                  spec_file_list.collect { |fn| %["#{fn}"] }.join(' ') + " " + 
                  spec_option_list + " " +
                  redirect
                )
              rescue => e
                 puts @failure_message if @failure_message
                 raise e if @fail_on_error
              end
            end
          end
        end

        if @rcov
          desc "Remove rcov products for #{actual_name}"
          task paste("clobber_", actual_name) do
            rm_r @rcov_dir rescue nil
          end

          clobber_task = paste("clobber_", actual_name)
          task :clobber => [clobber_task]

          task actual_name => clobber_task
        end
        self
      end

      def rcov_option_list # :nodoc:
        return "" unless @rcov
        ENV['RCOVOPTS'] || @rcov_opts.join(" ") || ""
      end

      def spec_option_list # :nodoc:
        ENV['RSPECOPTS'] || @spec_opts.join(" ") || ""
      end

      def spec_file_list # :nodoc:
        if ENV['SPEC']
          FileList[ ENV['SPEC'] ]
        else
          result = []
          result += @spec_files.to_a if @spec_files
          result += FileList[ @pattern ].to_a if @pattern
          FileList[result]
        end
      end

    end
  end
end

