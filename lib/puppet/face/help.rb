require 'puppet/face'
require 'puppet/util/command_line'
require 'pathname'
require 'erb'

Puppet::Face.define(:help, '0.0.1') do
  summary "Displays help about puppet subcommands"

  action(:help) do
    summary "Display help about faces and their actions."

    option "--version VERSION" do
      desc "Which version of the interface to show help for"
    end

    default
    when_invoked do |*args|
      # Check our invocation, because we want varargs and can't do defaults
      # yet.  REVISIT: when we do option defaults, and positional options, we
      # should rewrite this to use those. --daniel 2011-04-04
      options = args.pop
      if options.nil? or args.length > 2 then
        if args.select { |x| x == 'help' }.length > 2 then
          c = "\n !\"'),-./7:;<GIJLST\\_`abcdefhiklmnoprstuwx|}".split('')
          i = <<-'EOT'.gsub(/\s*/, '').to_i(36)
            2s7ytxy5vpj74kbab5xzf1ik2roinzlefaspjrzckiert5xbaxvwlku3a91w7y1rsd
            nenp51gwpulmnrp54nwdil36fjgjarab801y0r5a9nh1hdfgi99arn5c5t3zhxbvzi
            u6wx5r1tb7lun7pro69nrxunqqixsh6qmmv0ms0i0yycqw3pystyzmiita0lpxynqs
            qkbjwadcx82n76wwpzbht8i8rgvqhqick8mk3cs3rvwdjookpgu0rxw4tcezned5sq
            z5x8z9vntyyz0s4h6hjhtwtbytsmmu7ltvdftaixc7fkt276sqm48ab4yv0ot9y26n
            z0xniy4pfl1x300lt6h9c8of49vf799ieuxwnoycsjlmtd4qntzit524j0tdn6n5aj
            mq3z10apjuhkzprvmu53z1gnacymnoforrz5mbqto062kckgw5463pxwzg8liglub4
            ubnr0dln1s6iy3ummxuhim7m5a7yedl3gyy6ow4qqtmsigv27lysooau24zpsccsvx
            ddwygjprqpbwon7i9s1279m1fpinvva8mfh6bgmotrpxsh1c8rc83l3u0utf5i200y
            l7ui0ngcbcjyr4erzdee2tqk3fpjvb82t8xhncruhgn7j5dh2m914qzhb0gkoom47k
            6et7rp4tqjnrv0y2apk5qdl1x1hnbkkxup5ys6ip2ksmtpd3ipmrdtswxr5xwfiqtm
            60uyjr1v79irhnkrbbt4fwhgqjby1qflgwt9c1wpayzzucep6npgbn3f1k6cn4pug3
            1u02wel4tald4hij8m5p49xr8u4ero1ucs5uht42o8nhpmpe7c7xf9t85i85m9m5kk
            tgoqkgbu52gy5aoteyp8jkm3vri9fnkmwa5h60zt8otja72joxjb40p2rz2vp8f8q9
            nnggxt3x90pe5u4048ntyuha78q1oikhhpvw9j083yc3l00hz5ehv9c1au5gvctyap
            zprub289qruve9qsyuh75j04wzkemqw3uhisrfs92u1ahv2qlqxmorgob16c1vbqkx
            ttkoyp2agkt0v5l7lec25p0jqun9y39k41h67aeb5ihiqsftxc9azmg31hc73dk8ur
            lj88vgbmgt8yln9rchw60whgxvnv9zn6cxbr482svctswc5a07atj
          EOT
          607.times{i,x=i.divmod(1035);a,b=x.divmod(23);print(c[a]*b)}
          raise ArgumentError, "Such panic is really not required."
        end
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
    erb = ERB.new(template.read, nil, '%')
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
