#! /usr/bin/env ruby
require 'spec_helper'

provider_class = Puppet::Type.type(:package).provider(:gem)

describe provider_class do
  let(:resource) do
    Puppet::Type.type(:package).new(
      :name     => 'myresource',
      :making_sure   => :installed
    )
  end

  let(:provider) do
    provider = provider_class.new
    provider.resource = resource
    provider
  end

  describe "when installing" do
    it "should use the path to the gem" do
      provider_class.stubs(:command).with(:gemcmd).returns "/my/gem"
      provider.expects(:execute).with { |args| args[0] == "/my/gem" }.returns ""
      provider.install
    end

    it "should specify that the gem is being installed" do
      provider.expects(:execute).with { |args| args[1] == "install" }.returns ""
      provider.install
    end

    it "should specify that documentation should not be included" do
      provider.expects(:execute).with { |args| args[2] == "--no-rdoc" }.returns ""
      provider.install
    end

    it "should specify that RI should not be included" do
      provider.expects(:execute).with { |args| args[3] == "--no-ri" }.returns ""
      provider.install
    end

    it "should specify the package name" do
      provider.expects(:execute).with { |args| args[4] == "myresource" }.returns ""
      provider.install
    end

    describe "when a source is specified" do
      describe "as a normal file" do
        it "should use the file name instead of the gem name" do
          resource[:source] = "/my/file"
          provider.expects(:execute).with { |args| args[2] == "/my/file" }.returns ""
          provider.install
        end
      end
      describe "as a file url" do
        it "should use the file name instead of the gem name" do
          resource[:source] = "file:///my/file"
          provider.expects(:execute).with { |args| args[2] == "/my/file" }.returns ""
          provider.install
        end
      end
      describe "as a puppet url" do
        it "should fail" do
          resource[:source] = "puppet://my/file"
          lambda { provider.install }.should raise_error(Puppet::Error)
        end
      end
      describe "as a non-file and non-puppet url" do
        it "should treat the source as a gem repository" do
          resource[:source] = "http://host/my/file"
          provider.expects(:execute).with { |args| args[2..4] == ["--source", "http://host/my/file", "myresource"] }.returns ""
          provider.install
        end
      end
      describe "with an invalid uri" do
        it "should fail" do
          URI.expects(:parse).raises(ArgumentError)
          resource[:source] = "http:::::uppet:/:/my/file"
          lambda { provider.install }.should raise_error(Puppet::Error)
        end
      end
    end
  end

  describe "#latest" do
    it "should return a single value for 'latest'" do
      #gemlist is used for retrieving both local and remote version numbers, and there are cases
      # (particularly local) where it makes sense for it to return an array.  That doesn't make
      # sense for '#latest', though.
      provider.class.expects(:gemlist).with({ :justme => 'myresource'}).returns({
          :name     => 'myresource',
          :making_sure   => ["3.0"],
          :provider => :gem,
          })
      provider.latest.should == "3.0"
    end

    it "should list from the specified source repository" do
      resource[:source] = "http://foo.bar.baz/gems"
      provider.class.expects(:gemlist).
        with({:justme => 'myresource', :source => "http://foo.bar.baz/gems"}).
        returns({
          :name     => 'myresource',
          :making_sure   => ["3.0"],
          :provider => :gem,
          })
      provider.latest.should == "3.0"
    end
  end

  describe "#instances" do
    before do
      provider_class.stubs(:command).with(:gemcmd).returns "/my/gem"
    end

    it "should return an empty array when no gems installed" do
      provider_class.expects(:execute).with(%w{/my/gem list --local}).returns("\n")
      provider_class.instances.should == []
    end

    it "should return making_sure values as an array of installed versions" do
      provider_class.expects(:execute).with(%w{/my/gem list --local}).returns <<-HEREDOC.gsub(/        /, '')
        systemu (1.2.0)
        vagrant (0.8.7, 0.6.9)
      HEREDOC

      provider_class.instances.map {|p| p.properties}.should == [
        {:making_sure => ["1.2.0"],          :provider => :gem, :name => 'systemu'},
        {:making_sure => ["0.8.7", "0.6.9"], :provider => :gem, :name => 'vagrant'}
      ]
    end

    it "should ignore platform specifications" do
      provider_class.expects(:execute).with(%w{/my/gem list --local}).returns <<-HEREDOC.gsub(/        /, '')
        systemu (1.2.0)
        nokogiri (1.6.1 ruby java x86-mingw32 x86-mswin32-60, 1.4.4.1 x86-mswin32)
      HEREDOC

      provider_class.instances.map {|p| p.properties}.should == [
        {:making_sure => ["1.2.0"],          :provider => :gem, :name => 'systemu'},
        {:making_sure => ["1.6.1", "1.4.4.1"], :provider => :gem, :name => 'nokogiri'}
      ]
    end

    it "should not fail when an unmatched line is returned" do
      provider_class.expects(:execute).with(%w{/my/gem list --local}).
        returns(File.read(my_fixture('line-with-1.8.5-warning')))

      provider_class.instances.map {|p| p.properties}.
        should == [{:provider=>:gem, :making_sure=>["0.3.2"], :name=>"columnize"},
                   {:provider=>:gem, :making_sure=>["1.1.3"], :name=>"diff-lcs"},
                   {:provider=>:gem, :making_sure=>["0.0.1"], :name=>"metaclass"},
                   {:provider=>:gem, :making_sure=>["0.10.5"], :name=>"mocha"},
                   {:provider=>:gem, :making_sure=>["0.8.7"], :name=>"rake"},
                   {:provider=>:gem, :making_sure=>["2.9.0"], :name=>"rspec-core"},
                   {:provider=>:gem, :making_sure=>["2.9.1"], :name=>"rspec-expectations"},
                   {:provider=>:gem, :making_sure=>["2.9.0"], :name=>"rspec-mocks"},
                   {:provider=>:gem, :making_sure=>["0.9.0"], :name=>"rubygems-bundler"},
                   {:provider=>:gem, :making_sure=>["1.11.3.3"], :name=>"rvm"}]
    end
  end
end
