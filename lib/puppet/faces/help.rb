require 'puppet/faces'
require 'puppet/util/command_line'
require 'pathname'
require 'erb'

Puppet::Faces.define(:help, '0.0.1') do
  summary "Displays help about puppet subcommands"

  action(:help) do
    summary "Display help about faces and their actions."

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

      version = :current
      if options.has_key? :version then
        if options[:version].to_s !~ /^current$/i then
          version = options[:version]
        else
          if args.length == 0 then
            raise ArgumentError, "version only makes sense when a face is given"
          end
        end
      end

      # Name those parameters...
      facename, actionname = args
      face   = facename ? Puppet::Faces[facename.to_sym, version] : nil
      action = (face and actionname) ? face.get_action(actionname.to_sym) : nil

      case args.length
      when 0 then
        template = erb 'global.erb'
      when 1 then
        face or fail ArgumentError, "Unable to load face #{facename}"
        template = erb 'face.erb'
      when 2 then
        face or fail ArgumentError, "Unable to load face #{facename}"
        action or fail ArgumentError, "Unable to load action #{actionname} from #{face}"
        template = erb 'action.erb'
      else
        fail ArgumentError, "Too many arguments to help action"
      end

      # Run the ERB template in our current binding, including all the local
      # variables we established just above. --daniel 2011-04-11
      return template.result(binding)
    end
  end

  def erb(name)
    template = (Pathname(__FILE__).dirname + "help" + name)
    erb = ERB.new(template.read, nil, '%')
    erb.filename = template.to_s
    return erb
  end

  def legacy_applications
    # The list of applications, less those that are duplicated as a face.
    Puppet::Util::CommandLine.available_subcommands.reject do |appname|
      Puppet::Faces.face? appname.to_sym, :current or
        # ...this is a nasty way to exclude non-applications. :(
        %w{faces_base indirection_base}.include? appname
    end.sort
  end

  def horribly_extract_summary_from(appname)
    begin
      require "puppet/application/#{appname}"
      help = Puppet::Application[appname].help.split("\n")
      # Now we find the line with our summary, extract it, and return it.  This
      # depends on the implementation coincidence of how our pages are
      # formatted.  If we can't match the pattern we expect we return the empty
      # string to ensure we don't blow up in the summary. --daniel 2011-04-11
      while line = help.shift do
        if md = /^puppet-#{appname}\([^\)]+\) -- (.*)$/.match(line) then
          return md[1]
        end
      end
    rescue Exception
      # Damn, but I hate this: we just ignore errors here, no matter what
      # class they are.  Meh.
    end
    return ''
  end
end
