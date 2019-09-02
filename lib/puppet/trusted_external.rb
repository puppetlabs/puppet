# A method for retrieving external trusted facts
module Puppet::TrustedExternal
  def retrieve(certname)
    command = Puppet[:trusted_external_command]
    return nil unless command
    result = Puppet::Util::Execution.execute([command, certname], {
      :combine => false,
      :failonfail => true,
    })
    JSON.parse(result)
  end
  module_function :retrieve
end
