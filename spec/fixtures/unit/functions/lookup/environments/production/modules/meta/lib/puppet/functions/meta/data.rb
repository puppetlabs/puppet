Puppet::Functions.create_function(:'meta::data') do
  def data()
    { 'meta::b' => 'module_b',
      'meta::c' => 'module_c',
      'meta::e' => { 'k1' => 'module_e1', 'k2' => 'module_e2' },
      'meta::f' => { 'k1' => { 's1' => 'module_f11', 's3' => 'module_f13' },  'k2' => { 's1' => 'module_f21', 's2' => 'module_f22' }},
    }
  end
end
