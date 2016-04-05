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
  ["Ruby Version", "Puppet Version", "Operating System", "Operating System Release"].each do |label|
    name = label.gsub(/\s+/, '')
    value = Facter.value(name)
    ret << option(label, value)
  end
  ret << "\n"

  count = 1

  # Produce output for each type.
  types.each do |type|
    features = type.features
    ret << "\n" # add a trailing newline

    # Now build up a table of provider suitability.
    headers = %w{Provider Suitable?} + features.collect { |f| f.to_s }.sort

    table_data = {}

    functional = false
    notes = []
    default = type.defaultprovider ? type.defaultprovider.name : 'none'
    type.providers.sort { |a,b| a.to_s <=> b.to_s }.each do |pname|
      data = []
      table_data[pname] = data
      provider = type.provider(pname)

      # Add the suitability note
      if missing = provider.suitable?(false) and missing.empty?
        data << "*X*"
        suit = true
        functional = true
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
            details << "  - Missing files #{values.join(", ")}\n"
          when :variable
            values.each do |name, facts|
              if Puppet.settings.valid?(name)
                details << "  - Setting #{name} (currently #{Puppet.settings.value(name).inspect}) not in list #{facts.join(", ")}\n"
              else
                details << "  - Fact #{name} (currently #{Facter.value(name).inspect}) not in list #{facts.join(", ")}\n"
              end
            end
          when :true
            details << "  - Got #{values} true tests that should have been false\n"
          when :false
            details << "  - Got #{values} false tests that should have been true\n"
          when :feature
            details << "  - Missing features #{values.collect { |f| f.to_s }.join(",")}\n"
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

    ret << "[#{type.name}](https://docs.puppetlabs.com/puppet/latest/reference/type.html##{type.name})\n\n"
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
