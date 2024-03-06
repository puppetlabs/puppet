# frozen_string_literal: true

require_relative '../../../puppet/transaction/report'
require_relative '../../../puppet/indirector/json'

class Puppet::Transaction::Report::Json < Puppet::Indirector::JSON
  include Puppet::Util::SymbolicFileMode

  desc "Store last report as a flat file, serialized using JSON."

  # Force report to be saved there
  def path(name, ext = '.json')
    Puppet[:lastrunreport]
  end

  def save(request)
    filename = path(request.key)
    mode = Puppet.settings.setting(:lastrunreport).mode

    unless valid_symbolic_mode?(mode)
      raise Puppet::DevError, _("replace_file mode: %{mode} is invalid") % { mode: mode }
    end

    mode = symbolic_mode_to_int(normalize_symbolic_mode(mode))

    FileUtils.mkdir_p(File.dirname(filename))

    begin
      Puppet::FileSystem.replace_file(filename, mode) do |fh|
        fh.print JSON.dump(request.instance)
      end
    rescue TypeError => detail
      Puppet.err _("Could not save %{indirection} %{request}: %{detail}") % { indirection: name, request: request.key, detail: detail }
    end
  end
end
