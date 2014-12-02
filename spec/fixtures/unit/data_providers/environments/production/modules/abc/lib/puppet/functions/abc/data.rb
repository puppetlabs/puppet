Puppet::Functions.create_function(:'abc::data') do
  def data()
    { 'abc::def::test1' => 'module_test1',
      'abc::def::test2' => 'module_test2',
      'abc::def::test3' => 'module_test3'
    }
  end
end
