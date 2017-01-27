require 'semantic_puppet/dependency'

module SemanticPuppet
  module Dependency
    class Source
      def self.priority
        0
      end

      def priority
        self.class.priority
      end

      def create_release(name, version, dependencies = {})
        version = Version.parse(version) if version.is_a? String
        dependencies = dependencies.inject({}) do |hash, (key, value)|
          hash[key] = VersionRange.parse(value || '>= 0.0.0')
          hash[key] ||= VersionRange::EMPTY_RANGE
          hash
        end
        ModuleRelease.new(self, name, version, dependencies)
      end
    end
  end
end
