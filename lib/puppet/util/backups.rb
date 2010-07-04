require 'find'
module Puppet::Util::Backups

    # Deal with backups.
    def perform_backup(file = nil)
        # if they specifically don't want a backup, then just say
        # we're good
        return true unless self[:backup]

        # let the path be specified
        file ||= self[:path]
        return true unless FileTest.exists?(file)  

        return perform_backup_with_bucket(file) if self.bucket
        return perform_backup_with_backuplocal(file, self[:backup]) 
    end

    private

    def perform_backup_with_bucket(fileobj)
        file = (fileobj.class == String) ? fileobj : fileobj.name
        case File.stat(file).ftype
        when "directory"
            # we don't need to backup directories when recurse is on
            return true if self[:recurse]
            info "Recursively backing up to filebucket"
            Find.find(self[:path]) { |f| backup_file_with_filebucket(f) if File.file?(f) }
        when "file"; backup_file_with_filebucket(file)
        when "link";
        end
        true
    end

    def perform_backup_with_backuplocal(fileobj, backup)
        file = (fileobj.class == String) ? fileobj : fileobj.name
        newfile = file + backup

        remove_backup(newfile)

        begin
            bfile = file + backup

            # Ruby 1.8.1 requires the 'preserve' addition, but
            # later versions do not appear to require it.
            # N.B. cp_r works on both files and directories
            FileUtils.cp_r(file, bfile, :preserve => true)
            return true
        rescue => detail
            # since they said they want a backup, let's error out
            # if we couldn't make one
            self.fail "Could not back %s up: %s" % [file, detail.message]
        end
    end

    def remove_backup(newfile)
        if self.class.name == :file and self[:links] != :follow
            method = :lstat
        else
            method = :stat
        end

        begin
            stat = File.send(method, newfile)
        rescue Errno::ENOENT
            return
        end

        if stat.ftype == "directory"
            raise Puppet::Error, "Will not remove directory backup %s; use a filebucket" % newfile
        end

        info "Removing old backup of type %s" % stat.ftype

        begin
            File.unlink(newfile)
        rescue => detail
            puts detail.backtrace if Puppet[:trace]
            self.fail "Could not remove old backup: %s" % detail
        end
    end

    def backup_file_with_filebucket(f)
        sum = self.bucket.backup(f)
        self.info "Filebucketed %s to %s with sum %s" % [f, self.bucket.name, sum]
        return sum
	end
end
