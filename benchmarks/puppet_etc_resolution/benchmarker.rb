require 'puppet'

class Benchmarker
  def initialize(target, size)
    @size = size
    puts "Benchmarker #{@resolver}"
  end

  def setup
    if Etc.getpwnam('root').nil?
      puts "Etc not functional on this host"
      exit
    end
  end

  def generate
  end

  def run(args=nil)
    0.upto(@size) do |i|
      # This just does a search of all users on the system, and on a system
      # that uses Useradd, resolves these users via Etc. Really only useful to
      # compare the 'Puppet::Etc' values to the 'Etc' values.
      #
      Puppet::Resource.indirection.search('User', {})
    end
  end
end
