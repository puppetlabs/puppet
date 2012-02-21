require 'json'
Dir.glob("/etc/puppet/modules/*").each do |dir|
  m = JSON.parse(File.open("/etc/puppet/modules/#{dir}/metadata.json").read)
  puts "#{m['name']} #{m['version']}"
end
