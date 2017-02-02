Puppet::Functions.create_function(:'bca::data') do
  def data()
    { 'bca::b' => 'module_bca_b',
      'bca::c' => 'module_bca_c',
      'bca::e' => { 'k1' => 'module_bca_e1', 'k2' => 'module_bca_e2' },
      'bca::f' => { 'k1' => { 's1' => 'module_bca_f11', 's3' => 'module_bca_f13' },  'k2' => { 's1' => 'module_bca_f21', 's2' => 'module_bca_f22' }},
    }
  end
end
