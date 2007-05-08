# This doesn't get stored in trac, since it changes every time.
providers = Puppet::Util::Reference.newreference :providers, :depth => 1, :dynamic => true, :doc => "Which providers are valid for this machine" do
    types = []
    Puppet::Type.loadall
    Puppet::Type.eachtype do |klass|
        next unless klass.providers.length > 0
        types << klass
    end
    types.sort! { |a,b| a.name.to_s <=> b.name.to_s }

    unless ARGV.empty?
        types.reject! { |type| ! ARGV.include?(type.name.to_s) }
    end

    ret = "Details about this host:\n\n"

    # Throw some facts in there, so we know where the report is from.
    ["Ruby Version", "Puppet Version", "Operating System", "Operating System Release"].each do |label|
        name = label.gsub(/\s+/, '')
        value = Facter.value(name)
        ret += option(label, value)
    end
    ret += "\n"
    types.each do |type|
        ret += h(type.name.to_s + "_", 2)
        ret += ".. _%s: %s\n\n" % [type.name, "http://reductivelabs.com/trac/puppet/wiki/TypeReference#%s" % type.name]
        features = type.features
        unless features.empty?
            ret += option("Available Features", features.collect { |f| f.to_s }.sort.join(", "))
        end
        ret += "\n" # add a trailing newline
        type.providers.sort { |a,b| a.to_s <=> b.to_s }.each do |pname|
            provider = type.provider(pname)
            ret += h(provider.name, 3)

            unless features.empty?
                ret += option(:features, provider.features.collect { |a| a.to_s }.sort.join(", "))
            end
            if missing = provider.suitable?(false) and missing.empty?
                ret += option(:suitable?, "true")
            else
                ret += option(:suitable?, "false")
                ret += "\n" # must add a blank line before the list
                missing.each do |test, values|
                    case test
                    when :exists:
                        ret += "- Missing files %s\n" % values.join(", ")
                    when :facter:
                        values.each do |name, facts|
                            ret += "- Fact %s (currently %s) not in list %s\n" % [name, Facter.value(name).inspect, facts.join(", ")]
                        end
                    when :true:
                        ret += "- Got %s true tests that should have been false\n" % values
                    when :false:
                        ret += "- Got %s false tests that should have been true\n" % values
                    end
                end
            end
            ret += "\n" # add a trailing newline
        end
        ret += "\n"
    end

    ret += "\n"

    ret
end
providers.header = "
Puppet resource types are usually backed by multiple implementations called ``providers``,
which handle variance between platforms and tools.

Different providers are suitable or unsuitable on different platforms based on things
like the presence of a given tool.

Here are all of the provider-backed types and their different providers.  Any unmentioned
types do not use providers yet.

"
