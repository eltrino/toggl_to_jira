#!/usr/bin/ruby 
require 'net/https'
require 'uri'
require 'cgi'
require 'rubygems'
require 'json'
require 'yaml'
require 'time'
require 'rest_client'

def req_toggl(uri, token)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  request = Net::HTTP::Get.new(uri.request_uri)
  request.basic_auth(token, 'api_token')

  response = http.request(request)
  begin
    json = JSON.parse(response.body)
    raise unless json
  rescue
    puts 'Request to toggl failed'
    puts $!
    puts response.inspect
    exit(1)
  end

  return json
end

CONFIG = YAML.load_file(File.expand_path(File.dirname(__FILE__)) + '/config.yml') unless defined? CONFIG
CONFIG['start_time'] ||= Time.now.beginning_of_day.iso8601
CONFIG['start_time'] = CONFIG['start_time'].days.ago.iso8601 if CONFIG['start_time'].is_a?(Fixnum)
uri = URI.parse("https://www.toggl.com/api/v8/time_entries?start_date=#{CGI.escape(CONFIG['start_time'])}" +
                    (CONFIG['end_time'].empty? ? '' : "&end_date=#{CGI.escape(CONFIG['end_time'])}"))

puts "https://www.toggl.com/api/v8/time_entries?start_date=#{CGI.escape(CONFIG['start_time'])}" +
         (CONFIG['end_time'].empty? ? '' : "&end_date=#{CGI.escape(CONFIG['end_time'])}")

puts "Connecting to toggl starting from #{CONFIG['start_time']}"
entries = req_toggl(uri, CONFIG['toggl_key'])
puts "Got #{entries.length} entries from toggl"

IMPORTED_FILE = File.expand_path(File.dirname(__FILE__)) + '/imported.yml'
imported = (YAML.load_file(IMPORTED_FILE) rescue [])

entries.each do |entry|
  id = entry['id']
  start = Time.parse(entry['start'])
  duration = entry['duration'].to_i
  desc = entry['description'] || ''
  if entry['pid']
    uri = URI.parse("https://www.toggl.com/api/v8/projects/#{entry['pid']}")
    project = req_toggl(uri, CONFIG['toggl_key'])
    raise('Invalid data received from Toggl') unless project['data']
    desc += " #{project['data']['name']}" if project['data']['name']
  end
  jira_key = $1 if desc =~ /([A-Z]+-\d+)/
  jira_url = CONFIG['jira_url'] + "/rest/api/2/issue/#{jira_key}/worklog"

  if imported.include?(id)
    puts "Skip #{jira_key} '#{desc}' as it was already imported"
  elsif entry['duration'].to_i < 0
    puts "Skip #{jira_key} '#{desc}' as it's still running"
  elsif entry['duration'].to_i < 60
    puts "Skip #{jira_key} '#{desc}' as its duration is less than 1 minute"
  elsif jira_key.nil?
    puts "Skip #{jira_key} '#{desc}' as it doesn't have a JIRA ticket key"
  else
    comment = "#{desc} , generated from toggl_to_jira script"
    startDate = start.localtime.strftime('%b %e, %l:%M %p')
    timeSpent = (duration / 60.0).round
    puts "Add worklog #{timeSpent} from #{startDate} to ticket #{jira_key} #{desc}"
    #jira rest request here

    worklog = {
        :comment => comment,
        :started => (start.strftime "%FT%T.%L%z"),
        :timeSpent => "#{timeSpent}m"
    }

    request = RestClient::Request.new(
        :url => jira_url,
        :method => :post,
        :user => CONFIG['jira_user'],
        :password => CONFIG['jira_pass'],
        :headers => {
            :accept => "application/json",
            :content_type => "application/json"
        },
        :payload => worklog.to_json
    )

    begin
      response = JSON.parse(request.execute)

      if !response['id']
        raise("Bad response from JIRA")
      end

      imported.push id
      imported.shift if imported.size > 500 # avoid imported list increasing infinitely
      File.open(IMPORTED_FILE, 'w') { |f| f.write(imported.to_yaml) }

    rescue
      puts $!
    end
  end
end
