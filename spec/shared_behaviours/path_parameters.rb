# In order to use this correctly you must define a method to get an instance
# of the type being tested, so that this code can remain generic:
#
#    it_should_behave_like "all path parameters", :path do
#      def instance(path)
#        Puppet::Type.type(:example).new(
#          :name => 'foo', :require => 'bar', :path_param => path
#        )
#      end
#
# That method will be invoked for each test to create the instance that we
# subsequently test through the system; you should ensure that the minimum of
# possible attributes are set to keep the tests clean.
#
# You must also pass the symbolic name of the parameter being tested to the
# block, and optionally can pass a hash of additional options to the block.
#
# The known options are:
#  :array :: boolean, does this support arrays of paths, default true.

shared_examples_for "all pathname parameters with arrays" do |win32|
  path_types = {
    "unix absolute"            => %q{/foo/bar},
    "unix relative"            => %q{foo/bar},
    "win32 non-drive absolute" => %q{\foo\bar},
    "win32 non-drive relative" => %q{foo\bar},
    "win32 drive absolute"     => %q{c:\foo\bar},
    "win32 drive relative"     => %q{c:foo\bar}
  }

  describe "when given an array of paths" do
    (1..path_types.length).each do |n|
      path_types.keys.combination(n) do |set|
        data = path_types.collect { |k, v| set.member?(k) ? v : nil } .compact

        has_relative = set.find { |k| k =~ /relative/ or k =~ /non-drive/ }
        has_windows = set.find { |k| k =~ /win32/ }
        has_unix = set.find { |k| k =~ /unix/ }

        if has_relative or (has_windows and !win32) or (has_unix and win32)
          reject = true
        else
          reject = false
        end

        it "should #{reject ? 'reject' : 'accept'} #{set.join(", ")}" do
          if reject then
            expect { instance(data) }.
              to raise_error Puppet::Error, /fully qualified/
          else
            instance = instance(data)
            expect(instance[@param]).to eq(data)
          end
        end

        it "should #{reject ? 'reject' : 'accept'} #{set.join(", ")} doubled" do
          if reject then
            expect { instance(data + data) }.
              to raise_error Puppet::Error, /fully qualified/
          else
            instance = instance(data + data)
            expect(instance[@param]).to eq(data + data)
          end
        end
      end
    end
  end
end


shared_examples_for "all path parameters" do |param, options|
  # Extract and process options to the block.
  options ||= {}
  array = options[:array].nil? ? true : options.delete(:array)
  if options.keys.length > 0 then
    fail "unknown options for 'all path parameters': " +
      options.keys.sort.join(', ')
  end

  def instance(path)
    fail "we didn't implement the 'instance(path)' method in the it_should_behave_like block"
  end

  ########################################################################
  # The actual testing code...
  before :all do
    @param = param
  end

  describe "on a Unix-like platform it", :if => Puppet.features.posix? do
    if array then
      it_should_behave_like "all pathname parameters with arrays", false
    end

    it "should accept a fully qualified path" do
      path = File.join('', 'foo')
      instance = instance(path)
      expect(instance[@param]).to eq(path)
    end

    it "should give a useful error when the path is not absolute" do
      path = 'foo'
      expect { instance(path) }.
        to raise_error Puppet::Error, /fully qualified/
    end

    { "Unix" => '/', "Win32" => '\\' }.each do |style, slash|
      %w{q Q a A z Z c C}.sort.each do |drive|
        it "should reject drive letter '#{drive}' with #{style} path separators" do
          path = "#{drive}:#{slash}Program Files"
          expect { instance(path) }.
            to raise_error Puppet::Error, /fully qualified/
        end
      end
    end
  end

  describe "on a Windows-like platform it", :if => Puppet.features.microsoft_windows? do
    if array then
      it_should_behave_like "all pathname parameters with arrays", true
    end

    it "should reject a fully qualified unix path" do
      path = '/foo'
      expect { instance(path) }.to raise_error(Puppet::Error, /fully qualified/)
    end

    it "should give a useful error when the path is not absolute" do
      path = 'foo'
      expect { instance(path) }.
        to raise_error Puppet::Error, /fully qualified/
    end

    it "also accepts Unix style path separators" do
      path = 'C:/Program Files'
      instance = instance(path)
      expect(instance[@param]).to eq(path)
    end

    { "Unix" => '/', "Win32" => '\\' }.each do |style, slash|
      %w{q Q a A z Z c C}.sort.each do |drive|
        it "should accept drive letter '#{drive}' with #{style} path separators " do
          path = "#{drive}:#{slash}Program Files"
          instance = instance(path)
          expect(instance[@param]).to eq(path)
        end
      end
    end

    { "UNC paths"            => %q{\\\\foo\bar},
      "unparsed local paths" => %q{\\\\?\c:\foo},
      "unparsed UNC paths"   => %q{\\\\?\foo\bar}
    }.each do |name, path|
      it "should accept #{name} as absolute" do
        instance = instance(path)
        expect(instance[@param]).to eq(path)
      end
    end
  end
end
