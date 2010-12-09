class TaskNotAllowedError < StandardError; end

class CrmGoogleCalendarModelHooks < FatFreeCRM::Callback::Base
  
  Task.class_eval do
    after_create  :create_gcalendar
    after_update  :update_gcalendar
    after_destroy :destroy_gcalendar

    require 'gcal4ruby'
    
    #----------------------------------------------------------------------------
    def create_gcalendar
      if allowed? and cal = get_calendar
        event = GCal4Ruby::Event.new(cal.service, {:title => get_title, :calendar => cal})
        set_event(event)
        event.save
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
      if allowed? and cal = get_calendar
        event = GCal4Ruby::Event.find(cal.service, get_title(name_was), {:calendar => cal.id}).first
        unless event.blank?
          set_event(event)
          event.title = get_title
          event.save
        else
          create_gcalendar
        end    
      end
    rescue TaskNotAllowedError
      logging.warn 'Task of bucket: #{bucket} not allowed for calendar.'
    end

    #----------------------------------------------------------------------------
    def destroy_gcalendar
      if allowed? and cal = get_calendar
        event = GCal4Ruby::Event.find(cal.service, get_title, {:calendar => cal.id}).first
        unless event.blank?
          event.delete
        end
      end
    end    
    
    #----------------------------------------------------------------------------
    def get_calendar
      current_user = User.find(user_id)
      service = GCal4Ruby::Service.new
      begin
        service.authenticate(current_user.pref[:google_account], current_user.pref[:google_password])
      rescue GData4Ruby::HTTPRequestFailed => ex
        return false
      end
      service.calendars.first
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
