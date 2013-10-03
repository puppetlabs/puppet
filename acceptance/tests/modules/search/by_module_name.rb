test_name 'Searching for modules by part of the name'

module_name = "pmtacceptance-geordi"

expected_output  = <<-STDOUT
\e[mNotice: Searching https://forge.puppetlabs.com ...\e[0m
NAME                  DESCRIPTION                  AUTHOR          KEYWORDS     
%s  UNKNOWN                      @pmtacceptance  star trek    
STDOUT

step 'Setup'
stub_forge_on(master)

search_types = { 'Search for modules by partial name'                   => "geordi",
                 'Search for modules by partial full name (dashed)'     => "tance-ge",
                 'Search for modules by partial full name (slashed)'    => "tance/ge",
               }

search_types.each do |type, search_string|
  step type
  on master, puppet("module search #{search_string}") do
    search_string = search_string.gsub(/\//, "-")
    em_module_name = module_name.gsub(/#{search_string}/, "\e[0;32m#{search_string}\e[0m")
    assert_equal '', stderr
    assert_equal expected_output % [em_module_name], stdout
  end
end
