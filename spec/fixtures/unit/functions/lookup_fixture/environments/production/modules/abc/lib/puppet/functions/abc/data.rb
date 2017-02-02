Puppet::Functions.create_function(:'abc::data') do
  def data()
    { 'abc::b' => 'module_b',
      'abc::c' => 'module_c',
      'abc::e' => { 'k1' => 'module_e1', 'k2' => 'module_e2' },
      'abc::f' => { 'k1' => { 's1' => 'module_f11', 's3' => 'module_f13' },  'k2' => { 's1' => 'module_f21', 's2' => 'module_f22' }},
    }
  end
end
