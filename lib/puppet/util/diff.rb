# Provide a diff between two strings.
module Puppet::Util::Diff
    include Puppet::Util
    require 'tempfile'

    def diff(old, new)
        command = [Puppet[:diff]]
        if args = Puppet[:diff_args] and args != ""
            command << args
        end
        command << old << new
        execute(command, :failonfail => false)
    end

    module_function :diff

    # return diff string of two input strings
    # format defaults to unified
    # context defaults to 3 lines
    def lcs_diff(data_old, data_new, format=:unified, context_lines=3)
        unless Puppet.features.diff?
            Puppet.warning "Cannot provide diff without the diff/lcs Ruby library"
            return ""
        end
        data_old = data_old.split(/\n/).map! { |e| e.chomp }
        data_new = data_new.split(/\n/).map! { |e| e.chomp }

        output = ""

        diffs = ::Diff::LCS.diff(data_old, data_new)
        return output if diffs.empty?

        oldhunk = hunk = nil
        file_length_difference = 0

        diffs.each do |piece|
            begin
                hunk = ::Diff::LCS::Hunk.new(data_old, data_new, piece,
                                           context_lines,
                                           file_length_difference)
                file_length_difference = hunk.file_length_difference
            next unless oldhunk
            # Hunks may overlap, which is why we need to be careful when our
            # diff includes lines of context. Otherwise, we might print
            # redundant lines.
            if (context_lines > 0) and hunk.overlaps?(oldhunk)
                hunk.unshift(oldhunk)
            else
                output << oldhunk.diff(format)
            end
            ensure
                oldhunk = hunk
                output << "\n"
            end
        end

        # Handle the last remaining hunk
        output << oldhunk.diff(format) << "\n"
    end

    def string_file_diff(path, string)
        require 'tempfile'
        tempfile = Tempfile.new("puppet-diffing")
        tempfile.open
        tempfile.print string
        tempfile.close
        print diff(path, tempfile.path)
        tempfile.delete
    end
end

