require File.join(File.dirname(__FILE__),'../../acceptance_spec_helper.rb')
require 'puppet/acceptance/git_utils'

describe 'GitUtils' do
  include Puppet::Acceptance::GitUtils

  def with_env(vars)
    saved = {}
    vars.each do |k,v|
      saved[k] = ENV[k] if ENV[k]
      ENV[k] = v
    end
    yield
  ensure
    vars.keys.each do |k|
      saved.include?(k) ?
        ENV[k] = saved[k] :
        ENV.delete(k)
    end
  end

  it "looks up an env variable" do
    with_env('VAR' => 'from-var') do
      expect(lookup_in_env('VAR', 'foo', 'default')).to eq('from-var')
    end
  end

  it "looks up an env variable and submits default if none found" do
    expect(lookup_in_env('VAR', 'foo', 'default')).to eq('default')
  end

  it "prefers a project prefixed env variable" do
    with_env('VAR' => 'from-var',
             'FOO_BAR_VAR' => 'from-foo-bar-var') do
      expect(lookup_in_env('VAR', 'foo-bar', 'default')).to eq('from-foo-bar-var')
    end
  end

  it "builds a default git url for a project" do
    expect(build_giturl('foo')).to eq('git://github.com/puppetlabs/foo.git')
  end

  it "builds a git url from passed parameters" do
    expect(build_giturl('foo', 'somefork', 'someserver')).to eq('git://someserver/somefork-foo.git')
  end

  it "builds a git url based on env variables" do
    with_env('GIT_SERVER' => 'gitmirror',
             'FORK' => 'fork') do
      expect(build_giturl('foo')).to eq('git://gitmirror/fork-foo.git')
    end
  end

  it "builds a git url based on project specific env variables" do
    with_env('GIT_SERVER' => 'gitmirror',
             'FORK' => 'fork',
             'FOO_GIT_SERVER' => 'project.gitmirror',
             'FOO_FORK' => 'project-fork') do
      expect(build_giturl('foo')).to eq('git://project.gitmirror/project-fork-foo.git')
    end
  end
end
