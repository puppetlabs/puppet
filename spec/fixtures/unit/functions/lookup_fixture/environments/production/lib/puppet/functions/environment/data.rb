Puppet::Functions.create_function(:'environment::data') do
  def data()
    { 'abc::a' => 'env_a',
      'abc::c' => 'env_c',
      'abc::d' => { 'k1' => 'env_d1', 'k2' => 'env_d2', 'k3' => 'env_d3' },
      'abc::e' => { 'k1' => 'env_e1', 'k3' => 'env_e3' },
      'bca::e' => { 'k1' => 'env_bca_e1', 'k3' => 'env_bca_e3' },
      'no_provider::e' => { 'k1' => 'env_no_provider_e1', 'k3' => 'env_no_provider_e3' },
      'abc::f' => { 'k1' => { 's1' => 'env_f11', 's2' => 'env_f12' },  'k2' => { 's1' => 'env_f21', 's3' => 'env_f23' }},
      'abc::n' => nil
    }
  end
end
