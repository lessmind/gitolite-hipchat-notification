#!/usr/bin/env ruby

require 'yaml'
require 'time'
require 'net/https'

conffile = File.join(File.dirname(__FILE__), 'config.yml')
if File.exist?(conffile)
  CONFIG = YAML::load(File.open(conffile))
else
  CONFIG = {}
end

def set_var varname, args = {}
  required = args[:required] ||= false
  default = args[:default] ||= nil

	tmp_value = (%x[git config hooks.#{varname} ]).chomp.strip
  if tmp_value.to_s == ''
    varname.gsub!(/hipchat\./, '')
    if CONFIG[varname]
      value = CONFIG[varname]
    else
      if required && !default
        $stderr.puts "#{varname} not found - exiting"
        exit
      else
        value = default
      end
    end
  else
    value = tmp_value
  end
  value
end

def speak(message, force_notify = false)
  auth_token = set_var('hipchat.apitoken', :required => true)
  room = set_var('hipchat.room', :required => true)
  notify = set_var('hipchat.notify', :default => 0)
  if force_notify
    notify = 1
  end
  from = set_var('hipchat.from', :default => 'Gitolite')
  proxy_address = set_var('hipchat.proxyaddress')
  proxy_port = set_var('hipchat.proxyport')

  uri = URI.parse("https://api.hipchat.com/")
  http = Net::HTTP.new(uri.host, uri.port, proxy_address, proxy_port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Post.new("/v1/rooms/message")

  request.set_form_data({"message" => message,
      "auth_token" => auth_token,
      "room_id" => room,
      "notify" => notify,
      "from" => from })
  response = http.request(request)
end

repository = set_var('repository', :default => File.basename(Dir.getwd, ".git"))
if set_var('redmineurl')
  repo_url = "#{set_var('redmineurl')}/projects/#{set_var('project', :required => true)}/repository/#{repository}/"
  commit_url = repo_url + 'revisions/'
elsif set_var('gitweburl')
  repo_url = "#{set_var('gitweburl')}/#{repository}.git/"
  commit_url = repo_url + "commit/"
elsif set_var('cgiturl')
  repo_url = "#{set_var('cgiturl')}/#{repository}/"
  commit_url = repo_url + "commit/?id="
else
  repo_url = commit_url = nil
end

git = `which git`.strip

# Call to pre-speak hook
load File.join(File.dirname(__FILE__), 'pre-speak') if File.exist?(File.join(File.dirname(__FILE__), 'pre-speak'))

# Write in a file the timestamp of the last commit already posted to the room.
filename = File.join(File.dirname(__FILE__), repository[/[\w.]+/] + ".log")
if File.exist?(filename)
  last_revision = Time.parse(File.open(filename) { |f| f.read.strip })
else
  # TODO: Skip error message if push includes first commit?
  # Commenting out noisy error message for now
  # room.speak("Warning: Couldn't find the previous push timestamp.")
  last_revision = Time.now - 120
end

revtime = last_revision.strftime("%Y %b %d %H:%M:%S %Z")
File.open(filename, "w+") { |f| f.write Time.now.utc }

commit_changes = `#{git} log --abbrev-commit --oneline --since='#{revtime}' --reverse`
unless commit_changes.empty?
  message = "Commits just pushed to "
  if repo_url
    message += "<a href=\"#{repo_url}\">"
  end
  message += repository
  if repo_url
    message += "</a>"
  end
  message += ":<br/>"

  commit_changes.split("\n").each do |commit|
    if commit.strip =~ /^([\da-z]+) (.*)/
      if commit_url
        message += "<a href=\"#{commit_url + $1}\">"
      end
      message += $1
      if commit_url
        message += "</a>"
      end
      message += " #{$2.split("\n").first}<br/>"
    end
  end
  # check nospeak
  unless set_var('hipchat.nospeak', :default => '0') == '1'
    # add notify key check
    speak message, $2.include?(set_var('hipchat.notifykey', :default => '@notify'))
  end
end

# Call to post-speak hook
load File.join(File.dirname(__FILE__), 'post-speak') if File.exist?(File.join(File.dirname(__FILE__), 'post-speak'))
