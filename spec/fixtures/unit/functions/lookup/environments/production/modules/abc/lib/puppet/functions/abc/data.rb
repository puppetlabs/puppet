Puppet::Functions.create_function(:'abc::data') do
  def data()
    { 'b' => 'module_b',
      'c' => 'module_c',
      'e' => { 'k1' => 'module_e1', 'k2' => 'module_e2' },
      'f' => { 'k1' => { 's1' => 'module_f11', 's3' => 'module_f13' },  'k2' => { 's1' => 'module_f21', 's2' => 'module_f22' }},
    }
  end
end
