require 'puppet/module_tool'

module Puppet::ModuleTool

  # = ContentsDescription
  #
  # This class populates +Metadata+'s Puppet type information.
  class ContentsDescription

    # Instantiate object for string +module_path+.
    def initialize(module_path)
      @module_path = module_path
    end

    # Update +Metadata+'s Puppet type information.
    def annotate(metadata)
      metadata.types.replace data.clone
    end

    # Return types for this module. Result is an array of hashes, each of which
    # describes a Puppet type. The type description hash structure is:
    # * :name => Name of this Puppet type.
    # * :doc => Documentation for this type.
    # * :properties => Array of hashes representing the type's properties, each
    #   containing :name and :doc.
    # * :parameters => Array of hashes representing the type's parameters, each
    #   containing :name and :doc.
    # * :providers => Array of hashes representing the types providers, each
    #   containing :name and :doc.
    # TODO Write a TypeDescription to encapsulate these structures and logic?
    def data
      unless @data
        @data = []
        type_names = []
        for module_filename in Dir[File.join(@module_path, "lib/puppet/type/*.rb")]
          require module_filename
          type_name = File.basename(module_filename, ".rb")
          type_names << type_name

          for provider_filename in Dir[File.join(@module_path, "lib/puppet/provider/#{type_name}/*.rb")]
            require provider_filename
          end
        end

        type_names.each do |name|
          if type = Puppet::Type.type(name.to_sym)
            type_hash = {:name => name, :doc => type.doc}
            type_hash[:properties] = attr_doc(type, :property)
            type_hash[:parameters] = attr_doc(type, :param)
            if type.providers.size > 0
              type_hash[:providers] = provider_doc(type)
            end
            @data << type_hash
          else
            Puppet.warning _("Could not find/load type: %{name}") % { name: name }
          end
        end
      end
      @data
    end

    # Return an array of hashes representing this +type+'s attrs of +kind+
    # (e.g. :param or :property), each containing :name and :doc.
    def attr_doc(type, kind)
      attrs = []

      type.allattrs.each do |name|
        if type.attrtype(name) == kind && name != :provider
          attrs.push(:name => name, :doc => type.attrclass(name).doc)
        end
      end

      attrs
    end

    # Return an array of hashes representing this +type+'s providers, each
    # containing :name and :doc.
    def provider_doc(type)
      providers = []

      type.providers.sort.each do |prov|
        providers.push(:name => prov, :doc => type.provider(prov).doc)
      end

      providers
    end
  end
end
