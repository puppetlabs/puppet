class Puppet::Resource::Ral < Puppet::Indirector::Code
    def find( request )
        # find by name
        res   = type(request).instances.find { |o| o.name == resource_name(request) }
        res ||= type(request).new(:name => resource_name(request), :check => type(request).properties.collect { |s| s.name })

        return res.to_resource
    end

    def search( request )
        conditions = request.options.dup
        conditions[:name] = resource_name(request) if resource_name(request)

        type(request).instances.map do |res|
            res.to_resource
        end.find_all do |res|
            conditions.all? {|property, value| res.to_resource[property].to_s == value.to_s}
        end.sort do |a,b|
            a.title <=> b.title
        end
    end

    def save( request )
        # In RAL-land, to "save" means to actually try to change machine state
        res = request.instance
        ral_res = res.to_ral

        catalog = Puppet::Resource::Catalog.new
        catalog.add_resource ral_res
        catalog.apply

        return ral_res.to_resource
    end

    private

    def type_name( request )
        request.key.split('/')[0]
    end

    def resource_name( request )
        request.key.split('/')[1]
    end

    def type( request )
        Puppet::Type.type(type_name(request)) or raise Puppet::Error, "Could not find type #{type}"
    end
end
