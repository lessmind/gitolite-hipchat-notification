#!/usr/bin/env ruby

require 'yaml'
require 'time'
require 'net/https'
require 'uri'

# load configs from yml
conffile = File.join(File.dirname(__FILE__), 'config.yml')
if File.exist?(conffile)
  CONFIG = YAML::load(File.open(conffile))
else
  CONFIG = {}
end

# load configs from git config
`$(which git) config -l | grep hooks.hipchat | sed 's/^hooks\.hipchat\.//g'`.split("\n").each do |conf|
  pieces = conf.split('=', 2)
  CONFIG[pieces[0]] = pieces[1]
end

# get config value with default/required flags
def conf name, args = {}
  required = args[:required] ||= false
  default = args[:default] ||= nil
  if CONFIG[name]
    CONFIG[name]
  else
    if required && !default
      $stderr.puts "#{name} not found - exiting"
      exit
    else
      default
    end
  end
end

def speak(message)
  # put message let remote knowing this speak
  print "Sending commits to hipchat...... "
  STDOUT.flush
  # set up http request
  uri = URI.parse('https://api.hipchat.com/')
  http = Net::HTTP.new(uri.host, uri.port, conf('proxyaddress'), conf('proxyport'))
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  # send request
  request = Net::HTTP::Post.new('/v1/rooms/message')
  request.set_form_data({
    'message' => message,
    'auth_token' => conf('apitoken', :required => true),
    'room_id' => conf('room', :required => true),
    'notify' => conf('notify', :default => 0),
    'from' => conf('from', :default => 'Gitolite')
  })
  res = http.request(request)
  case res
  when Net::HTTPSuccess then
      # put message let remote knowing this speak
      puts "sent!"
  else
      abort("error: "+res.code+" "+res.body)
  end
end

def getUrl repo, branch_name
  if conf('redmineurl')
    repo_url = "#{conf('redmineurl')}/projects/#{conf('project', :required => true)}/repository/#{repo}/" +
      "?rev="+URI.encode_www_form_component(branch_name)
    commit_url = repo_url + 'revisions/%H'
  elsif conf('gitweburl')
    repo_url = "#{conf('gitweburl')}/#{repo}.git/"
    commit_url = repo_url + "commit/%H"
  elsif conf('cgiturl')
    repo_url = "#{conf('cgiturl')}/#{repo}/"
    commit_url = repo_url + "commit/?id=%H"
  else
    repo_url = commit_url = nil
  end
  {:repo => repo_url, :commit => commit_url}
end

def commitMessage old_rev, new_rev, branch_name
  # get repo name
  repo = conf('repository', :default => File.basename(Dir.getwd, '.git'))
  # get repo/commit url
  url = getUrl(repo, branch_name)

  if old_rev.match(/^0+$/)
    # new branch: just get the diffs from master
    start_rev = "master"
  else
    start_rev = old_rev
  end
  commit_range = "#{start_rev}..#{new_rev}"
  logs = `$(which git) log #{commit_range} --reverse --format='%an authored <a href="#{url[:commit]}">%h</a> %ad%n<b>%s</b>%n%b'`
 
  msg = "Commits just pushed to <a href=\"#{url[:repo]}\">#{repo}:#{branch_name}</a>:<br>" + logs

  # remove last newline, nl2br
  msg = msg.chomp.gsub("\r", '').gsub("\n", '<br>')

  # replace redmine issue url
  if conf('redmineurl')
    msg.gsub(/#(\d+)/, '<a href="'+ conf('redmineurl') +'/issues/\1">\0</a>')
  end
end


# get commit infos [oldRev, newRev, refHead]
old_rev, new_rev, ref_head = STDIN.read.split(/\s+/)
refmatch = conf('refmatch')
if refmatch && !ref_head.match(refmatch)
  exit
end

# Call to pre-speak hook
load File.join(File.dirname(__FILE__), 'pre-speak') if File.exist?(File.join(File.dirname(__FILE__), 'pre-speak'))

if ref_head.start_with?("refs/heads/")
  ref_head = ref_head[11..-1]
end

# speak
unless conf('silent') == '1'
  #puts commitMessage
  speak commitMessage(old_rev, new_rev, ref_head)
end

# Call to post-speak hook
load File.join(File.dirname(__FILE__), 'post-speak') if File.exist?(File.join(File.dirname(__FILE__), 'post-speak'))
