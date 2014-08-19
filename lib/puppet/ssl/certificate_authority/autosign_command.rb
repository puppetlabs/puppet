require 'puppet/ssl/certificate_authority'
require 'puppet/file_system/uniquefile'

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
  # @param csr [String] The CSR name to check for autosigning
  # @return [true, false] If the CSR should be autosigned
  def allowed?(csr)
    name = csr.name
    cmd = [@path, name]

    output = Puppet::FileSystem::Uniquefile.open_tmp('puppet-csr') do |csr_file|
      csr_file.write(csr.to_s)
      csr_file.flush

      execute_options = {:stdinfile => csr_file.path, :combine => true, :failonfail => false}
      Puppet::Util::Execution.execute(cmd, execute_options)
    end

    output.chomp!

    Puppet.debug "Autosign command '#{@path}' exit status: #{output.exitstatus}"
    Puppet.debug "Autosign command '#{@path}' output: #{output}"

    case output.exitstatus
    when 0
      true
    else
      false
    end
  end
end
