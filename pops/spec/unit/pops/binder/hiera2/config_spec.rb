require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/pops'

# A Backend class that doesn't implement the needed API
class Puppet::Pops::Binder::Hiera2::Bad_backend
end

describe 'The hiera2 config' do

  include PuppetSpec::Pops

  let(:acceptor) {  Puppet::Pops::Validation::Acceptor.new() }
  let(:diag) {  Puppet::Pops::Binder::Hiera2::DiagnosticProducer.new(acceptor) }

  def config_dir(config_name)
    File.dirname(my_fixture("#{config_name}/hiera.yaml"))
  end

  def test_config_issue(config_name, issue)
    Puppet::Pops::Binder::Hiera2::Config.new(config_dir(config_name), diag)
    acceptor.should have_issue(issue)
  end

  it 'should load and validate OK configuration' do
    Puppet::Pops::Binder::Hiera2::Config.new(config_dir('ok'), diag)
    acceptor.errors_or_warnings?.should() == false
  end

  it 'should report missing config file' do
    Puppet::Pops::Binder::Hiera2::Config.new(File.dirname(my_fixture('missing/foo.txt')), diag)
    acceptor.should have_issue(Puppet::Pops::Binder::Hiera2::Issues::CONFIG_FILE_NOT_FOUND)
  end

  it 'should report when config is not a hash' do
    test_config_issue('not_a_hash', Puppet::Pops::Binder::Hiera2::Issues::CONFIG_IS_NOT_HASH)
  end

  it 'should report when config has syntax problems' do
    if RUBY_VERSION.start_with?("1.8")
      # Yes, it is a lobotomy or 2 short of a full brain...
      # if a hash key is not in quotes it continues on the next line and gobbles what is there instead
      # of reporting an error
      test_config_issue('bad_syntax', Puppet::Pops::Binder::Hiera2::Issues::MISSING_HIERARCHY)
    else
      test_config_issue('bad_syntax', Puppet::Pops::Binder::Hiera2::Issues::CONFIG_FILE_SYNTAX_ERROR)
    end
  end

  it 'should report when config has no hierarchy defined' do
    test_config_issue('no_hierarchy', Puppet::Pops::Binder::Hiera2::Issues::MISSING_HIERARCHY)
  end

  it 'should report when config has no backends defined' do
    test_config_issue('no_backends', Puppet::Pops::Binder::Hiera2::Issues::MISSING_BACKENDS)
  end

  it 'should report when config hierarchy is malformed' do
    test_config_issue('malformed_hierarchy', Puppet::Pops::Binder::Hiera2::Issues::CATEGORY_MUST_BE_THREE_ELEMENT_ARRAY)
  end
end
