# Basic classes for reading, writing, and emptying files.  Not much
# to see here.

require_relative '../../puppet/util/selinux'
require 'tempfile'
require 'fileutils'

class Puppet::Util::FileType
  attr_accessor :loaded, :path, :synced

  class FileReadError < Puppet::Error; end

  include Puppet::Util::SELinux

  class << self
    attr_accessor :name
    include Puppet::Util::ClassGen
  end

  # Create a new filetype.
  def self.newfiletype(name, &block)
    @filetypes ||= {}

    klass = genclass(
      name,
      :block => block,
      :prefix => "FileType",
      :hash => @filetypes
    )

    # Rename the read and write methods, so that we're sure they
    # maintain the stats.
    klass.class_eval do
      # Rename the read method
      define_method(:real_read, instance_method(:read))
      define_method(:read) do
        begin
          val = real_read
          @loaded = Time.now
          if val
            return val.gsub(/# HEADER.*\n/,'')
          else
            return ""
          end
        rescue Puppet::Error
          raise
        rescue => detail
          message = _("%{klass} could not read %{path}: %{detail}") % { klass: self.class, path: @path, detail: detail }
          Puppet.log_exception(detail, message)
          raise Puppet::Error, message, detail.backtrace
        end
      end

      # And then the write method
      define_method(:real_write, instance_method(:write))
      define_method(:write) do |text|
        begin
          val = real_write(text)
          @synced = Time.now
          return val
        rescue Puppet::Error
          raise
        rescue => detail
          message = _("%{klass} could not write %{path}: %{detail}") % { klass: self.class, path: @path, detail: detail }
          Puppet.log_exception(detail, message)
          raise Puppet::Error, message, detail.backtrace
        end
      end
    end
  end

  def self.filetype(type)
    @filetypes[type]
  end

  # Pick or create a filebucket to use.
  def bucket
    @bucket ||= Puppet::Type.type(:filebucket).mkdefaultbucket.bucket
  end

  def initialize(path, default_mode = nil)
    raise ArgumentError.new(_("Path is nil")) if path.nil?
    @path = path
    @default_mode = default_mode
  end

  # Arguments that will be passed to the execute method. Will set the uid
  # to the target user if the target user and the current user are not
  # the same
  def cronargs
    uid = Puppet::Util.uid(@path)
    if uid && uid == Puppet::Util::SUIDManager.uid
      {:failonfail => true, :combine => true}
    else
      {:failonfail => true, :combine => true, :uid => @path}
    end
  end

  # Operate on plain files.
  newfiletype(:flat) do
    # Back the file up before replacing it.
    def backup
      bucket.backup(@path) if Puppet::FileSystem.exist?(@path)
    end

    # Read the file.
    def read
      if Puppet::FileSystem.exist?(@path)
        # this code path is used by many callers so the original default is
        # being explicitly preserved
        Puppet::FileSystem.read(@path, :encoding => Encoding.default_external)
      else
        return nil
      end
    end

    # Remove the file.
    def remove
      Puppet::FileSystem.unlink(@path) if Puppet::FileSystem.exist?(@path)
    end

    # Overwrite the file.
    def write(text)
      # this file is managed by the OS and should be using system encoding
      tf = Tempfile.new("puppet", :encoding => Encoding.default_external)
      tf.print text; tf.flush
      File.chmod(@default_mode, tf.path) if @default_mode
      FileUtils.cp(tf.path, @path)
      tf.close
      # If SELinux is present, we need to ensure the file has its expected context
      set_selinux_default_context(@path)
    end
  end

  # Operate on plain files.
  newfiletype(:ram) do
    @@tabs = {}

    def self.clear
      @@tabs.clear
    end

    def initialize(path, default_mode = nil)
      # default_mode is meaningless for this filetype,
      # supported only for compatibility with :flat
      super
      @@tabs[@path] ||= ""
    end

    # Read the file.
    def read
      Puppet.info _("Reading %{path} from RAM") % { path: @path }
      @@tabs[@path]
    end

    # Remove the file.
    def remove
      Puppet.info _("Removing %{path} from RAM") % { path: @path }
      @@tabs[@path] = ""
    end

    # Overwrite the file.
    def write(text)
      Puppet.info _("Writing %{path} to RAM") % { path: @path }
      @@tabs[@path] = text
    end
  end

  # Handle Linux-style cron tabs.
  #
  # TODO: We can possibly eliminate the "-u <username>" option in cmdbase
  # by just running crontab under <username>'s uid (like we do for suntab
  # and aixtab). It may be worth investigating this alternative
  # implementation in the future. This way, we can refactor all three of
  # our cron file types into a common crontab file type.
  newfiletype(:crontab) do
    def initialize(user)
      self.path = user
    end

    def path=(user)
      begin
        @uid = Puppet::Util.uid(user)
      rescue Puppet::Error => detail
        raise FileReadError, _("Could not retrieve user %{user}: %{detail}") % { user: user, detail: detail }, detail.backtrace
      end

      # XXX We have to have the user name, not the uid, because some
      # systems *cough*linux*cough* require it that way
      @path = user
    end

    # Read a specific @path's cron tab.
    def read
      unless Puppet::Util.uid(@path)
        Puppet.debug _("The %{path} user does not exist. Treating their crontab file as empty in case Puppet creates them in the middle of the run.") % { path: @path }

        return ""
      end

      Puppet::Util::Execution.execute("#{cmdbase} -l", failonfail: true, combine: true)
    rescue => detail
      case detail.to_s
      when /no crontab for/
        return ""
      when /are not allowed to/
        Puppet.debug _("The %{path} user is not authorized to use cron. Their crontab file is treated as empty in case Puppet authorizes them in the middle of the run (by, for example, modifying the cron.deny or cron.allow files).") % { path: @path }

        return ""
      else
        raise FileReadError, _("Could not read crontab for %{path}: %{detail}") % { path: @path, detail: detail }, detail.backtrace
      end
    end

    # Remove a specific @path's cron tab.
    def remove
      cmd = "#{cmdbase} -r"
      if %w{Darwin FreeBSD DragonFly}.include?(Puppet.runtime[:facter].value('os.name'))
        cmd = "/bin/echo yes | #{cmd}"
      end

      Puppet::Util::Execution.execute(cmd, failonfail: true, combine: true)
    end

    # Overwrite a specific @path's cron tab; must be passed the @path name
    # and the text with which to create the cron tab.
    #
    # TODO: We should refactor this at some point to make it identical to the
    # :aixtab and :suntab's write methods so that, at the very least, the pipe
    # is not created and the crontab command's errors are not swallowed.
    def write(text)
      unless Puppet::Util.uid(@path)
        raise Puppet::Error, _("Cannot write the %{path} user's crontab: The user does not exist") % { path: @path }
      end

      # this file is managed by the OS and should be using system encoding
      IO.popen("#{cmdbase()} -", "w", :encoding => Encoding.default_external) { |p|
        p.print text
      }
    end

    private

    # Only add the -u flag when the @path is different.  Fedora apparently
    # does not think I should be allowed to set the @path to my own user name
    def cmdbase
      if @uid == Puppet::Util::SUIDManager.uid || Puppet.runtime[:facter].value('os.name') == "HP-UX"
        return "crontab"
      else
        return "crontab -u #{@path}"
      end
    end
  end

  # SunOS has completely different cron commands; this class implements
  # its versions.
  newfiletype(:suntab) do
    # Read a specific @path's cron tab.
    def read
      unless Puppet::Util.uid(@path)
        Puppet.debug _("The %{path} user does not exist. Treating their crontab file as empty in case Puppet creates them in the middle of the run.") % { path: @path }

        return ""
      end

      Puppet::Util::Execution.execute(%w{crontab -l}, cronargs)
    rescue => detail
      case detail.to_s
      when /can't open your crontab/
        return ""
      when /you are not authorized to use cron/
        Puppet.debug _("The %{path} user is not authorized to use cron. Their crontab file is treated as empty in case Puppet authorizes them in the middle of the run (by, for example, modifying the cron.deny or cron.allow files).") % { path: @path }

        return ""
      else
        raise FileReadError, _("Could not read crontab for %{path}: %{detail}") % { path: @path, detail: detail }, detail.backtrace
      end
    end

    # Remove a specific @path's cron tab.
    def remove
      Puppet::Util::Execution.execute(%w{crontab -r}, cronargs)
    rescue => detail
      raise FileReadError, _("Could not remove crontab for %{path}: %{detail}") % { path: @path, detail: detail }, detail.backtrace
    end

    # Overwrite a specific @path's cron tab; must be passed the @path name
    # and the text with which to create the cron tab.
    def write(text)
      # this file is managed by the OS and should be using system encoding
      output_file = Tempfile.new("puppet_suntab", :encoding => Encoding.default_external)
      begin
        output_file.print text
        output_file.close
        # We have to chown the stupid file to the user.
        File.chown(Puppet::Util.uid(@path), nil, output_file.path)
        Puppet::Util::Execution.execute(["crontab", output_file.path], cronargs)
      rescue => detail
        raise FileReadError, _("Could not write crontab for %{path}: %{detail}") % { path: @path, detail: detail }, detail.backtrace
      ensure
        output_file.close
        output_file.unlink
      end
    end
  end

  #  Support for AIX crontab with output different than suntab's crontab command.
  newfiletype(:aixtab) do
    # Read a specific @path's cron tab.
    def read
      unless Puppet::Util.uid(@path)
        Puppet.debug _("The %{path} user does not exist. Treating their crontab file as empty in case Puppet creates them in the middle of the run.") % { path: @path }

        return ""
      end

      Puppet::Util::Execution.execute(%w{crontab -l}, cronargs)
    rescue => detail
      case detail.to_s
      when /open.*in.*directory/
        return ""
      when /not.*authorized.*cron/
        Puppet.debug _("The %{path} user is not authorized to use cron. Their crontab file is treated as empty in case Puppet authorizes them in the middle of the run (by, for example, modifying the cron.deny or cron.allow files).") % { path: @path }

        return ""
      else
        raise FileReadError, _("Could not read crontab for %{path}: %{detail}") % { path: @path, detail: detail }, detail.backtrace
      end
    end

    # Remove a specific @path's cron tab.
    def remove
      Puppet::Util::Execution.execute(%w{crontab -r}, cronargs)
    rescue => detail
      raise FileReadError, _("Could not remove crontab for %{path}: %{detail}") % { path: @path, detail: detail }, detail.backtrace
    end

    # Overwrite a specific @path's cron tab; must be passed the @path name
    # and the text with which to create the cron tab.
    def write(text)
      # this file is managed by the OS and should be using system encoding
      output_file = Tempfile.new("puppet_aixtab", :encoding => Encoding.default_external)

      begin
        output_file.print text
        output_file.close
        # We have to chown the stupid file to the user.
        File.chown(Puppet::Util.uid(@path), nil, output_file.path)
        Puppet::Util::Execution.execute(["crontab", output_file.path], cronargs)
      rescue => detail
        raise FileReadError, _("Could not write crontab for %{path}: %{detail}") % { path: @path, detail: detail }, detail.backtrace
      ensure
        output_file.close
        output_file.unlink
      end
    end
  end
end
