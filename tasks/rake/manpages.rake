# require 'fileutils'

desc "Build Puppet manpages"
task :gen_manpages do

  sbins = Dir.glob(%w{sbin/*})
  bins  = Dir.glob(%w{bin/*})
  applications  = Dir.glob(%w{lib/puppet/application/*})
  # Locate ronn
  ronn = %x{which ronn}.chomp
  unless File.executable?(ronn) then fail("Ronn does not appear to be installed.") end

  # Create puppet.conf.5 man page
  %x{RUBYLIB=./lib:$RUBYLIB bin/puppetdoc --reference configuration > ./man/man5/puppetconf.5.ronn}
  %x{#{ronn} --manual="Puppet manual" --organization="Puppet Labs, LLC" -r ./man/man5/puppetconf.5.ronn}
  File.move("./man/man5/puppetconf.5", "./man/man5/puppet.conf.5")
  File.unlink("./man/man5/puppetconf.5.ronn")

  # Create LEGACY binary man pages (i.e. delete me for 2.8.0)
  binary = bins + sbins
  binary.each do |bin|
    b = bin.gsub( /^s?bin\//, "")
    %x{RUBYLIB=./lib:$RUBYLIB #{bin} --help > ./man/man8/#{b}.8.ronn}
    %x{#{ronn} --manual="Puppet manual" --organization="Puppet Labs, LLC" -r ./man/man8/#{b}.8.ronn}
    File.unlink("./man/man8/#{b}.8.ronn")
  end

  # Create modern binary man pages
  applications.each do |app|
    app.gsub!( /^lib\/puppet\/application\/(.*?)\.rb/, '\1')
    %x{RUBYLIB=./lib:$RUBYLIB bin/puppet #{app} --help > ./man/man8/puppet-#{app}.8.ronn}
    %x{#{ronn} --manual="Puppet manual" --organization="Puppet Labs, LLC" -r ./man/man8/puppet-#{app}.8.ronn}
    File.unlink("./man/man8/puppet-#{app}.8.ronn")
  end


end