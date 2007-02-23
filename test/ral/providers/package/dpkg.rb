require File.dirname(__FILE__) + '/../../../lib/puppettest'

require 'mocha'

class DpkgPackageProviderTest < Test::Unit::TestCase
	def setup
		@type = Puppet::Type.type(:package)
		# This is hideous, but absent a 'reset' button on types...
		@type.instance_eval("@objects = {}")
	end
	
	def test_install
		pkg = @type.create :name => 'faff',
		                   :provider => :dpkg,
		                   :ensure => :present,
		                   :source => "/tmp/faff.deb"

		pkg.provider.expects(
		                 :dpkgquery
					  ).with(
							  '-W',
							  '--showformat',
							  '${Status} ${Package} ${Version}\n',
							  'faff'
					  ).returns(
					        "deinstall ok config-files faff 1.2.3-1\n"
					  )

		pkg.provider.expects(
		                 :dpkg
		           ).with(
		                 '-i',
		                 '/tmp/faff.deb'
					  ).returns(0)
		
		pkg.evaluate.each { |state| state.transaction = self; state.forward }
	end
	
	def test_purge
		pkg = @type.create :name => 'faff', :provider => :dpkg, :ensure => :purged

		pkg.provider.expects(
		                 :dpkgquery
					  ).with(
					        '-W',
					        '--showformat',
					        '${Status} ${Package} ${Version}\n',
					        'faff'
					  ).returns(
					        "install ok installed faff 1.2.3-1\n"
					  )
		pkg.provider.expects(
		                 :dpkg
					  ).with(
					        '--purge',
					        'faff'
					  ).returns(0)
		
		pkg.evaluate.each { |state| state.transaction = self; state.forward }
	end
end
