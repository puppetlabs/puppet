require 'puppet/file_collection/lookup'
require 'puppet/parser/yaml_trimmer'

 # The parameters we stick in Resources.
class Puppet::Parser::Resource::Param
    attr_accessor :name, :value, :source, :add
    include Puppet::Util
    include Puppet::Util::Errors
    include Puppet::Util::MethodHelper

    include Puppet::FileCollection::Lookup
    include Puppet::Parser::YamlTrimmer

    def initialize(hash)
        set_options(hash)
        requiredopts(:name, :value, :source)
        @name = symbolize(@name)
    end

    def line_to_i
        return line ? Integer(line) : nil
    end

    def to_s
        "%s => %s" % [self.name, self.value]
    end
end
