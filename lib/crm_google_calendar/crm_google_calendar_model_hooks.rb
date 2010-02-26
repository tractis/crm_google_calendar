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
          event = GCal4Ruby::Event.new(cal)
          event.title = get_title
          event.start = due_at + 28800
          event.end = due_at + 32400
          # TODO: Put the uri of the task: event.where = request.request_uri
          event.reminder = { :minutes => "15", :method => 'email' }
          event.save     
        end
      end
    end    

    #----------------------------------------------------------------------------
    def update_gcalendar
      if cal = get_calendar
        if bucket == "specific_time"        
          title = get_title
          
          # Search for the event
          event = GCal4Ruby::Event.find(cal, title, {:scope => :first})
          unless event.blank?
            event.title = title
            event.start = due_at + 28800
            event.end = due_at + 32400
            # TODO: Put the uri of the task: event.where = request.request_uri
            event.reminder = { :minutes => "15", :method => 'email' }
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
          # Search for the event
          event = GCal4Ruby::Event.find(cal, get_title, {:scope => :first})
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
      rescue GCal4Ruby::HTTPPostFailed => ex
        return false
      end
      
      GCal4Ruby::Calendar.find(service, current_user.pref[:google_account]).first      
      
    end
    
    #----------------------------------------------------------------------------
    def get_title
        if asset_id.blank? 
          "crm - #{name}"
        else
          "crm - #{name} (#{asset_type}: #{asset_type == "Contact" ? asset.full_name : asset.name})"
        end      
    end
    
  end
  
end
