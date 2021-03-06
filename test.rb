#!/usr/bin/ruby

# https://github.com/zendesk/zendesk_api_client_rb


require 'zendesk_api'
require 'yaml'
require 'json'

conf = YAML.load_file('zenconfig.yml')

# config - setting up connections to your zendesk

client = ZendeskAPI::Client.new do |config|
  config.url = conf['url']
  config.username = conf['user']
  config.token = conf['token']
end

current_user = client.users.find(:id => 'me')
puts current_user["name"]
puts current_user.name

# admins = client.users.page(2).per_page(3)
# admins = client.users.find(:role => 'admin')
admins = client.users.search(:role => "admin")
# puts admins.each { |name| }
admins.each do |admin|
  puts "Admin:\t#{admin.name}\t#{admin.email}"
end

agents = client.users.search(:role => "agent")
# puts admins.each { |name| }
agents.each do |agent|
  puts "Agent:\t#{agent.name}\t#{agent.email}"
end

# t = client.search(query: "status:open schedule").count
# puts t
