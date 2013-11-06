require 'puppet/ssl/certificate_authority'

# This class wraps a given command and invokes it with a CSR name and body to
# determine if the given CSR should be autosigned
#
# @api private
class Puppet::SSL::CertificateAuthority::AutosignCommand

  class CheckFailure < Puppet::Error; end

  def initialize(path)
    @path = path
  end

  # Run the autosign command with the given CSR name as an argument and the
  # CSR body on stdin.
  #
  # @param name [String] The CSR name to check for autosigning
  # @return [true, false] If the CSR should be autosigned
  def allowed?(name)
    csr = Puppet::SSL::CertificateRequest.indirection.find(name)
    if csr.nil?
      raise CheckFailure, "Could not run autosign_command for #{name}: no CSR for #{name}"
    end

    cmd = "#{@path} #{name}"
    csr_file = Tempfile.new('puppet-csr')
    csr_file.write(csr.to_s)
    csr_file.close

    execute_options = {:stdinfile => csr_file.path, :combine => true, :failonfail => false}
    output = Puppet::Util::Execution.execute(cmd, execute_options)

    output.chomp!

    Puppet.info "autosign_command '#{cmd}' completed with exit status #{output.exitstatus}"
    Puppet.debug "Output of autosign_command '#{cmd}': #{output}"

    case output.exitstatus
    when 0
      true
    else
      false
    end
  end
end
