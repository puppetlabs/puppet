require 'facter/util/plist'

Puppet::Type.type(:service).provide :launchd, :parent => :base do
    desc "launchd service management framework.
    
    This provider manages launchd jobs, the default service framework for
    Mac OS X, that has also been open sourced by Apple for possible use on
    other platforms.
    
    See:
     * http://developer.apple.com/macosx/launchd.html
     * http://launchd.macosforge.org/
     
    This provider reads plists out of the following directories:
     * /System/Library/LaunchDaemons
     * /System/Library/LaunchAgents
     * /Library/LaunchDaemons
     * /Library/LaunchAgents
     
    and builds up a list of services based upon each plists \"Label\" entry.
     
    This provider supports:
     * ensure => running/stopped,
     * enable => true/false
     * status
     * restart
    
    Here is how the Puppet states correspond to launchd states:
     * stopped => job unloaded
     * started => job loaded
     * enabled => 'Disable' removed from job plist file
     * disabled => 'Disable' added to job plist file

    Note that this allows you to do something launchctl can't do, which is to
    be in a state of \"stopped/enabled\ or \"running/disabled\".

  "

    commands :launchctl => "/bin/launchctl"
    
    defaultfor :operatingsystem => :darwin
    confine :operatingsystem => :darwin
    
    has_feature :enableable
    
    Launchd_Paths = ["/Library/LaunchAgents",
                     "/Library/LaunchDaemons",
                     "/System/Library/LaunchAgents",
                     "/System/Library/LaunchDaemons",]


    # returns a label => path map for either all jobs, or just a single
    # job if the label is specified
    def self.jobsearch(label=nil)
       label_to_path_map = {}
       Launchd_Paths.each do |path|
           if FileTest.exists?(path)
               Dir.entries(path).each do |f|
                   next if f =~ /^\..*$/
                   next if FileTest.directory?(f)
                   fullpath = File.join(path, f)
                   job = Plist::parse_xml(fullpath)
                   if job and job.has_key?("Label")
                       if job["Label"] == label
                           return { label => fullpath }
                       else
                           label_to_path_map[job["Label"]] = fullpath
                       end
                   end
               end
           end
       end
       
       # if we didn't find the job above and we should have, error.
       if label
           raise Puppet::Error.new("Unable to find launchd plist for job: #{label}")
       end
       # if returning all jobs
       label_to_path_map
    end


    def self.instances
        jobs = self.jobsearch
        jobs.keys.collect do |job|
            new(:name => job, :provider => :launchd, :path => jobs[job])
        end
    end


    # finds the path for a given label and returns the path and parsed plist
    # as an array of [path, plist]. Note plist is really a Hash here.
    def plist_from_label(label)
        job = self.class.jobsearch(label)
        job_path = job[label]
        job_plist = Plist::parse_xml(job_path)
        if not job_plist
            raise Puppet::Error.new("Unable to parse launchd plist at path: #{job_path}")
        end
        [job_path, job_plist]
    end


    def status
        # launchctl list <jobname> exits zero if the job is loaded
        # and non-zero if it isn't. Simple way to check... but is only
        # available on OS X 10.5 unfortunately, so we grab the whole list
        # and check if our resource is included. The output formats differ
        # between 10.4 and 10.5, thus the necessity for splitting
        begin
            output = launchctl :list
            if output.nil?
                raise Puppet::Error.new("launchctl list failed to return any data.")
            end
            output.split("\n").each do |j|
                return :running if j.split(/\s/).last == resource[:name]
            end
            return :stopped
        rescue Puppet::ExecutionFailure
            raise Puppet::Error.new("Unable to determine status of #{resource[:name]}")
        end
    end


    # start the service. To get to a state of running/enabled, we need to
    # conditionally enable at load, then disable by modifying the plist file
    # directly.
    def start
        job_path, job_plist = plist_from_label(resource[:name])
        did_enable_job = false
        cmds = []
        cmds << :launchctl << :load 
        if self.enabled? == :false  # launchctl won't load disabled jobs
            cmds << "-w"
            did_enable_job = true
        end
        cmds << job_path
        begin
            execute(cmds)
        rescue Puppet::ExecutionFailure
            raise Puppet::Error.new("Unable to start service: %s at path: %s" % [resource[:name], job_path])
        end
        # As load -w clears the Disabled flag, we need to add it in after
        if did_enable_job and resource[:enable] == :false
            self.disable
        end 
    end


    def stop
        job_path, job_plist = plist_from_label(resource[:name])
        did_disable_job = false
        cmds = []
        cmds << :launchctl << :unload 
        if self.enabled? == :true # keepalive jobs can't be stopped without disabling
            cmds << "-w"
            did_disable_job = true
        end
        cmds << job_path
        begin
            execute(cmds)
        rescue Puppet::ExecutionFailure
            raise Puppet::Error.new("Unable to stop service: %s at path: %s" % [resource[:name], job_path])
        end
        # As unload -w sets the Disabled flag, we need to add it in after
        if did_disable_job and resource[:enable] == :true
            self.enable
        end
    end


    # launchd jobs are enabled by default. They are only disabled if the key
    # "Disabled" is set to true, but it can also be set to false to enable it.
    def enabled?
        job_path, job_plist = plist_from_label(resource[:name])
        if job_plist.has_key?("Disabled")
            if job_plist["Disabled"]  # inverse of disabled is enabled
                return :false
            end
        end
        return :true
    end


    # enable and disable are a bit hacky. We write out the plist with the appropriate value
    # rather than dealing with launchctl as it is unable to change the Disabled flag
    # without actually loading/unloading the job.
    def enable
        job_path, job_plist = plist_from_label(resource[:name])
        if self.enabled? == :false
            job_plist.delete("Disabled")
            Plist::Emit.save_plist(job_plist, job_path)
        end
    end


    def disable
        job_path, job_plist = plist_from_label(resource[:name])
        job_plist["Disabled"] = true
        Plist::Emit.save_plist(job_plist, job_path)
    end


end
