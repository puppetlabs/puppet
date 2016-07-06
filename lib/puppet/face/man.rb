require 'puppet/face'
require 'puppet/util'
require 'pathname'
require 'erb'

Puppet::Face.define(:man, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Display Puppet manual pages."

  description <<-EOT
    This subcommand displays manual pages for all Puppet subcommands. If the
    `ronn` gem (<https://github.com/rtomayko/ronn/>) is installed on your
    system, puppet man will display fully-formatted man pages. If `ronn` is not
    available, puppet man will display the raw (but human-readable) source text
    in a pager.
  EOT

  notes <<-EOT
    The pager used for display will be the first found of `$MANPAGER`, `$PAGER`,
    `less`, `most`, or `more`.
  EOT

  action(:man) do
    summary "Display the manual page for a Puppet subcommand."
    arguments "<subcommand>"
    returns <<-'EOT'
      The man data, in Markdown format, suitable for consumption by Ronn.

      RENDERING ISSUES: To skip fancy formatting and output the raw Markdown
      text (e.g. for use in a pipeline), call this action with '--render-as s'.
    EOT
    examples <<-'EOT'
      View the manual page for a subcommand:

      $ puppet man facts
    EOT

    default
    when_invoked do |name, options|
      if legacy_applications.include? name then
        return Puppet::Application[name].help
      end

      face = Puppet::Face[name.to_sym, :current]

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

      if ronn then
        # ronn is a stupid about pager selection, we can be smarter. :)
        if pager then ENV['PAGER'] = pager end

        args  = "--man --manual='Puppet Manual' --organization='Puppet Labs, LLC'"
        IO.popen("#{ronn} #{args}", 'w') do |fh| fh.write text end

        ''                      # suppress local output, neh?
      elsif pager then
        IO.popen(pager, 'w') do |fh| fh.write text end
        ''
      else
        text
      end
    end
  end

  def legacy_applications
    # The list of applications, less those that are duplicated as a face.
    Puppet::Application.available_application_names.reject do |appname|
      Puppet::Face.face? appname.to_sym, :current or
        # ...this is a nasty way to exclude non-applications. :(
        %w{face_base indirection_base}.include? appname
    end
  end
end
