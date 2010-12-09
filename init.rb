require "fat_free_crm"

FatFreeCRM::Plugin.register(:crm_google_calendar, initializer) do
          name "Google calendar integration"
       authors "Tractis - https://www.tractis.com - Jose Luis Gordo Romero"
       version "0.1"
   description "Create events from tasks in your google calendar"
  dependencies :haml, :simple_column_search
end

require "crm_google_calendar"