require 'puppet/provider/parsedfile'

Puppet::Type.type(:mailalias).provide(
  :aliases,
  :parent => Puppet::Provider::ParsedFile,
  :default_target => "/etc/aliases",
  :filetype => :flat
) do
  text_line :comment, :match => /^#/
  text_line :blank, :match => /^\s*$/

  record_line :aliases, :fields => %w{name recipient}, :separator => /\s*:\s*/, :block_eval => :instance do
    def post_parse(record)
      if record[:recipient]
	record[:recipient] = record[:recipient].split(/\s*,\s*/).collect { |d| d.gsub(/^['"]|['"]$/, '') }
      end
      record
    end

    def process(line)
      ret = {}
      records = line.split(':',4)
      ret[:name] = records[0].strip
      if records.length == 4 and records[2].strip == 'include'
	ret[:file] = records[3].strip
      else
	records = line.split(':',2)
	ret[:recipient] = records[1].strip
      end
      ret
    end

    def to_line(record)
      if record[:recipient]
	dest = record[:recipient].collect do |d|
	  # Quote aliases that have non-alpha chars
	  if d =~ /[^-+\w@.]/
	    '"%s"' % d
	  else
	    d
	  end
	end.join(",")
	"#{record[:name]}: #{dest}"
      elsif record[:file]
	"#{record[:name]}: :include: #{record[:file]}"
      end
    end
  end
end

