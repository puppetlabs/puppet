require 'puppet/util/instrumentation/process_name'

module Puppet::Util::Instrumentation

  def instrument(title)
    Puppet::Util::Instrumentation::ProcessName.instrument(title) do
      yield
    end
  end
  module_function :instrument

end