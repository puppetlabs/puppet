module Puppet::Module::Tool::Errors
  class ModuleToolError < StandardError
    def v(version)
      (version || '???').to_s.sub(/^(?=\d)/, 'v')
    end
  end
end
