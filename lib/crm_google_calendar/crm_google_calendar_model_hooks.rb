class CrmGoogleCalendarModelHooks < FatFreeCRM::Callback::Base
  
  Task.class_eval do
    after_create  :create_gcalendar
    after_update  :update_gcalendar
    after_destroy :destroy_gcalendar

    require 'gcal4ruby'
    
    #----------------------------------------------------------------------------
    def create_gcalendar
      if cal = get_calendar
        if bucket == "specific_time"
          event = GCal4Ruby::Event.new(cal.service, {:title => get_title, :calendar => cal})
          set_event(event)
          event.save
        end
      end
    end
    
    def set_event(event)
      if assigned_to
          attendee = User.find(assigned_to)
          event.attendees = [{ :name => attendee.full_name, :email => attendee.email }] if attendee
      end
      event.content = background_info unless background_info.blank?
      event.start_time = get_event_start
      event.end_time = get_event_end
      # TODO: Put the uri of the task: event.where = request.request_uri
      event.reminder = [{ :minutes => "15", :method => 'email' }]
    end

    #----------------------------------------------------------------------------
    def update_gcalendar
      if cal = get_calendar
        if bucket == "specific_time"
          event = GCal4Ruby::Event.find(cal.service, get_title(name_was), {:calendar => cal.id}).first
          unless event.blank?
            set_event(event)
            event.title = get_title
            event.save
          else
            create_gcalendar
          end
        end      
      end
    end

    #----------------------------------------------------------------------------
    def destroy_gcalendar
      if cal = get_calendar
        if bucket == "specific_time"
          event = GCal4Ruby::Event.find(cal.service, get_title, {:calendar => cal.id}).first
          unless event.blank?
            event.delete
          end
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
    def get_event_start
      Setting.task_calendar_with_time == true ? due_at : due_at + 28800
    end

    #----------------------------------------------------------------------------
    def get_event_end
      Setting.task_calendar_with_time == true ? due_at + 3600 : due_at + 32400
    end    
    
  end
  
end
