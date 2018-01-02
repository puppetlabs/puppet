require 'puppet'

class Benchmarker
  def initialize(target, size)
    @size = size
    @direction = ENV['SER_DIRECTION'] == 'generate' ? :generate : :parse
    @format = ENV['SER_FORMAT'] == 'pson' ? :pson : :json

    puts "Benchmarker #{@direction} #{@format}"
  end

  def setup
  end

  def generate
    path = File.expand_path(File.join(__FILE__, '../catalog.json'))
    puts "Using catalog #{path}"

    @data = File.read(path)
    @catalog = JSON.parse(@data)
  end

  def run(args=nil)
    0.upto(@size) do |i|
      # This parses a catalog from JSON data, which is a combination of parsing
      # the data into a JSON hash, and the parsing the hash into a Catalog. It's
      # interesting to see just how slow that latter process is:
      #
      #   Puppet::Resource::Catalog.convert_from(:json, @data)
      #
      # However, for this benchmark, we're just testing how long JSON vs PSON
      # parsing and generation are, where we default to parsing JSON.
      #
      if @direction == :generate
        if @format == :pson
          PSON.dump(@catalog)
        else
          JSON.dump(@catalog)
        end
      else
        if @format == :pson
          PSON.parse(@data)
        else
          JSON.parse(@data)
        end
      end
    end
  end
end
