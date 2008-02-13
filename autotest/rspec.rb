require 'autotest'

class RspecCommandError < StandardError; end

class Autotest::Rspec < Autotest
  
  def initialize(kernel=Kernel, separator=File::SEPARATOR, alt_separator=File::ALT_SEPARATOR) # :nodoc:
    super()
    @kernel, @separator, @alt_separator = kernel, separator, alt_separator
    @spec_command = spec_command

    # watch out: Ruby bug (1.8.6):
    # %r(/) != /\//
    # since Ruby compares the REGEXP source, not the resulting pattern
    @test_mappings = {
      %r%^spec/.*\.rb$% => kernel.proc { |filename, _| 
        filename 
      },
      %r%^lib/(.*)\.rb$% => kernel.proc { |_, m| 
        ["spec/#{m[1]}_spec.rb"] 
      },
      %r%^spec/(spec_helper|shared/.*)\.rb$% => kernel.proc { 
        files_matching %r%^spec/.*_spec\.rb$% 
      }
    }
  end
  
  def tests_for_file(filename)
    super.select { |f| @files.has_key? f }
  end
  
  alias :specs_for_file :tests_for_file
  
  def failed_results(results)
    results.scan(/^\d+\)\n(?:\e\[\d*m)?(?:.*?Error in )?'([^\n]*)'(?: FAILED)?(?:\e\[\d*m)?\n(.*?)\n\n/m)
  end

  def handle_results(results)
    @files_to_test = consolidate_failures failed_results(results)
    unless @files_to_test.empty? then
      hook :red
    else
      hook :green
    end unless $TESTING
    @tainted = true unless @files_to_test.empty?
  end

  def consolidate_failures(failed)
    filters = Hash.new { |h,k| h[k] = [] }
    failed.each do |spec, failed_trace|
      @files.keys.select{|f| f =~ /spec\//}.each do |f|
        if failed_trace =~ Regexp.new(f)
          filters[f] << spec
          break
        end
      end
    end
    return filters
  end

  def make_test_cmd(files_to_test)
    return "#{ruby} -S #{@spec_command} #{add_options_if_present} #{files_to_test.keys.flatten.join(' ')}"
  end
  
  def add_options_if_present
    File.exist?("spec/spec.opts") ? "-O spec/spec.opts " : ""
  end

  # Finds the proper spec command to use.  Precendence
  # is set in the lazily-evaluated method spec_commands.  Alias + Override
  # that in ~/.autotest to provide a different spec command
  # then the default paths provided.
  def spec_command
    spec_commands.each do |command|
      if File.exists?(command)
        return @alt_separator ? (command.gsub @separator, @alt_separator) : command
      end
    end
    
    raise RspecCommandError, "No spec command could be found!"
  end
  
  # Autotest will look for spec commands in the following
  # locations, in this order:
  #
  #   * bin/spec
  #   * default spec bin/loader installed in Rubygems
  def spec_commands
    [
      File.join('bin', 'spec'),
      File.join(Config::CONFIG['bindir'], 'spec')
    ]
  end

end
