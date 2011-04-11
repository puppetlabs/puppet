require 'puppet/faces'
require 'puppet/util/command_line'

Puppet::Faces.define(:help, '0.0.1') do
  HelpSummaryFormat = '  %-18s  %s'

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
        message << "Available subcommands, from Puppet Faces:"
        Puppet::Faces.faces.sort.each do |name|
          face = Puppet::Faces[name, :current]
          message << format(HelpSummaryFormat, face.name, face.summary)
        end

        unless legacy_applications.empty? then # great victory when this is true!
          message << ""
          message << "Available applications, soon to be ported to Faces:"
          legacy_applications.each do |appname|
            summary = horribly_extract_summary_from appname
            message << format(HelpSummaryFormat, appname, summary)
          end
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
