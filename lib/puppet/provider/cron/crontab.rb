require 'puppet/provider/parsedfile'

Puppet::Type.type(:cron).provide(:crontab, :parent => Puppet::Provider::ParsedFile, :default_target => ENV["USER"] || "root") do
  commands :crontab => "crontab"

  text_line :comment, :match => %r{^\s*#}, :post_parse => proc { |record|
    record[:name] = $1 if record[:line] =~ /Puppet Name: (.+)\s*$/
  }

  text_line :blank, :match => %r{^\s*$}

  text_line :environment, :match => %r{^\s*\w+\s*=}

  def self.filetype
  tabname = case Facter.value(:osfamily)
            when "Solaris"
              :suntab
            when "AIX"
              :aixtab
            else
              :crontab
            end

    Puppet::Util::FileType.filetype(tabname)
  end

  self::TIME_FIELDS = [:minute, :hour, :monthday, :month, :weekday]

  record_line :crontab,
    :fields     => %w{time command},
    :match      => %r{^\s*(@\w+|\S+\s+\S+\s+\S+\s+\S+\s+\S+)\s+(.+)$},
    :absent     => '*',
    :block_eval => :instance do

    def post_parse(record)
      time = record.delete(:time)
      if match = /@(\S+)/.match(time)
        # is there another way to access the constant?
        Puppet::Type::Cron::ProviderCrontab::TIME_FIELDS.each { |f| record[f] = :absent }
        record[:special] = match.captures[0]
      elsif match = /(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/.match(time)
        record[:special] = :absent
        Puppet::Type::Cron::ProviderCrontab::TIME_FIELDS.zip(match.captures).each do |field,value|
          if value == self.absent
            record[field] = :absent
          else
            record[field] = value.split(",")
          end
        end
      else
        raise Puppet::Error, _("Line got parsed as a crontab entry but cannot be handled. Please file a bug with the contents of your crontab")
      end
      record
    end

    def pre_gen(record)
      if record[:special] and record[:special] != :absent
        record[:special] = "@#{record[:special]}"
      end

      Puppet::Type::Cron::ProviderCrontab::TIME_FIELDS.each do |field|
        if vals = record[field] and vals.is_a?(Array)
          record[field] = vals.join(",")
        end
      end
      record
    end

    def to_line(record)
      str = ""
      record[:name] = nil if record[:unmanaged]
      str = "# Puppet Name: #{record[:name]}\n" if record[:name]
      if record[:environment] and record[:environment] != :absent
        str += record[:environment].map {|line| "#{line}\n"}.join('')
      end
      if record[:special] and record[:special] != :absent
        fields = [:special, :command]
      else
        fields = Puppet::Type::Cron::ProviderCrontab::TIME_FIELDS + [:command]
      end
      str += record.values_at(*fields).map do |field|
        if field.nil? or field == :absent
          self.absent
        else
          field
        end
      end.join(self.joiner)
      str
    end
  end

  def create
    if resource.should(:command) then
      super
    else
      resource.err _("no command specified, cannot create")
    end
  end

  # Look up a resource with a given name whose user matches a record target
  #
  # @api private
  #
  # @note This overrides the ParsedFile method for finding resources by name,
  #   so that only records for a given user are matched to resources of the
  #   same user so that orphaned records in other crontabs don't get falsely
  #   matched (#2251)
  #
  # @param [Hash<Symbol, Object>] record
  # @param [Array<Puppet::Resource>] resources
  #
  # @return [Puppet::Resource, nil] The resource if found, else nil
  def self.resource_for_record(record, resources)
    resource = super

    if resource
      target = resource[:target] || resource[:user]
      if record[:target] == target
        resource
      end
    end
  end

  # Return the header placed at the top of each generated file, warning
  # users that modifying this file manually is probably a bad idea.
  def self.header
%{# HEADER: This file was autogenerated at #{Time.now} by puppet.
# HEADER: While it can still be managed manually, it is definitely not recommended.
# HEADER: Note particularly that the comments starting with 'Puppet Name' should
# HEADER: not be deleted, as doing so could cause duplicate cron jobs.\n}
  end

  # Regex for finding one vixie cron header.
  def self.native_header_regex
    /# DO NOT EDIT THIS FILE.*?Cron version.*?vixie.*?\n/m
  end

  # If a vixie cron header is found, it should be dropped, cron will insert
  # a new one in any case, so we need to avoid duplicates.
  def self.drop_native_header
    true
  end

  # See if we can match the record against an existing cron job.
  def self.match(record, resources)
    # if the record is named, do not even bother (#19876)
    # except the resource name was implicitly generated (#3220)
    return false if record[:name] and !record[:unmanaged]
    resources.each do |name, resource|
      # Match the command first, since it's the most important one.
      next unless record[:target] == resource[:target]
      next unless record[:command] == resource.value(:command)

      # Now check the time fields
      compare_fields = self::TIME_FIELDS + [:special]

      matched = true
      compare_fields.each do |field|
        # If the resource does not manage a property (say monthday) it should
        # always match. If it is the other way around (e.g. resource defines
        # a should value for :special but the record does not have it, we do
        # not match
        next unless resource[field]
        unless record.include?(field)
          matched = false
          break
        end

        if record_value = record[field] and resource_value = resource.value(field)
          # The record translates '*' into absent in the post_parse hook and
          # the resource type does exactly the opposite (alias :absent to *)
          next if resource_value == '*' and record_value == :absent
          next if resource_value == record_value
        end
        matched =false
        break
      end
      return resource if matched
    end
    false
  end

  @name_index = 0

  # Collapse name and env records.
  def self.prefetch_hook(records)
    name = nil
    envs = nil
    result = records.each { |record|
      case record[:record_type]
      when :comment
        if record[:name]
          name = record[:name]
          record[:skip] = true

          # Start collecting env values
          envs = []
        end
      when :environment
        # If we're collecting env values (meaning we're in a named cronjob),
        # store the line and skip the record.
        if envs
          envs << record[:line]
          record[:skip] = true
        end
      when :blank
        # nothing
      else
        if name
          record[:name] = name
          name = nil
        else
          cmd_string = record[:command].gsub(/\s+/, "_")
          index = ( @name_index += 1 )
          record[:name] = "unmanaged:#{cmd_string}-#{ index.to_s }"
          record[:unmanaged] = true
        end
        if envs.nil? or envs.empty?
          record[:environment] = :absent
        else
          # Collect all of the environment lines, and mark the records to be skipped,
          # since their data is included in our crontab record.
          record[:environment] = envs

          # And turn off env collection again
          envs = nil
        end
      end
    }.reject { |record| record[:skip] }
    result
  end

  def self.to_file(records)
    text = super
    # Apparently Freebsd will "helpfully" add a new TZ line to every
    # single cron line, but not in all cases (e.g., it doesn't do it
    # on my machine).  This is my attempt to fix it so the TZ lines don't
    # multiply.
    if text =~ /(^TZ=.+\n)/
      tz = $1
      text.sub!(tz, '')
      text = tz + text
    end
    text
  end

  def user=(user)
    # we have to mark the target as modified first, to make sure that if
    # we move a cronjob from userA to userB, userA's crontab will also
    # be rewritten
    mark_target_modified
    @property_hash[:user] = user
    @property_hash[:target] = user
  end

  def user
    @property_hash[:user] || @property_hash[:target]
  end

  CRONTAB_DIR = case Facter.value("osfamily")
  when "Debian", "HP-UX"
    "/var/spool/cron/crontabs"
  when /BSD/
    "/var/cron/tabs"
  when "Darwin"
    "/usr/lib/cron/tabs/"
  else
    "/var/spool/cron"
  end

  # Yield the names of all crontab files stored on the local system.
  #
  # @note Ignores files that are not writable for the puppet process.
  #
  # @api private
  def self.enumerate_crontabs
    Puppet.debug "looking for crontabs in #{CRONTAB_DIR}"
    return unless File.readable?(CRONTAB_DIR)
    Dir.foreach(CRONTAB_DIR) do |file|
      path = "#{CRONTAB_DIR}/#{file}"
      yield(file) if File.file?(path) and File.writable?(path)
    end
  end


  # Include all plausible crontab files on the system
  # in the list of targets (#11383 / PUP-1381)
  def self.targets(resources = nil)
    targets = super(resources)
    enumerate_crontabs do |target|
      targets << target
    end
    targets.uniq
  end

end

