Puppet::Functions.create_function(:'environment::data') do
  def data()
    { 'abc::def::test1' => 'env_test1',
      'abc::def::test2' => 'env_test2',
      'xyz::def::test1' => 'env_test1',
      'xyz::def::test2' => 'env_test2'
    }
  end
end