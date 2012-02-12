begin test_name 'puppet module search output should be well structured'

step 'Stub http://forge.puppetlabs.com'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.com')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"

step 'Search results should line up by column'
on master, puppet("module search apache") do
  assert_equal('', stderr)

  assert_equal "Searching http://forge.puppetlabs.com ...\n", stdout.lines.first
  columns = stdout.lines.to_a[1].split(/\s{2}(?=\S)/)
  pattern = /^#{ columns.map { |c| c.chomp.gsub(/./, '.') }.join('  ') }$/

  stdout.lines.to_a[1..-1].each do |line|
    assert_match(pattern, line.chomp, 'columns were misaligned')
  end
end

ensure step 'Unstub http://forge.puppetlabs.com'
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
end
