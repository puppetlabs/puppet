require 'puppet/faces'

Puppet::Faces.define(:help, '0.0.1') do
  summary "Displays help about puppet subcommands"

  action(:help) do
    option "--version VERSION" do
      desc "Which version of the interface to show help for"
    end

    when_invoked do |*args|
      # Check our invocation, because we want varargs and can't do defaults
      # yet.  REVISIT: when we do option defaults, and positional options, we
      # should rewrite this to use those. --daniel 2011-04-04
      options = args.pop
      if options.nil? or args.length > 2 then
        raise ArgumentError, "help only takes two (optional) arguments, a face name, and an action"
      end

      if options[:version] and options[:version] !~ /^current$/i then
        version = options[:version]
      else
        version = :current
      end

      message = []
      if args.length == 0 then
        message << "Use: puppet [options] <subcommand> <action>"
        message << ""
        message << "Available commands, from Puppet Faces:"
        Puppet::Faces.faces.sort.each do |name|
          face = Puppet::Faces[name, :current]
          message << format("  %-15s %s", face.name, 'REVISIT: face.desc')
        end
      else
        face = Puppet::Faces[args[0].to_sym, version]
        if args[1] then
          action = face.get_action args[1].to_sym
        else
          action = nil
        end

        help = []
        face.actions.each do |action|
          help << "Action: #{action}"
        end
      end

      message
    end
  end
end
