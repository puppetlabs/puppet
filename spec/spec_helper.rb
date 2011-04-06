require 'pathname'
dir = Pathname.new(__FILE__).parent
$LOAD_PATH.unshift(dir, dir + 'lib', dir + '../lib')

require 'mocha'
require 'puppet'
require 'puppet/string'
require 'rspec'

Pathname.glob("#{dir}/shared_behaviours/**/*.rb") do |behaviour|
  require behaviour.relative_path_from(dir)
end

RSpec.configure do |config|
  config.mock_with :mocha

  config.before :each do
    # Set the confdir and vardir to gibberish so that tests
    # have to be correctly mocked.
    Puppet[:confdir] = "/dev/null"
    Puppet[:vardir] = "/dev/null"

    # Avoid opening ports to the outside world
    Puppet.settings[:bindaddress] = "127.0.0.1"

    @logs = []
    Puppet::Util::Log.newdestination(@logs)

    @load_path_scratch_dir = Dir.mktmpdir
    $LOAD_PATH.push @load_path_scratch_dir
    FileUtils.mkdir_p(File.join @load_path_scratch_dir, 'puppet', 'string')
  end

  config.after :each do
    Puppet.settings.clear

    @logs.clear
    Puppet::Util::Log.close_all

    $LOAD_PATH.delete @load_path_scratch_dir
    FileUtils.remove_entry_secure @load_path_scratch_dir
  end

  def write_scratch_string(name)
    fail "you need to supply a block: do |fh| fh.puts 'content' end" unless block_given?
    fail "name should be a symbol" unless name.is_a? Symbol
    filename = File.join(@load_path_scratch_dir, 'puppet', 'string', "#{name}.rb")
    File.open(filename, 'w') do |fh|
      yield fh
    end
  end
end

# We need this because the RAL uses 'should' as a method.  This
# allows us the same behaviour but with a different method name.
class Object
  alias :must :should
end
