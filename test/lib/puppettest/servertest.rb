require 'puppettest'

module PuppetTest::ServerTest
  include PuppetTest
  def setup
    super

    if defined?(@@port)
      @@port += 1
    else
      @@port = 20000
    end
  end

  # create a simple manifest that just creates a file
  def mktestmanifest
    file = File.join(Puppet[:confdir], "#{(self.class.to_s + "test")}site.pp")
    #@createdfile = File.join(tmpdir, self.class.to_s + "manifesttesting" +
    #    "_#{@method_name}")
    @createdfile = tempfile

    File.open(file, "w") { |f|
      f.puts "file { \"%s\": ensure => file, mode => 755 }\n" % @createdfile
    }

    @@tmpfiles << @createdfile
    @@tmpfiles << file

    file
  end
end

