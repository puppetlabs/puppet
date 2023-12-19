# frozen_string_literal: true

module Puppet
  module Util
    module Windows
      module String
        def wide_string(str)
          # if given a nil string, assume caller wants to pass a nil pointer to win32
          return nil if str.nil?

          str.encode('UTF-16LE')
        end
        module_function :wide_string
      end
    end
  end
end
