providers = Puppet::Util::Reference.newreference :providers, :title => "Provider Suitability Report", :depth => 1, :dynamic => true, :doc => "Which providers are valid for this machine" do
  types = []
  Puppet::Type.loadall
  Puppet::Type.eachtype do |klass|
    next unless klass && klass.providers.length > 0
    types << klass
  end
  types.sort! { |a,b| a.name.to_s <=> b.name.to_s }

  command_line = Puppet::Util::CommandLine.new
  types.reject! { |type| ! command_line.args.include?(type.name.to_s) } unless command_line.args.empty?

  ret = "Details about this host:\n\n"

  # Throw some facts in there, so we know where the report is from.
  ret << option('Ruby Version', Facter.value('ruby.version'))
  ret << option('Puppet Version', Facter.value('puppetversion'))
  ret << option('Operating System', Facter.value('os.name'))
  ret << option('Operating System Release', Facter.value('os.release.full'))
  ret << "\n"

  count = 1

  # Produce output for each type.
  types.each do |type|
    features = type.features
    ret << "\n" # add a trailing newline

    # Now build up a table of provider suitability.
    headers = %w{Provider Suitable?} + features.collect { |f| f.to_s }.sort

    table_data = {}

    notes = []
    default = type.defaultprovider ? type.defaultprovider.name : 'none'
    type.providers.sort_by(&:to_s).each do |pname|
      data = []
      table_data[pname] = data
      provider = type.provider(pname)

      # Add the suitability note
      missing = provider.suitable?(false)
      if missing && missing.empty?
        data << "*X*"
        suit = true
      else
        data << "[#{count}]_" # A pointer to the appropriate footnote
        suit = false
      end

      # Add a footnote with the details about why this provider is unsuitable, if that's the case
      unless suit
        details = ".. [#{count}]\n"
        missing.each do |test, values|
          case test
          when :exists
            details << _("  - Missing files %{files}\n") % { files: values.join(", ") }
          when :variable
            values.each do |name, facts|
              if Puppet.settings.valid?(name)
                details << _("  - Setting %{name} (currently %{value}) not in list %{facts}\n") % { name: name, value: Puppet.settings.value(name).inspect, facts: facts.join(", ") }
              else
                details << _("  - Fact %{name} (currently %{value}) not in list %{facts}\n") % { name: name, value: Puppet.runtime[:facter].value(name).inspect, facts: facts.join(", ") }
              end
            end
          when :true
            details << _("  - Got %{values} true tests that should have been false\n") % { values: values }
          when :false
            details << _("  - Got %{values} false tests that should have been true\n") % { values: values }
          when :feature
            details << _("  - Missing features %{values}\n") % { values: values.collect { |f| f.to_s }.join(",") }
          end
        end
        notes << details

        count += 1
      end

      # Add a note for every feature
      features.each do |feature|
        if provider.features.include?(feature)
          data << "*X*"
        else
          data << ""
        end
      end
    end

    ret << markdown_header(type.name.to_s + "_", 2)

    ret << "[#{type.name}](https://puppet.com/docs/puppet/latest/type.html##{type.name})\n\n"
    ret << option("Default provider", default)
    ret << doctable(headers, table_data)

    notes.each do |note|
      ret << note + "\n"
    end

    ret << "\n"
  end

  ret << "\n"

  ret
end
providers.header = "
Puppet resource types are usually backed by multiple implementations called `providers`,
which handle variance between platforms and tools.

Different providers are suitable or unsuitable on different platforms based on things
like the presence of a given tool.

Here are all of the provider-backed types and their different providers.  Any unmentioned
types do not use providers yet.

"
