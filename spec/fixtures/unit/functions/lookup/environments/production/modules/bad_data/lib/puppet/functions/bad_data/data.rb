Puppet::Functions.create_function(:'bad_data::data') do
  def data()
    { 'b' => 'module_b', # Intentionally bad key (no module prefix)
      'bad_data::c' => 'module_c' # Good key. Should be OK
    }
  end
end
