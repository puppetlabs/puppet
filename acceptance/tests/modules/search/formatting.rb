test_name 'puppet module search output should be well structured'

step 'Search for a common module'
on master, puppet("module search apache") do
  assert_equal('', stderr)

  columns = stdout.lines.first.split(/\s{2}(?=\S)/)
  pattern = /^#{ columns.map { |c| c.chomp.gsub(/./, '.') }.join('  ') }$/

  stdout.lines.each do |line|
    assert_match(pattern, line.chomp, 'columns were misaligned')
  end
end
