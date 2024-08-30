desc "Build Puppet manpages"
task :gen_manpages do
  require 'puppet/face'
  require 'fileutils'

  Puppet.initialize_settings
  helpface = Puppet::Face[:help, '0.0.1']

  non_face_applications = helpface.legacy_applications
  faces = Puppet::Face.faces.map(&:to_s)
  apps = non_face_applications + faces

  ronn_args = '--manual="Puppet manual" --organization="Puppet, Inc." --roff'

  unless ENV['SOURCE_DATE_EPOCH'].nil?
    source_date = Time.at(ENV['SOURCE_DATE_EPOCH'].to_i).strftime('%Y-%m-%d')
    ronn_args += " --date=#{source_date}"
  end

  # Locate ronn
  begin
    require 'ronn'
  rescue LoadError
    abort("Run `bundle install --with documentation` to install the `ronn` gem.")
  end

  ronn = %x{which ronn}.chomp
  unless File.executable?(ronn)
    abort("Ronn does not appear to be installed")
  end

  %x{mkdir -p ./man/man5 ./man/man8}
  %x{RUBYLIB=./lib:$RUBYLIB bin/puppet doc --reference configuration > ./man/man5/puppetconf.5.ronn}
  %x{#{ronn} #{ronn_args} ./man/man5/puppetconf.5.ronn}
  FileUtils.mv("./man/man5/puppetconf.5", "./man/man5/puppet.conf.5")
  FileUtils.rm("./man/man5/puppetconf.5.ronn")

  # Create puppet binary man page
  # puppet --help outputs raw text, not ronn, so trying to convert that to roff
  # fails miserably. Render valid ronn so we can convert to roff
  common = helpface.common_app_summaries
  specialized = helpface.specialized_app_summaries
  template_binding = OpenStruct.new(common: common, specialized: specialized).instance_eval {binding}
  content = ERB.new(File.read(File.join(__dir__, 'man/puppet.erb')), trim_mode: '-').result(template_binding)
  File.write("./man/man8/puppet.8.ronn", content)
  %x{#{ronn} #{ronn_args} ./man/man8/puppet.8.ronn}
  FileUtils.rm("./man/man8/puppet.8.ronn")

  apps.each do |app|
    %x{RUBYLIB=./lib:$RUBYLIB bin/puppet help #{app} --ronn > ./man/man8/puppet-#{app}.8.ronn}
    %x{#{ronn} #{ronn_args} ./man/man8/puppet-#{app}.8.ronn}
    FileUtils.rm("./man/man8/puppet-#{app}.8.ronn")
  end

  # Delete orphaned manpages if binary was deleted
  Dir.glob(%w{./man/man8/puppet-*.8}) do |app|
    appname = app.match(/puppet-(.*)\.8/)[1]
    FileUtils.rm("./man/man8/puppet-#{appname}.8") unless apps.include?(appname)
  end

  # Vile hack: create puppet resource man page
  # Currently, the useless resource face wins against puppet resource in puppet
  # man. (And actually, it even gets removed from the list of legacy
  # applications.) So we overwrite it with the correct man page at the end.
  %x{RUBYLIB=./lib:$RUBYLIB bin/puppet resource --help > ./man/man8/puppet-resource.8.ronn}
  %x{#{ronn} #{ronn_args} ./man/man8/puppet-resource.8.ronn}
  FileUtils.rm("./man/man8/puppet-resource.8.ronn")

end
