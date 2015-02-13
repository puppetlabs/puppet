Puppet::Functions.create_function(:'environment::data') do
  def data()
    { 'a' => 'env_a',
      'c' => 'env_c',
      'd' => { 'k1' => 'env_d1', 'k2' => 'env_d2', 'k3' => 'env_d3' },
      'e' => { 'k1' => 'env_e1', 'k3' => 'env_e3' },
      'f' => { 'k1' => { 's1' => 'env_f11', 's2' => 'env_f12' },  'k2' => { 's1' => 'env_f21', 's3' => 'env_f23' }},
    }
  end
end