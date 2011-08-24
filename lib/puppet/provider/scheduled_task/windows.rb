require 'win32/taskscheduler' if Puppet.features.microsoft_windows?
require 'time'

Puppet::Type.type(:scheduled_task).provide(:windows) do
  desc "Support for enhanced Windows Scheduled Tasks.

  Scheduled tasks are controlled using Win32Utils , 'win32-taskscheduler' gem."

  defaultfor :operatingsystem => :windows
  confine :operatingsystem => :windows
  confine :true => Puppet.features.microsoft_windows?

  def enable
    task.flags &= ~( Win32::TaskScheduler::TASK_FLAG_DISABLED )
  rescue Win32::TaskScheduler::Error => detail
    raise Puppet::Error.new("Cannot enable task #{@resource[:name]}, error was: #{detail}" )
  end

  def disable
    task.flags |= Win32::TaskScheduler::TASK_FLAG_DISABLED
  rescue Win32::TaskScheduler::Error => detail
    raise Puppet::Error.new("Cannot disable task #{@resource[:name]}, error was: #{detail}" )
  end

  def enabled?
    ( 0 == (task.flags & Win32::TaskScheduler::TASK_FLAG_DISABLED) ) ? :true : :false
  rescue Win32::TaskScheduler::Error => detail
    raise Puppet::Error.new("Cannot determine if task #{@resource[:name]} is enabled, error was: #{detail}" )
  end

  def exists?
    !jobname.nil?
  end

  def create
    # create the basic work itme
    task.new_work_item( taskname, trigger )

    # Forward slash PATH seperators are OK: will be corrected by the gem
    # tokenize by quoted args first(' or ")
    bin_ary = @resource[:command].scan(/.*["'](.*)['"](.*)/).flatten
    # tokenize by spaces is no quoted args found
    bin_ary = @resource[:command].split if bin_ary.empty?
    bin_ary.each{ |p| p.strip! }
    bin_ary.delete_if{ |p| p.nil? || p.empty?}    # delete any empty/nil values

    task.application_name = bin_ary[0] unless bin_ary.empty?
    task.parameters = bin_ary.slice(1..-1).join(' ') unless bin_ary.nil? || ( 2 > bin_ary.size )

    # FIXME: Assume working dir is command's. Should add a property
    task.working_directory = File.dirname( task.application_name )

    # FIXME: Add a priority property
    task.priority = Win32::TaskScheduler::NORMAL

=begin
    # FIXME: validate
    flags = 0
    @resource[ :task_modifiers ].each{ |value|
      case value.to_sym
        when :userloggedin
          flags |= Win32::TaskScheduler::RUN_ONLY_IF_LOGGED_ON
        when :interactive
          flags |= Win32::TaskScheduler::INTERACTIVE
        when :deletewhendone
          flags |= Win32::TaskScheduler::TASK_FLAG_DELETE_WHEN_DONE
      end
    } unless @resource[ :task_modifiers ].nil?
    task.flags = flags
=end

    # set all tasks to run as the local system account: no password is required
    task.set_account_information( 'system', nil )

    # FIXME: cannot use resource[:user] without a password
    # task.set_account_information( @resource[ :user ], ( property? :password ? @resource[ :password ] : nil ) ) if property? :user
    # Puppet.warning "The 'user' property is not currently supported. Defaulting to the local 'SYSTEM' account." if property? :user

    commit

  rescue Win32::TaskScheduler::Error => detail
    raise Puppet::Error.new("Cannot create task #{@resource[:name]}, error was: #{detail}" )
  end

  def destroy
    task.delete( taskname )
  rescue Win32::TaskScheduler::Error => detail
    raise Puppet::Error.new("Cannot delete task #{@resource[:name]}, error was: #{detail}" )
  end

  ## Property getor/setors:
  #
  def command
    c = @resource[:command]
    unless task.nil?
      # Gem rewrites filepath, so make sure the manaifest is really different from resource
      c = task.application_name
      c = "\"#{c}\"" if c.include?(' ')
      c = "#{c.gsub!('\\', '/')} #{task.parameters}".strip
    end
    c
  end

  # caveat: Embedded spaces in the bin name must be quoted, i.e.
  # ='"c:/document and settings/ruby.bat" --debug'
  def command=( value )
    unless task.nil?
      # tokenize by quoted args first(' or ")
      bin_ary = value.scan(/.*["'](.*)['"](.*)/).flatten
      # tokenize by spaces is no quoted args found
      bin_ary = value.split if bin_ary.empty?
      bin_ary.each{ |p| p.strip! }
      bin_ary.delete_if{ |p| p.nil? || p.empty?}    # delete any empty/nil values

      # Can't modify the instance task, so...
      t = Win32::TaskScheduler.new
      t.activate taskname
      t.application_name = bin_ary[0] unless bin_ary.empty?
      t.parameters = bin_ary.slice(1..-1).join(' ') unless( 2 > bin_ary.size )
      t.save
      task.activate taskname  # refresh the instance var
    end

    @resource[:command] = value
  rescue Win32::TaskScheduler::Error => detail
    raise Puppet::Error.new("Cannot update task #{@resource[:name]} command, error was: #{detail}" )
  end

  def user
    user = @resource[:user]
    user = task.account_information unless task.nil?
    user = :absent if user.empty? || user.nil?
    user
    # FIXME: Only SYSTEM user is currently supported. Return identity
    # so Puppet doesn't always want to re-apply
    @resource[:user]
  end

  def user= user
    unless task.nil?
      # Again, can't modify the instance task, so...
      t = Win32::TaskScheduler.new
      t.activate taskname
      # FIXME: Until passwords are supported as a property, only the localhost
      # SYSTEM account is supported
      t.set_account_information 'system',nil  # user,nil
      t.save
      task.activate taskname  # refresh the instance var
    end
    @resource[:user] = user
  rescue Win32::TaskScheduler::Error => detail
    raise Puppet::Error.new("Cannot update task #{@resource[:name]} user, error was: #{detail}" )
  end

  def minute
    min = @resource[:minute]
    min = [ task.trigger(0)['start_minute'].to_s ] unless task.trigger_count < 1
    min
  end

  def minute= m
    update_trigger 'start_minute', m[ 0 ].to_i
    @resource[:minute] = m
  end

  def hour
    hour = @resource[:hour]
    hour = [ task.trigger(0)['start_hour'].to_s ] unless task.trigger_count < 1 || hour == :absent
    hour
  end

  def hour= h
    update_trigger 'start_hour', h[ 0 ].to_i unless h == :absent
    @resource[:hour] = h
  end

  def month
    mon = @resource[:month]
    mon = [ task.trigger(0)['start_month'].to_s ] unless task.trigger_count < 1 ||  mon == :absent
    mon
  end

  def month= m
    update_trigger 'start_month', m[ 0 ].to_i unless m == :absent
    @resource[:month] = m
  end

  def weekday
    wd = @resource[:weekday]
    unless task.trigger_count < 1 || wd == :absent
      tr = task.trigger 0
      daysofweek = tr[ 'type' ][ 'days_of_week' ] unless tr.nil? || tr['type'].nil?
      unless daysofweek.nil?
        wd = []
        # FIXME: refactor
        tsdays= [
          Win32::TaskScheduler::TASK_SUNDAY,
          Win32::TaskScheduler::TASK_MONDAY,
          Win32::TaskScheduler::TASK_TUESDAY,
          Win32::TaskScheduler::TASK_WEDNESDAY,
          Win32::TaskScheduler::TASK_THURSDAY,
          Win32::TaskScheduler::TASK_FRIDAY,
          Win32::TaskScheduler::TASK_SATURDAY,
          Win32::TaskScheduler::TASK_SUNDAY ]
        (0..7).each{ |d| wd << d unless( 0 == ( daysofweek & tsdays[d] ) ) }
      end
    end
    wd
  end

  def weekday= wd
    days = 0
    wd.each{ |d| days |=  Win32::TaskScheduler::SUNDAY << d.to_i } unless wd == :absent
    unless days == 0
      update_trigger 'trigger_type', Win32::TaskScheduler::WEEKLY   # probably unneccesary
      update_trigger 'type', { 'weeks_interval' => 1, 'days_of_week' => days }
    end
    @resource[:weekday] = wd
  end

  def monthday
    md = @resource[:monthday]
    md = [ task.trigger(0)['start_day'].to_s ] unless task.trigger_count < 1 || md == :absent
    md
  end

  def monthday= md
    update_trigger 'start_day', md[ 0 ].to_i unless md == :absent
    @resource[:monthday] = md
  end

  def repeat
    r = @resource[:repeat]
    unless task.trigger_count < 1
      tr = task.trigger(0)
      # uncoupled to the type enums, so remap
      case tr['trigger_type']
      when Win32::TaskScheduler::DAILY
        # 0=daily, 3=hourly
        r = ( tr[ 'minutes_interval' ] == 60 ) ? ['3'] : ['0']
      when Win32::TaskScheduler::WEEKLY
        r = ['1']
      when Win32::TaskScheduler::MONTHLYDATE
        r = ['2']
      when Win32::TaskScheduler::ONCE
        r = ['4']
      else
        r = ['0']
      end
    end
    r
  end

  def repeat= value
    # cruel, but fair
    tr = repeat_triggers
    tr.each_pair{|k,v| update_trigger k, v } unless tr.nil?
    @resource[:repeat] = value
  end

  # FIXME
  def start_flags
    @resource[:start_flags]
  end

  # FIXME
  def start_flags= value
    @resource[:start_flags] = value
  end

  # FIXME
  def task_modifiers
    @resource[:task_modifiers]
  end

  # FIXME
  def task_modifiers= value
    @resource[:task_modifiers] = value
  end

  def purge
    task.enum.each{ |t| task.delete( t.name ) unless ( 0 == ( t.flags & Win32::TaskScheduler::TASK_FLAG_DISABLED ) ) }
  end

  def self.instances
    Win32::TaskScheduler.new.enum.map{ |job| new( :name => job.grep(/(.*)\.job/){$1}[0] ) }
  end

  private

  # The taskname will be either the resource name orthe basename of the command
  def taskname
    @resource[ :name ] || File.basename( @resource[ :command ] )
  end

  # Returns the memoized jobname for this task. The job name for Task Scheduler v1.0
  # is the filename of the task artifact in %WINDOWS\task
  def jobname
    if @jobname.nil?
      lowername = ( @resource[ :name ] + ".job" ).downcase
      @jobname = Win32::TaskScheduler.new.enum.find{ |t| t.downcase == lowername }
    end
    @jobname
  end

  # helper bool to return true if property exists AND isn't ansent
  def property? sym
    !( @resource[sym].nil? || @resource[sym] == :absent )
  end

  # sets the pertainent repeat trigger values
  def repeat_triggers
    trigger = {}
    case @resource[ 'repeat' ][0].to_i
    when 0  # :daily
      trigger[ 'trigger_type' ] = Win32::TaskScheduler::DAILY
      trigger[ 'type' ] = { :days_interval => 1 }

    when 1  # :weekly
      trigger[ 'trigger_type' ] = Win32::TaskScheduler::WEEKLY
      trigger[ 'type' ] = { 'weeks_interval' => 1 }
      if property? :weekday
        days = 0
        @resource[ 'weekday' ].each{ |day|
          days |=  Win32::TaskScheduler::SUNDAY << day.to_i
        }
        trigger[ 'type' ][ 'days_of_week' ] = days unless( days == 0 )
      end

    when 2  # :monthly
      trigger[ 'trigger_type' ] = Win32::TaskScheduler::MONTHLYDATE
      trigger[ 'type' ] = {
        'months' => 0xFFF,   # every month
        'days' => 1 << @resource[ 'monthday' ][0].to_i - 1,
      }

    when 3  # :hourly
      trigger[ 'trigger_type' ] = Win32::TaskScheduler::DAILY
      trigger[ 'type' ] = { 'days_interval' => 1 }
      trigger[ 'minutes_interval' ] = 60
      trigger[ 'minutes_duration' ] = 24*60

    when 4  # :once
      trigger[ 'trigger_type' ] = Win32::TaskScheduler::ONCE

    end if property? :repeat
    trigger
  end

  # Returns a memoized trigger hash
  def trigger
    # times are assumed to be in local format
    tstart = Time.new + 60
    if @trigger.nil?
      # Default is once a day starting the next minute
      @trigger = {
        'start_year' => tstart.year,
        'start_month' => tstart.month,
        'start_day' => tstart.mday,
        'start_hour' => tstart.hour,
        'start_minute' => tstart.min,
        'trigger_type' => Win32::TaskScheduler::DAILY,
        'type' => {
          "days_interval" => 1
        }
      }

      # override w/properties
      @trigger[ 'start_month' ] = @resource[ :month ][0].to_i if property? :month
      @trigger[ 'start_day' ]   = @resource[ :monthday ][0].to_i if property? :monthday
      @trigger[ 'start_hour' ]  = @resource[ :hour ][0].to_i if property? :hour
      @trigger[ 'start_minute' ]= @resource[ :minute ][0].to_i if property? :minute

      @trigger.merge! repeat_triggers

=begin
      # FIXME: start_flags property.
      @resource[ :start_flags ].each{ |value|
        case value.to_sym
        when :onidle
          @trigger[ 'trigger_type' ] = Win32::TaskScheduler::ON_IDLE
          @trigger[ 'type' ] = {}
        when :onlogin
          @trigger[ 'trigger_type' ] = Win32::TaskScheduler::AT_LOGON
        when :onsysstart
          @trigger[ 'trigger_type' ] = Win32::TaskScheduler::AT_SYSTEMSTART
        end
      }
=end
   end

    # TODO: Return an array of triggers for repetitive schedules
    @trigger
  end

  # Returns a memoized task instance, activating if this task already exists
  def task
    @task = Win32::TaskScheduler.new if @task.nil?
    @task.activate( taskname ) if exists?
    @task
  end

  # Save and refresh the task's state
  def commit
    task.save
    # .save is destructive so re-activate the task
    task.activate taskname
  rescue Win32::TaskScheduler::Error => detail
    raise Puppet::Error.new("Cannot save task #{@resource[:name]}, error was: #{detail}" )
  end

  # Refresh the task's default [0] trigger
  def update_trigger key, value
    unless task.trigger_count < 1
      tr = task.trigger( 0 )
      tr[ key ] = value
      # The gem won't update the trigger of the instance task,
      # so alloc a copy and update it. Optimize this, please...
      t = Win32::TaskScheduler.new
      t.activate taskname
      raise Win32::TaskScheduler::Error( "add_trigger(0,trigger) failed" ) unless t.add_trigger(0, tr)
      t.save
      # refresh the instance task
      task.activate taskname
    end
    tr
  rescue Win32::TaskScheduler::Error => detail
    raise Puppet::Error.new("Cannot update task #{@resource[:name]} trigger, error was: #{detail}" )
  end

  # Return the time (if any) this task expires
  def expires
    texp = Time.at(0)
    if exists?
      @task.activate( taskname )
      raise Puppet::Error.new("Task #{@resource[:name]} contains no triggers. Can't expire" ) if @task.trigger_count < 1
      trigger = @task.trigger(0)
      texp = Time.new( trigger['end_year'], trigger['end_month'], trigger['end_day'], trigger['end_hour'] )
    end
    texp.gmtime
  end

end
