module Puppet::Util::Windows
  # This module is a helper to create a string that performs an action from powershell
  # and returns the exit code to puppet when used with Puppet::Util::Execution.execute
  module PowershellCommandString

    DEFAULT_POWERSHELL_ARGS = '-ExecutionPolicy Bypass -InputFormat None -NoLogo -NoProfile -NonInteractive'
    DEFAULT_START_PROCESS_ARGS = '-NoNewWindow -Wait'

    # Construct a command string that can be used with Util::Execution::execute to call to powershell to execute a command.
    # The general construction of the command is:
    #
    # powershell.exe -Command exit (Start-Process -PassThru command).ExitCode
    #
    # We call from powershell to the 'exit' command that will call to Start-Process "command" to get "command"s exit code
    # so that when powershell exits it will exit with the same exit code.
    def self.make_powershell_command(command, arguments: [], powershell_args: DEFAULT_POWERSHELL_ARGS, start_process_args: DEFAULT_START_PROCESS_ARGS)
      parsed_args = parse_arguments(arguments)
      unless parsed_args.empty?
        argument_string = '-ArgumentList \'' + parsed_args + '\''
      end
      [
        'powershell.exe',
        powershell_args,
        '-Command',
        'exit',
        '(',
        'Start-Process',
        '-PassThru', # We always use -PassThru so .ExitCode recieves the code from "command"
        start_process_args,
        '-FilePath',
        command,
        argument_string,
        ').ExitCode',
      ].flatten.compact.join(' ')
    end

    def self.parse_arguments(args)
      return '' if args.nil?
      args.compact.delete_if { |arg| arg.empty? }.flatten.join(' ')
    end
  end
end
