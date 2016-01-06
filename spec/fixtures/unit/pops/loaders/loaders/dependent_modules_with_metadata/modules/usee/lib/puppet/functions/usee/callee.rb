Puppet::Functions.create_function(:'usee::callee') do
  def callee(value)
    "usee::callee() was told '#{value}'"
  end
end
