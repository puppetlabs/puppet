class Puppet::Type
    # Look up the schedule and set it appropriately.  This is done after
    # the instantiation phase, so that the schedule can be anywhere in the
    # file.
    def schedule

        # If we've already set the schedule, then just move on
        return if self[:schedule].is_a?(Puppet.type(:schedule))

        return unless self[:schedule]

        # Schedules don't need to be scheduled
        #return if self.is_a?(Puppet.type(:schedule))

        # Nor do components
        #return if self.is_a?(Puppet.type(:component))

        if sched = Puppet.type(:schedule)[self[:schedule]]
            self[:schedule] = sched
        else
            self.fail "Could not find schedule %s" % self[:schedule]
        end
    end

    # Check whether we are scheduled to run right now or not.
    def scheduled?
        return true if Puppet[:ignoreschedules]
        return true unless schedule = self[:schedule]

        # We use 'checked' here instead of 'synced' because otherwise we'll
        # end up checking most elements most times, because they will generally
        # have been synced a long time ago (e.g., a file only gets updated
        # once a month on the server and its schedule is daily; the last sync time
        # will have been a month ago, so we'd end up checking every run).
        return schedule.match?(self.cached(:checked).to_i)
    end
end

# $Id$
