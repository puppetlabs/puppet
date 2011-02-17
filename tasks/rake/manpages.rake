# require 'fileutils'

desc "Build Puppet manpages"
task :gen_manpages do

  sbins = Dir.glob(%w{sbin/*})
  bins  = Dir.glob(%w{bin/*})
  
  # Locate ronn
  ronn = %x{which ronn}
  ronn.chomp!
  # Create puppet.conf.5 man page
  %x{RUBYLIB=./lib:$RUBYLIB bin/puppetdoc --reference configuration > ./man/man5/puppetconf.5.ronn}
  %x{#{ronn} --manual="Puppet manual" --organization="Puppet Labs, LLC" -r ./man/man5/puppetconf.5.ronn}
  File.move("./man/man5/puppetconf.5", "./man/man5/puppet.conf.5")
  File.unlink("./man/man5/puppetconf.5.ronn")

  # Create binary man pages
  binary = bins + sbins
  binary.each do |bin|
    b = bin.gsub( /(bin|sbin)\//, "")
    %x{RUBYLIB=./lib:$RUBYLIB #{bin} --help > ./man/man8/#{b}.8.ronn}
    %x{#{ronn} --manual="Puppet manual" --organization="Puppet Labs, LLC" -r ./man/man8/#{b}.8.ronn}
    File.unlink("./man/man8/#{b}.8.ronn")
  end
  
end