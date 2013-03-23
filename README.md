gitolite-hipchat-notification
==============================

Adapted heavily from: https://github.com/LegionSB/gitolite-campfire-notification

Installation (basic)
--------------------

1. Copy files to your gitolite user's .gitolite/hooks/common folder
2. Rename config.yml.example to config.yml, and fill in your Hipchat account information
3. Re-run "gitolite setup" (or "gl-setup" for g2) to propogate the hooks to each repo's hook folder

Installation (advanced)
-----------------------
This method will allow you to use the config.yml for some (or all) of the configuration or the gitolite.conf configuration file for some (or all) of the config.  This setup will also maintain the hooks in the gitolite-admin repository.

1. As the gitolite user on the gitolite server:
- Update the GIT\_CONFIG\_KEYS variable in the ~/.gitolite.rc to include "hooks\..\*" (If this variable is already defined, regex matches are space separated)
- Add "LOCAL\_CODE =>  "$ENV{HOME}/.gitolite/local-code"," to the ~/gitolite.rc
2. In your checked out copy of the gitolite-admin repo:
- Create the local-code/hooks/common directory ("mkdir -p local-code/hooks/common")
- Copy the post-receive, post-receive-hipchat.rb, and config.yml (if desired) into this directory
3. Configure

Configuration
-------------
Individual repository variables will override the @all repository.  Both will override settings in the config.yml.

config.yml example:
<pre>
apitoken: '1234567890'
room: "developers"
notify: 0
from: "Gitolite"
gitweburl: 'https://git.mycompany.com'
proxyaddress: "1.2.3.4"
proxyport: 83
</pre>

gitolite.conf:
<pre>
repo @all
  config hooks.hipchat.from = Git

repo cool\_project
  RW+ = @all
  config hooks.hipchat.room = CoolRoom

repo puppet
  RW+ = @ops
  R   = @all
  config hooks.hipchat.apitoken = 'asdfjkl'
  config hooks.hipchat.room = Ops
</pre>
Note: Git config variables cannot have an underscore in them so there are some changes from the previous variable names.

New Features
------------
- nospeak config to suppress messages from some repository have to be ignored

	Example: <pre>
# In gitolite.conf
repo testing
		RW+     =   @all
		config hooks.hipchat.from = Testing
		config hooks.hipchat.nospeak = 1
# Or set config.yml nospeak as 1, so all repositories won't speak.
# Then turn on speak for the repositoriess you want
# In config.yml
nospeak: '1'
# In gitolite.conf
repo testing
		RW+     =   @all
		config hooks.hipchat.from = Testing
		config hooks.hipchat.nospeak = 0
# actually all values except 1 will make it speak
</pre>

- redmineurl feature to support view commits in redmine

	Example: <pre>
# In config.yml
redmineurl: 'http://redmine-url.com'
# In gitolite.conf
repo testing
	RW+     =   @all
	config hooks.hipchat.from = Testing
	config hooks.hipchat.project = your-project
	config hooks.hipchat.repository = some-name-other-than-testing # (optional)
</pre>

TO-DO
-----
- set some keyword in commit message that will notify the hipchat window