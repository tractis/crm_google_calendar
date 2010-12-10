class TaskNotAllowedError < StandardError; end

def get_calendar(user_id)
  current_user = User.find(user_id)
  service = GCal4Ruby::Service.new
  begin
    service.authenticate(current_user.pref[:google_account], current_user.pref[:google_password])
  rescue GData4Ruby::HTTPRequestFailed => ex
    return false
  end
  service.calendars.first
end

class CreateEventJob < Struct.new(:user_id, :options)
  def perform
    require "pp"
    if cal = get_calendar(user_id)
      event = GCal4Ruby::Event.new(cal.service, {:calendar => cal})
      event.title = options[:title]
      event.content = options[:content] || ''
      event.attendees = options[:attendees]
      event.start_time = options[:start_time]
      event.end_time = options[:end_time]
      event.all_day = options[:all_day]
      event.reminder = options[:reminder]
      event.save
    end
  end
end

class UpdateEventJob < Struct.new(:user_id, :title, :options)
  def perform
    if cal = get_calendar(user_id)
      event = GCal4Ruby::Event.find(cal.service, title, {:calendar => cal.id}).first
      unless event.blank?
        event.title = options[:title]
        event.content = options[:content] || ''
        event.attendees = options[:attendees]
        event.start_time = options[:start_time]
        event.end_time = options[:end_time]
        event.all_day = options[:all_day]
        event.reminder = options[:reminder]
        event.save
      else        
        Delayed::Job.enqueue CreateEventJob.new(user_id, options)
      end
    end
  end
end

class DeleteEventJob < Struct.new(:user_id, :title)
  def perform
    if cal = get_calendar(user_id)
      event = GCal4Ruby::Event.find(cal.service, title, {:calendar => cal.id}).first
      event.delete unless event.blank?
    end
  end
end

class CrmGoogleCalendarModelHooks < FatFreeCRM::Callback::Base
  
  Task.class_eval do
    after_create  :create_gcalendar
    after_update  :update_gcalendar
    after_destroy :destroy_gcalendar

    require 'gcal4ruby'
    
    #----------------------------------------------------------------------------
    def create_gcalendar
      if allowed?
        event = GCal4Ruby::Event.new(GCal4Ruby::Service.new, {:title => get_title})
        set_event(event)
        Delayed::Job.enqueue CreateEventJob.new(user_id, {
          :title => event.title,
          :content => event.content || '',
          :attendees => event.attendees,
          :start_time => event.start_time,
          :end_time => event.end_time,
          :all_day => event.all_day,
          :reminder => event.reminder
        })
      end
    rescue TaskNotAllowedError
      logging.warn 'Task of bucket: #{bucket} not allowed for calendar.'
    end
    
    def allowed?
      !Regexp.new('^(due_later|due_asap)').match(bucket)
    end
    
    def set_event(event)

      if assigned_to
        attendee = User.find(assigned_to)
        event.attendees = [{ :name => attendee.full_name, :email => attendee.email }] if attendee
      end
      
      event.content = background_info unless background_info.blank?
      
      case bucket
      when "overdue"
        if due_at
          event.start_time = due_at
          event.end_time = get_event_end
        else
          event.end_time = event.start_time = Time.zone.now.midnight.yesterday
          event.all_day = true
        end
      when "due_today"
        event.end_time = event.start_time = Time.zone.now.midnight
        event.all_day = true
      when "due_tomorrow"
        event.end_time = event.start_time = Time.zone.now.midnight.tomorrow
        event.all_day = true
      when "due_this_week"
        event.end_time = event.start_time = Time.zone.now.end_of_week - 2.day
        event.all_day = true
      when "due_next_week"
        event.end_time = event.start_time = Time.zone.now.next_week.end_of_week - 2.day
        event.all_day = true
      when "specific_time"
        event.start_time = due_at
        event.end_time = get_event_end
      else # due_later or due_asap
        raise TaskNotAllowedError
      end
      
      # TODO: Put the uri of the task: event.where = request.request_uri
      
      event.reminder = [{ :minutes => "15", :method => 'email' }]
    end

    #----------------------------------------------------------------------------
    def update_gcalendar
      if allowed?
        event = GCal4Ruby::Event.new(GCal4Ruby::Service.new)
        set_event(event)
        Delayed::Job.enqueue UpdateEventJob.new(user_id, get_title(name_was), {
          :title => get_title,
          :content => event.content,
          :attendees => event.attendees,
          :start_time => event.start_time,
          :end_time => event.end_time,
          :all_day => event.all_day,
          :reminder => event.reminder
        })
      end
    rescue TaskNotAllowedError
      logging.warn 'Task of bucket: #{bucket} not allowed for calendar.'
    end

    #----------------------------------------------------------------------------
    def destroy_gcalendar
      if allowed?
        Delayed::Job.enqueue DeleteEventJob.new(user_id, get_title)
      end
    end
    
    #----------------------------------------------------------------------------
    def get_title(title='')
      title = name if title.blank?
      if asset_id.blank? 
        "crm - #{get_category} - #{title}"
      else
        "crm - #{get_category} - #{title} (#{asset_type}: #{asset_type == "Contact" ? asset.full_name : asset.name})"
      end      
    end
 
    #----------------------------------------------------------------------------
    def get_category
      category == "" ? "other" : category
    end

    #----------------------------------------------------------------------------
    def get_event_end(due=nil)
      due ||= due_at
      Setting.task_calendar_with_time == true ? due + 3600 : due + 32400
    end    
    
  end
  
end
