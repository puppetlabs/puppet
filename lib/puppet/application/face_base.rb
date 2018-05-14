require 'puppet/application'
require 'puppet/face'
require 'optparse'
require 'pp'

class Puppet::Application::FaceBase < Puppet::Application
  option("--debug", "-d") do |arg|
    set_log_level(:debug => true)
  end

  option("--verbose", "-v") do |_|
    set_log_level(:verbose => true)
  end

  option("--render-as FORMAT") do |format|
    self.render_as = format.to_sym
  end

  option("--help", "-h") do |arg|
    if action && !@is_default_action
      # Only invoke help on the action if it was specified, not if
      # it was the default action.
      puts Puppet::Face[:help, :current].help(face.name, action.name)
    else
      puts Puppet::Face[:help, :current].help(face.name)
    end
    exit(0)
  end

  attr_accessor :face, :action, :type, :arguments, :render_as

  def render_as=(format)
    @render_as = Puppet::Network::FormatHandler.format(format)
    @render_as or raise ArgumentError, _("I don't know how to render '%{format}'") % { format: format }
  end

  def render(result, args_and_options)
    hook = action.when_rendering(render_as.name)

    if hook
      # when defining when_rendering on your action you can optionally
      # include arguments and options
      if hook.arity > 1
        result = hook.call(result, *args_and_options)
      else
        result = hook.call(result)
      end
    end

    render_as.render(result)
  end

  def preinit
    super
    Signal.trap(:INT) do
      $stderr.puts _("Cancelling Face")
      exit(0)
    end
  end

  def parse_options
    # We need to parse enough of the command line out early, to identify what
    # the action is, so that we can obtain the full set of options to parse.

    # REVISIT: These should be configurable versions, through a global
    # '--version' option, but we don't implement that yet... --daniel 2011-03-29
    @type = Puppet::Util::ConstantInflector.constant2file(self.class.name.to_s.sub(/.+:/, '')).to_sym
    @face = Puppet::Face[@type, :current]

    # Now, walk the command line and identify the action.  We skip over
    # arguments based on introspecting the action and all, and find the first
    # non-option word to use as the action.
    action_name = nil
    index       = -1
    until action_name or (index += 1) >= command_line.args.length do
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
            # ... But, the mandatory argument will not be the next item if an = is
            # employed in the long form of the option. --jeffmccune 2012-09-18
            index += 1 unless item =~ /^--#{option.name}=/
          end
        elsif option = find_application_argument(item) then
          index += 1 if (option[:argument] and not option[:optional])
        else
          raise OptionParser::InvalidOption.new(item.sub(/=.*$/, ''))
        end
      else
        # Stash away the requested action name for later, and try to fetch the
        # action object it represents; if this is an invalid action name that
        # will be nil, and handled later.
        action_name = item.to_sym
        @action = Puppet::Face.find_action(@face.name, action_name)
        @face   = @action.face if @action
      end
    end

    if @action.nil?
      if @action = @face.get_default_action() then
        @is_default_action = true
      else
        # First try to handle global command line options
        # But ignoring invalid options as this is a invalid action, and
        # we want the error message for that instead.
        begin
          super
        rescue OptionParser::InvalidOption
        end

        face   = @face.name
        action = action_name.nil? ? 'default' : "'#{action_name}'"
        msg = _("'%{face}' has no %{action} action.  See `puppet help %{face}`.") % { face: face, action: action }

        Puppet.err(msg)
        Puppet::Util::Log.force_flushqueue()

        exit false
      end
    end

    # Now we can interact with the default option code to build behaviour
    # around the full set of options we now know we support.
    @action.options.each do |o|
      o = @action.get_option(o) # make it the object.
      self.class.option(*o.optparse) # ...and make the CLI parse it.
    end

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

    # If we don't have a rendering format, set one early.
    self.render_as ||= (@action.render_as || :console)
  end


  def main
    status = false

    # Call the method associated with the provided action (e.g., 'find').
    unless @action
      puts Puppet::Face[:help, :current].help(@face.name)
      raise _("%{face} does not respond to action %{arg}") % { face: face, arg: arguments.first }
    end

    # We need to do arity checking here because this is generic code
    # calling generic methods – that have argument defaulting.  We need to
    # make sure we don't accidentally pass the options as the first
    # argument to a method that takes one argument.  eg:
    #
    #   puppet facts find
    #   => options => {}
    #      @arguments => [{}]
    #   => @face.send :bar, {}
    #
    #   def face.bar(argument, options = {})
    #   => bar({}, {})  # oops!  we thought the options were the
    #                   # positional argument!!
    #
    # We could also fix this by making it mandatory to pass the options on
    # every call, but that would make the Ruby API much more annoying to
    # work with; having the defaulting is a much nicer convention to have.
    #
    # We could also pass the arguments implicitly, by having a magic
    # 'options' method that was visible in the scope of the action, which
    # returned the right stuff.
    #
    # That sounds attractive, but adds complications to all sorts of
    # things, especially when you think about how to pass options when you
    # are writing Ruby code that calls multiple faces.  Especially if
    # faces are involved in that. ;)
    #
    # --daniel 2011-04-27
    if (arity = @action.positional_arg_count) > 0
      unless (count = arguments.length) == arity then
        raise ArgumentError, n_("puppet %{face} %{action} takes %{arg_count} argument, but you gave %{given_count}", "puppet %{face} %{action} takes %{arg_count} arguments, but you gave %{given_count}", arity - 1) % { face: @face.name, action: @action.name, arg_count: arity-1, given_count: count-1 }
      end
    end

    if @face.deprecated?
      Puppet.deprecation_warning(_("'puppet %{face}' is deprecated and will be removed in a future release") % { face: @face.name })
    end

    result = @face.send(@action.name, *arguments)
    puts render(result, arguments) unless result.nil?
    status = true

  # We need an easy way for the action to set a specific exit code, so we
  # rescue SystemExit here; This allows each action to set the desired exit
  # code by simply calling Kernel::exit.  eg:
  #
  #   exit(2)
  #
  # --kelsey 2012-02-14
  rescue SystemExit => detail
    status = detail.status

  rescue => detail
    Puppet.log_exception(detail)
    Puppet.err _("Try 'puppet help %{face} %{action}' for usage") % { face: @face.name, action: @action.name }

  ensure
    exit status
  end
end
