require 'puppet/util/windows'

module Puppet::Util::Windows::File
  require 'windows/api'
  require 'windows/wide_string'

  ReplaceFileWithoutBackupW = Windows::API.new('ReplaceFileW', 'PPVLVV', 'B')
  def replace_file(target, source)
    result = ReplaceFileWithoutBackupW.call(WideString.new(target.to_s),
                                   WideString.new(source.to_s),
                                   0, 0x1, 0, 0)
    return true unless result == 0
    raise Puppet::Util::Windows::Error.new("ReplaceFile(#{target}, #{source})")
  end
  module_function :replace_file

  MoveFileEx = Windows::API.new('MoveFileExW', 'PPL', 'B')
  def move_file_ex(source, target, flags = 0)
    result = MoveFileEx.call(WideString.new(source.to_s),
                             WideString.new(target.to_s),
                             flags)
    return true unless result == 0
    raise Puppet::Util::Windows::Error.
      new("MoveFileEx(#{source}, #{target}, #{flags.to_s(8)})")
  end
  module_function :move_file_ex
end
