module Puppet::ModuleTool::Errors
  class ModuleToolError < Puppet::Error
    def v(version)
      (version || '???').to_s.sub(/^(?=\d)/, 'v')
    end

    def vstring
      if @action == :upgrade
        "#{v(@installed_version)} -> #{v(@requested_version)}"
      else
        "#{v(@installed_version || @requested_version)}"
      end
    end
  end
end
