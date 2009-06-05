require 'puppet/provider/parsedfile'

Puppet::Type.type(:mailalias).provide(:aliases,
    :parent => Puppet::Provider::ParsedFile,
    :default_target => "/etc/aliases",
    :filetype => :flat
) do
    text_line :comment, :match => /^#/
    text_line :blank, :match => /^\s*$/

    record_line :aliases, :fields => %w{name recipient}, :separator => /\s*:\s*/, :block_eval => :instance do
        def post_parse(record)
            # LAK:NOTE See http://snurl.com/21zf8  [groups_google_com]
            # It's not sufficient to assign to an existing hash.
            recipient = record[:recipient].split(/\s*,\s*/).collect { |d| d.gsub(/^['"]|['"]$/, '') }
            record[:recipient] = recipient
            record
        end

        def process(line)
          ret = {}
          records = line.split(':',2)
          ret[:name] = records[0].strip()
          ret[:recipient] = records[1].strip()
          ret
        end

        def to_line(record)
            dest = record[:recipient].collect do |d|
                # Quote aliases that have non-alpha chars
                if d =~ /[^-\w@.]/
                    '"%s"' % d
                else
                    d
                end
            end.join(",")
            return "%s: %s" % [record[:name], dest]
        end
    end
end

