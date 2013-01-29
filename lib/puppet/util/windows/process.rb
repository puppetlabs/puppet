require 'puppet/util/windows'
require 'windows/process'
require 'windows/handle'
require 'windows/synchronize'

module Puppet::Util::Windows::Process
  extend ::Windows::Process
  extend ::Windows::Handle
  extend ::Windows::Synchronize

  def execute(command, arguments, stdin, stdout, stderr)
    Process.create( :command_line => command, :startup_info => {:stdin => stdin, :stdout => stdout, :stderr => stderr}, :close_handles => false )
  end
  module_function :execute

  def wait_process(handle)
    while WaitForSingleObject(handle, 0) == Windows::Synchronize::WAIT_TIMEOUT
      sleep(1)
    end

    exit_status = [0].pack('L')
    unless GetExitCodeProcess(handle, exit_status)
      raise Puppet::Util::Windows::Error.new("Failed to get child process exit code")
    end
    exit_status = exit_status.unpack('L').first

    # $CHILD_STATUS is not set when calling win32/process Process.create
    # and since it's read-only, we can't set it. But we can execute a
    # a shell that simply returns the desired exit status, which has the
    # desired effect.
    %x{#{ENV['COMSPEC']} /c exit #{exit_status}}

    exit_status
  end
  module_function :wait_process
end
