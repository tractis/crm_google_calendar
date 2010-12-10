
class EventJob < Struct.new(:user_id, :options, :previous)
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

  def merge(event, options)
    options.each do |key, value|
      event.send "#{key}=", value
    end
  end
end

class CreateEventJob < EventJob
  def perform
    if cal = get_calendar
      event = GCal4Ruby::Event.new(cal.service, {:calendar => cal})
      merge event, options
      event.save
    end
  end
end

class UpdateEventJob < EventJob
  def perform
    if cal = get_calendar
      event = GCal4Ruby::Event.find(cal.service, previous, {:calendar => cal.id}).first
      unless event.blank?
        merge event, options
        event.save
      else
        Delayed::Job.enqueue CreateEventJob.new(user_id, options)
      end
    end
  end
end

class DeleteEventJob < EventJob
  def perform
    if cal = get_calendar
      event = GCal4Ruby::Event.find(cal.service, options[:title], {:calendar => cal.id}).first
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
        Delayed::Job.enqueue CreateEventJob.new(user_id, get_event_options(event))
      end
    end

    #----------------------------------------------------------------------------
    def update_gcalendar
      if allowed?
        event = GCal4Ruby::Event.new(GCal4Ruby::Service.new)
        set_event(event)
        options = get_event_options(event)
        options[:title] = get_title
        Delayed::Job.enqueue UpdateEventJob.new(user_id, options, get_title(name_was))
      end
    end

    #----------------------------------------------------------------------------
    def destroy_gcalendar
      if allowed?
        Delayed::Job.enqueue DeleteEventJob.new(user_id, {:title => get_title})
      end
    end

    #----------------------------------------------------------------------------
    def allowed?
      !Regexp.new('^(due_later|due_asap)').match(bucket)
    end

    #----------------------------------------------------------------------------
    def set_event(event)
      if assigned_to
        attendee = User.find(assigned_to)
        event.attendees = [{ :name => attendee.full_name, :email => attendee.email }] if attendee
      end

      event.content = background_info unless background_info.blank?

      event.all_day = true unless (bucket == 'overdue' and due_at) or bucket == 'specific_time'

      event.start_time = case bucket
      when 'overdue'
        due_at || now.mindnight.yesterday
      when 'due_today'
        Time.zone.now.midnight
      when 'due_tomorrow'
        Time.zone.now.midnight.tomorrow
      when 'due_this_week'
        Time.zone.now.end_of_week - 2.day
      when 'due_next_week'
        Time.zone.now.next_week.end_of_week - 2.day
      when 'specific_time'
        due_at
      end

      event.end_time = case bucket
      when 'overdue'
        due_at ? get_event_end : event.start_time
      when 'specific_time'
        get_event_end
      else
        event.start_time
      end

      # TODO: Put the uri of the task: event.where = request.request_uri

      event.reminder = [{ :minutes => "15", :method => 'email' }]
    end

    def get_event_options(event)
      {
        :title => event.title,
        :content => event.content,
        :attendees => event.attendees,
        :start_time => event.start_time,
        :end_time => event.end_time,
        :all_day => event.all_day,
        :reminder => event.reminder
      }
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
    def get_event_end
      Setting.task_calendar_with_time == true ? due_at + 3600 : due_at + 32400
    end
  end
end
