providers = Puppet::Util::Reference.newreference :providers, :doc => "Which providers are valid for this machine" do
    types = []
    Puppet::Type.loadall
    Puppet::Type.eachtype do |klass|
        next unless klass.providers.length > 0
        types << klass
    end
    types.sort! { |a,b| a.name.to_s <=> b.name.to_s }

    ret = ""
    types.each do |type|
        ret += h(type.name, 2)
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
            if provider.suitable?
                ret += option(:suitable?, "true")
            else
                ret += option(:suitable?, "false")
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
