module HarnessOptions

  DEFAULTS = {
    :type => 'git',
    :helper => ['lib/helper.rb'],
    :debug => true,
    :root_keys => true,
  }

  class Aggregator
    attr_reader :mode

    def initialize(mode)
      @mode = mode
    end

    def get_options(file_path)
      puts file_path
      if File.exists? file_path
        options = eval(File.read(file_path), binding)
      else
        puts "No options file found at #{File.expand_path(file_path)}"
      end
      options || {}
    end

    def get_mode_options
      get_options("./config/#{mode}/options.rb")
    end

    def get_local_options
      get_options("./local_options.rb")
    end

    def final_options
      mode_options = get_mode_options
      local_overrides = get_local_options
      final_options = DEFAULTS.merge(mode_options)
      final_options.merge(local_overrides)
    end
  end

  def self.options(mode)
    final_options = Aggregator.new(mode).final_options
    puts "Loading the following options into systest:"
    pp final_options
    final_options
  end
end

HarnessOptions.options(ENV['TESTING_MODE'])
