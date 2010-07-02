unless defined? SPEC_HELPER_IS_LOADED
SPEC_HELPER_IS_LOADED = 1

dir = File.expand_path(File.dirname(__FILE__))

$LOAD_PATH.unshift("#{dir}/")
$LOAD_PATH.unshift("#{dir}/lib") # a spec-specific test lib dir
$LOAD_PATH.unshift("#{dir}/../lib")
$LOAD_PATH.unshift("#{dir}/../test/lib")  # Add the old test dir, so that we can still find our local mocha and spec

# include any gems in vendor/gems
Dir["#{dir}/../vendor/gems/**"].each do |path|
    libpath = File.join(path, "lib")
    if File.directory?(libpath)
        $LOAD_PATH.unshift(libpath)
    else
        $LOAD_PATH.unshift(path)
    end
end

require 'puppettest'
require 'puppettest/runnable_test'
require 'mocha'
gem 'rspec', '>=1.2.9'
require 'spec/autorun'

# So everyone else doesn't have to include this base constant.
module PuppetSpec
    FIXTURE_DIR = File.join(dir = File.expand_path(File.dirname(__FILE__)), "fixtures") unless defined?(FIXTURE_DIR)
end

# load any monkey-patches
Dir["#{dir}/monkey_patches/*.rb"].map { |file| require file }

Spec::Runner.configure do |config|
    config.mock_with :mocha

#  config.prepend_before :all do
#      setup_mocks_for_rspec
#      setup() if respond_to? :setup
#  end
#
    config.prepend_after :each do
        Puppet.settings.clear
        Puppet::Node::Environment.clear
        Puppet::Util::Storage.clear

        if defined?($tmpfiles)
            $tmpfiles.each do |file|
                file = File.expand_path(file)
                if Puppet.features.posix? and file !~ /^\/tmp/ and file !~ /^\/var\/folders/
                    puts "Not deleting tmpfile #{file} outside of /tmp or /var/folders"
                    next
                elsif Puppet.features.win32? 
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
    end

    config.prepend_before :each do
        # these globals are set by Application
        $puppet_application_mode = nil
        $puppet_application_name = nil

        # Set the confdir and vardir to gibberish so that tests
        # have to be correctly mocked.
        Puppet[:confdir] = "/dev/null"
        Puppet[:vardir] = "/dev/null"

        # Avoid opening ports to the outside world
        Puppet.settings[:bindaddress] = "127.0.0.1"
    end
end

# We need this because the RAL uses 'should' as a method.  This
# allows us the same behaviour but with a different method name.
class Object
    alias :must :should
end

end
