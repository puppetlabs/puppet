require 'spec/extensions'
require 'spec/version'
require 'spec/matchers'
require 'spec/expectations'
require 'spec/translator'
require 'spec/dsl'
require 'spec/runner'

class Object
  def metaclass
    class << self; self; end
  end
end
