require File.join(File.dirname(__FILE__), "spec_helper")

if SafeYAML::YAML_ENGINE == "psych"
  require "safe_yaml/psych_resolver"

  describe SafeYAML::PsychResolver do
    include ResolverSpecs
    let(:resolver) { SafeYAML::PsychResolver.new }
  end
end
