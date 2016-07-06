require 'puppet/face'
require 'puppet/application/face_base'
require 'puppet/util/constant_inflector'
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

      return erb('global.erb').result(binding) if args.empty?

      facename, actionname = args
      if legacy_applications.include? facename then
        if actionname then
          raise ArgumentError, "Legacy subcommands don't take actions"
        end
        return render_application_help(facename)
      else
        return render_face_help(facename, actionname, version)
      end
    end
  end

  def render_application_help(applicationname)
    return Puppet::Application[applicationname].help
  rescue StandardError, LoadError => detail
    msg = <<-MSG
Could not load help for the application #{applicationname}.
Please check the error logs for more information.

Detail: "#{detail.message}"
MSG
    fail ArgumentError, msg, detail.backtrace
  end

  def render_face_help(facename, actionname, version)
    face, action = load_face_help(facename, actionname, version)
    return template_for(face, action).result(binding)
  rescue StandardError, LoadError => detail
    msg = <<-MSG
Could not load help for the face #{facename}.
Please check the error logs for more information.

Detail: "#{detail.message}"
MSG
    fail ArgumentError, msg, detail.backtrace
  end

  def load_face_help(facename, actionname, version)
    face = Puppet::Face[facename.to_sym, version]
    if actionname
      action = face.get_action(actionname.to_sym)
      if not action
        fail ArgumentError, "Unable to load action #{actionname} from #{face}"
      end
    end

    [face, action]
  end

  def template_for(face, action)
    if action.nil?
      erb('face.erb')
    else
      erb('action.erb')
    end
  end

  def erb(name)
    template = (Pathname(__FILE__).dirname + "help" + name)
    erb = ERB.new(template.read, nil, '-')
    erb.filename = template.to_s
    return erb
  end

  # Return a list of applications that are not simply just stubs for Faces.
  def legacy_applications
    Puppet::Application.available_application_names.reject do |appname|
      (is_face_app?(appname)) or (exclude_from_docs?(appname))
    end.sort
  end

  # Return a list of all applications (both legacy and Face applications), along with a summary
  #  of their functionality.
  # @return [Array] An Array of Arrays.  The outer array contains one entry per application; each
  #  element in the outer array is a pair whose first element is a String containing the application
  #  name, and whose second element is a String containing the summary for that application.
  def all_application_summaries()
    Puppet::Application.available_application_names.sort.inject([]) do |result, appname|
      next result if exclude_from_docs?(appname)

      if (is_face_app?(appname))
        begin
          face = Puppet::Face[appname, :current]
          result << [appname, face.summary]
        rescue StandardError, LoadError
          result << [ "! #{appname}", "! Subcommand unavailable due to error. Check error logs." ]
        end
      else
        result << [appname, horribly_extract_summary_from(appname)]
      end
    end
  end

  def horribly_extract_summary_from(appname)
    begin
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
    rescue StandardError, LoadError
      return "! Subcommand unavailable due to error. Check error logs."
    end
    return ''
  end
  # This should absolutely be a private method, but for some reason it appears
  #  that you can't use the 'private' keyword inside of a Face definition.
  #  See #14205.
  #private :horribly_extract_summary_from

  def exclude_from_docs?(appname)
    %w{face_base indirection_base}.include? appname
  end
  # This should absolutely be a private method, but for some reason it appears
  #  that you can't use the 'private' keyword inside of a Face definition.
  #  See #14205.
  #private :exclude_from_docs?

  def is_face_app?(appname)
    clazz = Puppet::Application.find(appname)

    clazz.ancestors.include?(Puppet::Application::FaceBase)
  end
  # This should probably be a private method, but for some reason it appears
  #  that you can't use the 'private' keyword inside of a Face definition.
  #  See #14205.
  #private :is_face_app?

end
