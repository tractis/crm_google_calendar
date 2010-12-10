Google Calendar integration plugin for Fat Free CRM
============

Important: Needs Fat Free Crm >= 0.9.10

Put/Edit/Delete events for tasks with due date

This plugin requires:

 * https://github.com/tractis/crm_google_account_settings - google account settings in user profile
 * https://github.com/collectiveidea/delayed_job - Delayed job (v2.0) for responsiveness


Installation
============

The plugin can be installed by running:

    script/plugin install git://github.com/tractis/crm_google_account_settings.git
    script/plugin install git://github.com/tractis/crm_google_calendar.git
	script/plugin install git://github.com/collectiveidea/delayed_job.git -r v2.0
    sudo gem install gcal4ruby
	script/generate delayed_job
	rake db:migrate

Choose how to run the delayed_jobs script:

 * Using god: http://jetpackweb.com/blog/tags/delayed_job/
 * Using monit: http://stackoverflow.com/questions/1226302/how-to-monitor-delayed-job-with-monit

Then restart your web server.

Copyright (c) 2010 by Tractis (https://www.tractis.com), released under the MIT License