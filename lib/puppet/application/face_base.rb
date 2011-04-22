require 'puppet/application'
require 'puppet/face'
require 'optparse'
require 'pp'

class Puppet::Application::FaceBase < Puppet::Application
  should_parse_config
  run_mode :agent

  option("--debug", "-d") do |arg|
    Puppet::Util::Log.level = :debug
  end

  option("--verbose", "-v") do
    Puppet::Util::Log.level = :info
  end

  option("--render-as FORMAT") do |arg|
    @render_as = arg.to_sym
  end

  option("--mode RUNMODE", "-r") do |arg|
    raise "Invalid run mode #{arg}; supported modes are user, agent, master" unless %w{user agent master}.include?(arg)
    self.class.run_mode(arg.to_sym)
    set_run_mode self.class.run_mode
  end


  attr_accessor :face, :action, :type, :arguments, :render_as
  attr_writer :exit_code

  # This allows you to set the exit code if you don't want to just exit
  # immediately but you need to indicate a failure.
  def exit_code
    @exit_code || 0
  end

  def render(result)
    format = render_as || action.render_as || :for_humans

    # Invoke the rendering hook supplied by the user, if appropriate.
    if hook = action.when_rendering(format) then
      result = hook.call(result)
    end

    if format == :for_humans then
      render_for_humans(result)
    else
      render_method = Puppet::Network::FormatHandler.format(format).render_method
      if render_method == "to_pson"
        PSON::pretty_generate(result, :allow_nan => true, :max_nesting => false)
      else
        result.send(render_method)
      end
    end
  end

  def render_for_humans(result)
    # String to String
    return result if result.is_a? String
    return result if result.is_a? Numeric

    # Simple hash to table
    if result.is_a? Hash and result.keys.all? { |x| x.is_a? String or x.is_a? Numeric }
      output = ''
      column_a = result.map do |k,v| k.to_s.length end.max + 2
      column_b = 79 - column_a
      result.sort_by { |k,v| k.to_s } .each do |key, value|
        output << key.to_s.ljust(column_a)
        output << PP.pp(value, '', column_b).
          chomp.gsub(/\n */) { |x| x + (' ' * column_a) }
        output << "\n"
      end
      return output
    end

    # ...or pretty-print the inspect outcome.
    return result.pretty_inspect
  end

  def preinit
    super
    Signal.trap(:INT) do
      $stderr.puts "Cancelling Face"
      exit(0)
    end
  end

  def parse_options
    # We need to parse enough of the command line out early, to identify what
    # the action is, so that we can obtain the full set of options to parse.

    # REVISIT: These should be configurable versions, through a global
    # '--version' option, but we don't implement that yet... --daniel 2011-03-29
    @type = self.class.name.to_s.sub(/.+:/, '').downcase.to_sym
    @face = Puppet::Face[@type, :current]

    # Now, walk the command line and identify the action.  We skip over
    # arguments based on introspecting the action and all, and find the first
    # non-option word to use as the action.
    action = nil
    index  = -1
    until @action or (index += 1) >= command_line.args.length do
      item = command_line.args[index]
      if item =~ /^-/ then
        option = @face.options.find do |name|
          item =~ /^-+#{name.to_s.gsub(/[-_]/, '[-_]')}(?:[ =].*)?$/
        end
        if option then
          option = @face.get_option(option)
          # If we have an inline argument, just carry on.  We don't need to
          # care about optional vs mandatory in that case because we do a real
          # parse later, and that will totally take care of raising the error
          # when we get there. --daniel 2011-04-04
          if option.takes_argument? and !item.index('=') then
            index += 1 unless
              (option.optional_argument? and command_line.args[index + 1] =~ /^-/)
          end
        elsif option = find_global_settings_argument(item) then
          unless Puppet.settings.boolean? option.name then
            # As far as I can tell, we treat non-bool options as always having
            # a mandatory argument. --daniel 2011-04-05
            index += 1          # ...so skip the argument.
          end
        elsif option = find_application_argument(item) then
          index += 1 if (option[:argument] and option[:optional])
        else
          raise OptionParser::InvalidOption.new(item.sub(/=.*$/, ''))
        end
      else
        @action = @face.get_action(item.to_sym)
      end
    end

    if @action.nil?
      @action = @face.get_default_action()
      @is_default_action = true
    end

    # Now we can interact with the default option code to build behaviour
    # around the full set of options we now know we support.
    @action.options.each do |option|
      option = @action.get_option(option) # make it the object.
      self.class.option(*option.optparse) # ...and make the CLI parse it.
    end if @action

    # ...and invoke our parent to parse all the command line options.
    super
  end

  def find_global_settings_argument(item)
    Puppet.settings.each do |name, object|
      object.optparse_args.each do |arg|
        next unless arg =~ /^-/
        # sadly, we have to emulate some of optparse here...
        pattern = /^#{arg.sub('[no-]', '').sub(/[ =].*$/, '')}(?:[ =].*)?$/
        pattern.match item and return object
      end
    end
    return nil                  # nothing found.
  end

  def find_application_argument(item)
    self.class.option_parser_commands.each do |options, function|
      options.each do |option|
        next unless option =~ /^-/
        pattern = /^#{option.sub('[no-]', '').sub(/[ =].*$/, '')}(?:[ =].*)?$/
        next unless pattern.match(item)
        return {
          :argument => option =~ /[ =]/,
          :optional => option =~ /[ =]\[/
        }
      end
    end
    return nil                  # not found
  end

  def setup
    Puppet::Util::Log.newdestination :console

    @arguments = command_line.args

    # Note: because of our definition of where the action is set, we end up
    # with it *always* being the first word of the remaining set of command
    # line arguments.  So, strip that off when we construct the arguments to
    # pass down to the face action. --daniel 2011-04-04
    # Of course, now that we have default actions, we should leave the
    # "action" name on if we didn't actually consume it when we found our
    # action.
    @arguments.delete_at(0) unless @is_default_action

    # We copy all of the app options to the end of the call; This allows each
    # action to read in the options.  This replaces the older model where we
    # would invoke the action with options set as global state in the
    # interface object.  --daniel 2011-03-28
    @arguments << options
  end


  def main
    # Call the method associated with the provided action (e.g., 'find').
    if @action
      result = @face.send(@action.name, *arguments)
      puts render(result) unless result.nil?
    else
      if arguments.first.is_a? Hash
        puts "#{@face} does not have a default action"
      else
        puts "#{@face} does not respond to action #{arguments.first}"
      end

      puts Puppet::Face[:help, :current].help(@face.name, *arguments)
    end
    exit(exit_code)
  end
end
