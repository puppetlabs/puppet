unless defined?(SPEC_HELPER_IS_LOADED)
SPEC_HELPER_IS_LOADED = 1

dir = File.expand_path(File.dirname(__FILE__))

$LOAD_PATH.unshift("#{dir}/")
$LOAD_PATH.unshift("#{dir}/lib") # a spec-specific test lib dir
$LOAD_PATH.unshift("#{dir}/../lib")
$LOAD_PATH.unshift("#{dir}/../test/lib")

# Don't want puppet getting the command line arguments for rake or autotest
ARGV.clear

require 'puppet'
require 'mocha'
gem 'rspec', '>=2.0.0'

# So everyone else doesn't have to include this base constant.
module PuppetSpec
  FIXTURE_DIR = File.join(dir = File.expand_path(File.dirname(__FILE__)), "fixtures") unless defined?(FIXTURE_DIR)
end

module PuppetTest
end

require 'pathname'
require 'lib/puppet_spec/verbose'
require 'lib/puppet_spec/files'
require 'monkey_patches/alias_should_to_must'
require 'monkey_patches/publicize_methods'

Pathname.glob("#{dir}/shared_behaviours/**/*.rb") do |behaviour|
  require behaviour.relative_path_from(Pathname.new(dir))
end

RSpec.configure do |config|
  config.mock_with :mocha

  config.after :each do
    Puppet.settings.clear
    Puppet::Node::Environment.clear
    Puppet::Util::Storage.clear
    Puppet::Util::ExecutionStub.reset

    if defined?($tmpfiles)
      $tmpfiles.each do |file|
        file = File.expand_path(file)
        if Puppet.features.posix? and file !~ /^\/tmp/ and file !~ /^\/var\/folders/
          puts "Not deleting tmpfile #{file} outside of /tmp or /var/folders"
          next
        elsif Puppet.features.microsoft_windows?
          tempdir = File.expand_path(File.join(Dir::LOCAL_APPDATA, "Temp"))
          if file !~ /^#{tempdir}/
            puts "Not deleting tmpfile #{file} outside of #{tempdir}"
            next
          end
        end
        if FileTest.exist?(file)
          system("chmod -R 755 '#{file}'")
          system("rm -rf '#{file}'")
        end
      end
      $tmpfiles.clear
    end

    @logs.clear
    Puppet::Util::Log.close_all
  end

  config.before :each do
    # these globals are set by Application
    $puppet_application_mode = nil
    $puppet_application_name = nil
    Signal.stubs(:trap)

    # Set the confdir and vardir to gibberish so that tests
    # have to be correctly mocked.
    Puppet[:confdir] = "/dev/null"
    Puppet[:vardir] = "/dev/null"

    # Avoid opening ports to the outside world
    Puppet.settings[:bindaddress] = "127.0.0.1"

    @logs = []
    Puppet::Util::Log.newdestination(@logs)
  end
end

end
