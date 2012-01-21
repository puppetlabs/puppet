require 'puppet/face'
require 'puppet/util/command_line'
require 'pathname'
require 'erb'

Puppet::Face.define(:help, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Display Puppet help."

  action(:help) do
    summary "Display help about Puppet subcommands and their actions."
    arguments "[<subcommand>] [<action>]"
    returns "Short help text for the specified subcommand or action."
    examples <<-'EOT'
      Get help for an action:

      $ puppet help
    EOT

    option "--version VERSION" do
      summary "The version of the subcommand for which to show help."
    end

    default
    when_invoked do |*args|
      # Check our invocation, because we want varargs and can't do defaults
      # yet.  REVISIT: when we do option defaults, and positional options, we
      # should rewrite this to use those. --daniel 2011-04-04
      options = args.pop
      if options.nil? or args.length > 2 then
        if args.select { |x| x == 'help' }.length > 2 then
          c = "\n %'(),-./=ADEFHILORSTUXY\\_`gnv|".split('')
          i = <<-'EOT'.gsub(/\s*/, '').to_i(36)
            3he6737w1aghshs6nwrivl8mz5mu9nywg9tbtlt081uv6fq5kvxse1td3tj1wvccmte806nb
            cy6de2ogw0fqjymbfwi6a304vd56vlq71atwmqsvz3gpu0hj42200otlycweufh0hylu79t3
            gmrijm6pgn26ic575qkexyuoncbujv0vcscgzh5us2swklsp5cqnuanlrbnget7rt3956kam
            j8adhdrzqqt9bor0cv2fqgkloref0ygk3dekiwfj1zxrt13moyhn217yy6w4shwyywik7w0l
            xtuevmh0m7xp6eoswin70khm5nrggkui6z8vdjnrgdqeojq40fya5qexk97g4d8qgw0hvokr
            pli1biaz503grqf2ycy0ppkhz1hwhl6ifbpet7xd6jjepq4oe0ofl575lxdzjeg25217zyl4
            nokn6tj5pq7gcdsjre75rqylydh7iia7s3yrko4f5ud9v8hdtqhu60stcitirvfj6zphppmx
            7wfm7i9641d00bhs44n6vh6qvx39pg3urifgr6ihx3e0j1ychzypunyou7iplevitkyg6gbg
            wm08oy1rvogcjakkqc1f7y1awdfvlb4ego8wrtgu9vzw4vmj59utwifn2ejcs569dh1oaavi
            sc581n7jjg1dugzdu094fdobtx6rsvk3sfctvqnr36xctold
          EOT
          353.times{i,x=i.divmod(1184);a,b=x.divmod(37);print(c[a]*b)}
        end
        raise ArgumentError, "Puppet help only takes two (optional) arguments: a subcommand and an action"
      end

      version = :current
      if options.has_key? :version then
        if options[:version].to_s !~ /^current$/i then
          version = options[:version]
        else
          if args.length == 0 then
            raise ArgumentError, "Version only makes sense when a Faces subcommand is given"
          end
        end
      end

      # Name those parameters...
      facename, actionname = args

      if facename then
        if legacy_applications.include? facename then
          actionname and raise ArgumentError, "Legacy subcommands don't take actions"
          return Puppet::Application[facename].help
        else
          face = Puppet::Face[facename.to_sym, version]
          actionname and action = face.get_action(actionname.to_sym)
        end
      end

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
    erb = ERB.new(template.read, nil, '-')
    erb.filename = template.to_s
    return erb
  end

  def legacy_applications
    # The list of applications, less those that are duplicated as a face.
    Puppet::Util::CommandLine.available_subcommands.reject do |appname|
      Puppet::Face.face? appname.to_sym, :current or
        # ...this is a nasty way to exclude non-applications. :(
        %w{face_base indirection_base}.include? appname
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
