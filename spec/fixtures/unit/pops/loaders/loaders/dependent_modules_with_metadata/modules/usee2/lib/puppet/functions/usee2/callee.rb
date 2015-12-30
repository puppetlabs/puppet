Puppet::Functions.create_function(:'usee2::callee') do
  def callee(value)
    "usee2::callee() was told '#{value}'"
  end
end
