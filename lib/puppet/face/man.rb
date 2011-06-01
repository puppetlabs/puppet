require 'puppet/face'
require 'puppet/util'
require 'pathname'
require 'erb'

Puppet::Face.define(:man, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Display Puppet subcommand manual pages."

  description <<-EOT
    The man face, when invoked from the command line, tries very hard to
    behave nicely for interactive use.  If possible, it delegates to the
    ronn(1) command to format the output as a real manual page.

    If ronn(1) is not available, it will use the first of `$MANPAGER`,
    `$PAGER`, `less`, `most`, or `more` to paginate the (human-readable)
    input text for the manual page.

    We do try hard to ensure that this behaves correctly when used as
    part of a pipeline.  (Well, we delegate to tools that do the right
    thing, which is more or less the same.)
  EOT

  notes <<-EOT
    We strongly encourage you to install the `ronn` gem on your system,
    or otherwise make it available, so that we can display well structured
    output from this face.
  EOT

  action(:man) do
    summary "Display the manual page for a face."
    arguments "<face>"
    returns "The man data, in markdown format, suitable for consumption by Ronn."
    examples <<-'EOT'
      Get the manual page for a face:

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
      ENV['LESS'] ||= 'FRSX'    # emulate git...

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
    Puppet::Util::CommandLine.available_subcommands.reject do |appname|
      Puppet::Face.face? appname.to_sym, :current or
        # ...this is a nasty way to exclude non-applications. :(
        %w{face_base indirection_base}.include? appname
    end
  end
end
