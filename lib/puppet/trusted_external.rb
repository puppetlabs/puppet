# frozen_string_literal: true

# A method for retrieving external trusted facts
module Puppet::TrustedExternal
  def retrieve(certname)
    command = Puppet[:trusted_external_command]
    return nil unless command

    Puppet.debug { _("Retrieving trusted external data from %{command}") % { command: command } }
    setting_type = Puppet.settings.setting(:trusted_external_command).type
    if setting_type == :file
      return fetch_data(command, certname)
    end

    # command is a directory. Thus, data is a hash of <basename> => <data> for
    # each executable file in command. For example, if the files 'servicenow.rb',
    # 'unicorn.sh' are in command, then data is the following hash:
    #   { 'servicenow' => <servicenow.rb output>, 'unicorn' => <unicorn.sh output> }
    data = {}
    Puppet::FileSystem.children(command).each do |file|
      abs_path = Puppet::FileSystem.expand_path(file)
      executable_file = Puppet::FileSystem.file?(abs_path) && Puppet::FileSystem.executable?(abs_path)
      unless executable_file
        Puppet.debug { _("Skipping non-executable file %{file}") % { file: abs_path } }
        next
      end
      basename = file.basename(file.extname).to_s
      unless data[basename].nil?
        raise Puppet::Error, _("There is more than one '%{basename}' script in %{dir}") % { basename: basename, dir: command }
      end

      data[basename] = fetch_data(abs_path, certname)
    end
    data
  end
  module_function :retrieve

  def fetch_data(command, certname)
    result = Puppet::Util::Execution.execute([command, certname], {
                                               :combine => false,
                                               :failonfail => true,
                                             })
    JSON.parse(result)
  end
  module_function :fetch_data
end
