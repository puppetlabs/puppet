require 'puppet/face'
require 'puppet/util'
require 'pathname'
require 'erb'

Puppet::Face.define(:man, '0.0.1') do
  copyright "Puppet Inc.", 2011
  license   _("Apache 2 license; see COPYING")

  summary _("Display Puppet manual pages.")

  description <<-EOT
    Please use the command 'puppet help <subcommand>' or the system manpage system
    'man puppet-<subcommand>' to display information about Puppet subcommands. The
    deprecated man subcommand displays manual pages for all Puppet subcommands. If
    the `ronn` gem (<https://github.com/rtomayko/ronn/>) is installed on your
    system, puppet man will display fully-formatted man pages. If `ronn` is not
    available, puppet man will display the raw (but human-readable) source text
    in a pager.
  EOT

  notes <<-EOT
    The pager used for display will be the first found of `$MANPAGER`, `$PAGER`,
    `less`, `most`, or `more`.
  EOT

  action(:man) do
    summary _("Display the manual page for a Puppet subcommand.")
    arguments _("<subcommand>")
    #TRANSLATORS '--render-as s' is a command line option and should not be translated
    returns _(<<-'EOT')
      The man data, in Markdown format, suitable for consumption by Ronn.

      RENDERING ISSUES: To skip fancy formatting and output the raw Markdown
      text (e.g. for use in a pipeline), call this action with '--render-as s'.
    EOT
    examples <<-'EOT'
      View the installed manual page for the subcommand 'config':

      $ man puppet-config

      (Deprecated) View the manual page for the subcommand 'config':

      $ puppet man config
    EOT

    default
    when_invoked do |*args|
      # 'args' is an array of the subcommand and arguments from the command line and an options hash
      # [<arg1>, ..., {options}]
      _options = args.pop

      unless valid_command_line?(args)
        print_man_help
        #TRANSLATORS 'puppet man' is a specific command line and should not be translated
        raise ArgumentError, _("The 'puppet man' command takes a single subcommand to review the subcommand's manpage")
      end

      manpage = args.first
      if default_case?(manpage)
        print_man_help
        return nil
      end

      if legacy_applications.include?(manpage)
        return Puppet::Application[manpage].help
      end

      # set 'face' as it's used in the erb processing.
      face = Puppet::Face[manpage.to_sym, :current]
      _face = face # suppress the unused variable warning

      file = (Pathname(__FILE__).dirname + "help" + 'man.erb')
      erb = ERB.new(file.read, nil, '-')
      erb.filename = file.to_s

      # Run the ERB template in our current binding, including all the local
      # variables we established just above. --daniel 2011-04-11
      return erb.result(binding)
    end

    when_rendering :console do |text|
      # OK, if we have Ronn on the path we can delegate to it and override the
      # normal output process.  Otherwise delegate to a pager on the raw text,
      # otherwise we finally just delegate to our parent.  Oh, well.

      # These are the same options for less that git normally uses.
      # -R : Pass through color control codes (allows display of colors)
      # -X : Don't init/deinit terminal (leave display on screen on exit)
      # -F : automatically exit if display fits entirely on one screen
      # -S : don't wrap long lines
      ENV['LESS'] ||= 'FRSX'

      ronn  = Puppet::Util.which('ronn')
      pager = [ENV['MANPAGER'], ENV['PAGER'], 'less', 'most', 'more'].
        detect {|x| x and x.length > 0 and Puppet::Util.which(x) }

      if ronn
        # ronn is a stupid about pager selection, we can be smarter. :)
        ENV['PAGER'] = pager if pager

        args  = "--man --manual='Puppet Manual' --organization='Puppet Inc., LLC'"
        # manual pages could contain UTF-8 text
        IO.popen("#{ronn} #{args}", 'w:UTF-8') do |fh| fh.write text end

        ''                      # suppress local output, neh?
      elsif pager
        # manual pages could contain UTF-8 text
        IO.popen(pager, 'w:UTF-8') do |fh| fh.write text end
        ''
      else
        text
      end
    end
  end

  def valid_command_line?(args)
    # not too many arguments
    # This allows the command line case of "puppet man man man" to not throw an error because face_based eats
    # one of the "man"'s, which means this command line ends up looking like this in the code: 'manface.man("man")'
    # However when we generate manpages, we do the same call. So we have to allow it and generate the real manpage.
    args.length <= 1
  end

  # by default, if you ask for the man manpage "puppet man man" face_base removes the "man" from the args that we
  # are passed, so we get nil instead
  def default_case?(manpage)
    manpage.nil?
  end

  def print_man_help
    puts Puppet::Face[:help, :current].help(:man)
  end

  def legacy_applications
    # The list of applications, less those that are duplicated as a face.
    Puppet::Application.available_application_names.reject do |appname|
      Puppet::Face.face? appname.to_sym, :current or
        # ...this is a nasty way to exclude non-applications. :(
        %w{face_base indirection_base}.include? appname
    end
  end

  deprecate
end
