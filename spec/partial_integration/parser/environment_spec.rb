require 'spec_helper'

describe "A parser environment setting" do

  let(:confdir) { Puppet[:confdir] }
  let(:environmentpath) { File.expand_path("envdir", confdir) }
  let(:testingdir) { File.join(environmentpath, "testing") }

  before(:each) do
    FileUtils.mkdir_p(testingdir)
  end

  it "selects the given parser when compiling" do
    manifestsdir = File.expand_path("manifests", confdir)
    FileUtils.mkdir_p(manifestsdir)

    File.open(File.join(testingdir, "environment.conf"), "w") do |f|
      f.puts(<<-ENVCONF)
        parser='future'
        manifest =#{manifestsdir}
      ENVCONF
    end

    File.open(File.join(confdir, "puppet.conf"), "w") do |f|
      f.puts(<<-EOF)
          environmentpath=#{environmentpath}
          parser='current'
      EOF
    end

    File.open(File.join(manifestsdir, "site.pp"), "w") do |f|
      f.puts("notice( [1,2,3].map |$x| { $x*10 })")
    end

    expect { a_catalog_compiled_for_environment('testing') }.to_not raise_error
  end

  def a_catalog_compiled_for_environment(envname)
    Puppet.initialize_settings
    expect(Puppet[:environmentpath]).to eq(environmentpath)
    node = Puppet::Node.new('testnode', :environment => 'testing')
    expect(node.environment).to eq(Puppet.lookup(:environments).get('testing'))
    Puppet.override(:current_environment => Puppet.lookup(:environments).get('testing')) do
      Puppet::Parser::Compiler.compile(node)
    end
  end
end
