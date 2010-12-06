#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../lib/puppettest')

require 'puppettest'
require 'etc'

class TestPackageProvider < Test::Unit::TestCase
  include PuppetTest

  def setup
    super
    Puppet.info @method_name
  end

  # Load the testpackages hash.
  def self.load_test_packages
    require 'yaml'
    file = File.join(PuppetTest.datadir, "providers", "package", "testpackages.yaml")
    raise "Could not find file #{file}" unless FileTest.exists?(file)
    array = YAML::load(File.read(file)).collect { |hash|
      # Stupid ruby 1.8.1.  YAML is sometimes broken such that
      # symbols end up being strings with the : in them.
      hash.each do |name, value|
        if name.is_a?(String) and name =~ /^:/
          hash.delete(name)
          name = name.sub(/^:/, '').intern
          hash[name] = value
        end
        if value.is_a?(String) and value =~ /^:/
          hash[name] = value.sub(/^:/, '').intern
        end
      end
    }

    array
  end

  def self.suitable_test_packages
    list = load_test_packages
    providers = {}
    Puppet::Type.type(:package).suitableprovider.each do |provider|
      providers[provider.name] = provider
    end
    facts = {}
    Facter.to_hash.each do |fact, value|
      facts[fact.to_s.downcase.intern] = value.to_s.downcase.intern
    end
    list.find_all { |hash| # First find the matching providers
      hash.include?(:provider) and providers.include?(hash[:provider])
    }.reject { |hash| # Then find matching fact sets
      facts.detect do |fact, value|
        # We're detecting unmatched facts, but we also want to
        # delete the facts so they don't show up later.
        if fval = hash[fact]
          hash.delete(fact)
          fval = [fval] unless fval.is_a?(Array)
          fval = fval.collect { |v| v.downcase.intern }
          ! fval.include?(value)
        end
      end
    }
  end

  def assert_absent(provider, msg = "package not absent")
    result = nil
    assert_nothing_raised("Could not query provider") do
      result = provider.query
    end
    if result.nil?
      assert_nil(result)
    elsif result.is_a?(Hash)
      assert (result[:ensure] == :absent or result[:ensure] == :purged), msg
    else
      raise "dunno how to handle #{result.inspect}"
    end
  end

  def assert_not_absent(provider, msg = "package not installed")
    result = nil
    assert_nothing_raised("Could not query provider") do
      result = provider.query
    end
    assert((result == :listed or result.is_a?(Hash)), "query did not return hash or :listed")
    if result == :listed
      assert(provider.resource.is(:ensure) != :absent, msg)
    else
      assert(result[:ensure] != :absent, msg)
    end
  end

  # Run a package through all of its paces.  FIXME This should use the
  # provider, not the package, duh.
  def run_package_installation_test(hash)
    # Turn the hash into a package
    if files = hash[:files]
      hash.delete(:files)
      if files.is_a?(Array)
        hash[:source] = files.shift
      else
        hash[:source] = files
        files = []
      end
    else
      files = []
    end

    if versions = hash[:versions]
      hash.delete(:versions)
    else
      versions = []
    end

    # Start out by just making sure it's installed
    if versions.empty?
      hash[:ensure] = :present
    else
      hash[:ensure] = versions.shift
    end

    if hash[:source]
      unless FileTest.exists?(hash[:source])
        $stderr.puts "Create a package at #{hash[:source]} for testing"
        return
      end
    end

    if cleancmd = hash[:cleanup]
      hash.delete(:cleanup)
    end

    pkg = nil
    assert_nothing_raised(
      "Could not turn #{hash.inspect} into a package"
    ) do
      pkg = Puppet::Type.newpackage(hash)
    end

    # Make any necessary modifications.
    modpkg(pkg)

    provider = pkg.provider

    assert(provider, "Could not retrieve provider")

    return if result = provider.query and ! [:absent, :purged].include?(result[:ensure])

    assert_absent(provider)

    if Process.uid != 0
      Puppet.info "Run as root for full package tests"
      return
    end

    cleanup do
      if pkg.provider.respond_to?(:uninstall)
        pkg.provider.flush
        if pkg.provider.properties[:ensure] != :absent
          assert_nothing_raised("Could not clean up package") do
            pkg.provider.uninstall
          end
        end
      else
        system(cleancmd) if cleancmd
      end
    end

    # Now call 'latest' after the package is installed
    if provider.respond_to?(:latest)
      assert_nothing_raised("Could not call 'latest'") do
        provider.latest
      end
    end

    assert_nothing_raised("Could not install package") do
      provider.install
    end

    assert_not_absent(provider, "package did not install")

    # If there are any remaining files, then test upgrading from there
    unless files.empty?
      pkg[:source] = files.shift
      current = provider.properties
      assert_nothing_raised("Could not upgrade") do
        provider.update
      end
      provider.flush
      new = provider.properties
      assert(current != new, "package was not upgraded: #{current.inspect} did not change")
    end

    unless versions.empty?
      pkg[:ensure] = versions.shift
      current = provider.properties
      assert_nothing_raised("Could not upgrade") do
        provider.update
      end
      provider.flush
      new = provider.properties
      assert(current != new, "package was not upgraded: #{current.inspect} did not change")
    end

    # Now call 'latest' after the package is installed
    if provider.respond_to?(:latest)
      assert_nothing_raised("Could not call 'latest'") do
        provider.latest
      end
    end

    # Now remove the package
    if provider.respond_to?(:uninstall)
      assert_nothing_raised do
        provider.uninstall
      end

      assert_absent(provider)
    end
  end

  # Now create a separate test method for each package
  suitable_test_packages.each do |hash|
    mname = ["test", hash[:name].to_s, hash[:provider].to_s].join("_").intern

    if method_defined?(mname)
      warn "Already a test method defined for #{mname}"
    else
      define_method(mname) do
        run_package_installation_test(hash)
      end
    end
  end

  def test_dont_complain_if_theres_nothing_to_test
    assert("sometimes the above metaprogramming fails to find anything to test and the runner complains")
  end

  def modpkg(pkg)
    case pkg[:provider]
    when :sun
      pkg[:adminfile] = "/usr/local/pkg/admin_file"
    end
  end
end

