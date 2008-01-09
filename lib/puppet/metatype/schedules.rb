class Puppet::Type
    # Look up the schedule and set it appropriately.  This is done after
    # the instantiation phase, so that the schedule can be anywhere in the
    # file.
    def schedule
        unless catalog
            warning "Cannot schedule without a schedule-containing catalog"
            return nil
        end
        unless defined? @schedule
            if name = self[:schedule]
                if sched = catalog.resource(:schedule, name)
                    @schedule = sched
                else
                    self.fail "Could not find schedule %s" % name
                end
            else
                @schedule = nil
            end
        end
        @schedule
    end

    # Check whether we are scheduled to run right now or not.
    def scheduled?
        return true if Puppet[:ignoreschedules]
        return true unless schedule = self.schedule

        # We use 'checked' here instead of 'synced' because otherwise we'll
        # end up checking most resources most times, because they will generally
        # have been synced a long time ago (e.g., a file only gets updated
        # once a month on the server and its schedule is daily; the last sync time
        # will have been a month ago, so we'd end up checking every run).
        return schedule.match?(self.cached(:checked).to_i)
    end
end

