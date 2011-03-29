require 'puppet/application'
require 'puppet/string'

class Puppet::Application::StringBase < Puppet::Application
  should_parse_config
  run_mode :agent

  def preinit
    super
    trap(:INT) do
      $stderr.puts "Cancelling String"
      exit(0)
    end
  end

  option("--debug", "-d") do |arg|
    Puppet::Util::Log.level = :debug
  end

  option("--verbose", "-v") do
    Puppet::Util::Log.level = :info
  end

  option("--format FORMAT") do |arg|
    @format = arg.to_sym
  end

  option("--mode RUNMODE", "-r") do |arg|
    raise "Invalid run mode #{arg}; supported modes are user, agent, master" unless %w{user agent master}.include?(arg)
    self.class.run_mode(arg.to_sym)
    set_run_mode self.class.run_mode
  end


  attr_accessor :string, :type, :verb, :arguments, :format
  attr_writer :exit_code

  # This allows you to set the exit code if you don't want to just exit
  # immediately but you need to indicate a failure.
  def exit_code
    @exit_code || 0
  end

  def main
    # Call the method associated with the provided action (e.g., 'find').
    if result = string.send(verb, *arguments)
      puts render(result)
    end
    exit(exit_code)
  end

  # Override this if you need custom rendering.
  def render(result)
    render_method = Puppet::Network::FormatHandler.format(format).render_method
    if render_method == "to_pson"
      jj result
      exit(0)
    else
      result.send(render_method)
    end
  end

  def preinit
    # We need to parse enough of the command line out early, to identify what
    # the action is, so that we can obtain the full set of options to parse.
    #
    # This requires a partial parse first, and removing the options that we
    # understood, then identification of the next item, then another round of
    # the same until we have the string and action all set. --daniel 2011-03-29
    #
    # NOTE: We can't use the Puppet::Application implementation of option
    # parsing because it is (*ahem*) going to puts on $stderr and exit when it
    # hits a parse problem, not actually let us reuse stuff. --daniel 2011-03-29

    # TODO: These should be configurable versions, through a global
    # '--version' option, but we don't implement that yet... --daniel 2011-03-29
    @type   = self.class.name.to_s.sub(/.+:/, '').downcase.to_sym
    @string = Puppet::String[@type, :current]
    @format = @string.default_format

    # Now, collect the global and string options and parse the command line.
    begin
      @string.options.inject OptionParser.new do |options, option|
        option = @string.get_option option # turn it into the object, bleh
        options.on(*option.to_optparse) do |value|
          puts "REVISIT: do something with #{value.inspect}"
        end
      end.parse! command_line.args.dup
    rescue OptionParser::InvalidOption => e
      puts e.inspect            # ...and ignore??
    end

    fail "REVISIT: Finish this code, eh..."
  end

  def setup
    Puppet::Util::Log.newdestination :console

    # We copy all of the app options to the end of the call; This allows each
    # action to read in the options.  This replaces the older model where we
    # would invoke the action with options set as global state in the
    # interface object.  --daniel 2011-03-28
    @verb = command_line.args.shift
    @arguments = Array(command_line.args) << options
    validate
  end

  def validate
    unless verb
      raise "You must specify #{string.actions.join(", ")} as a verb; 'save' probably does not work right now"
    end

    unless string.action?(verb)
      raise "Command '#{verb}' not found for #{type}"
    end
  end
end
