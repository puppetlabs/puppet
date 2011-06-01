require 'puppet/face'
require 'pathname'
require 'erb'

Puppet::Face.define(:man, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Display Puppet subcommand manual pages."

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
