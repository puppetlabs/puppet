test_name 'Searching for modules by part of the name'

module_name = "pmtacceptance-geordi"

expected_output  = <<-STDOUT
\e[mNotice: Searching https://forge.puppetlabs.com ...\e[0m
NAME                  DESCRIPTION                  AUTHOR          KEYWORDS     
%s  UNKNOWN                      @pmtacceptance  star trek    
STDOUT

step 'Setup'
stub_forge_on(master)

step 'Search for modules by partial name'
search_string = "geordi"
on master, puppet("module search #{search_string}") do
  em_module_name = module_name.gsub(/#{search_string}/, "\e[0;32m#{search_string}\e[0m")
  assert_equal '', stderr
  assert_equal expected_output % [em_module_name], stdout
end

step 'Search for modules by partial full name (dashed)'
search_string = "tance-ge"
on master, puppet("module search #{search_string}") do
  em_module_name = module_name.gsub(/#{search_string}/, "\e[0;32m#{search_string}\e[0m")
  assert_equal '', stderr
  assert_equal expected_output % [em_module_name], stdout
end

step 'Search for modules by partial full name (slashed)'
search_string = "tance/ge"
on master, puppet("module search #{search_string}") do
  search_string = search_string.gsub(/\//, "-")
  em_module_name = module_name.gsub(/#{search_string}/, "\e[0;32m#{search_string}\e[0m")
  assert_equal '', stderr
  assert_equal expected_output % [em_module_name], stdout
end
