require 'net/http'
require 'json'
require 'optparse'
require 'paint'
require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'net/http'   

# get your own guidebox API Key: https://api.guidebox.com/production-key
# set the api key as an environment var (e.g. shell:  $ export GUIDEBOX_API_KEY=foobar123abc)
# don't publish API key to version control
api_key = ENV["GUIDEBOX_API_KEY"]


#get movie name from user 
if ARGV.count > 0
	title = ARGV.join("%20")
else 
	puts "Enter the movie you want to stream"
	title = gets.chomp.gsub(/\s/, "%20")
end

# API formating:
# Guidebox URL for GET request for TV show search:
# base_URL + key + search/title/Arrested%20Development/fuzzy

# Guidebox URL for GET request for movie search:
# base_URL + key + search/movie/title/Stranger%20Than%20Fiction/fuzzy


#GET request to search by movie title 
url = "http://api-public.guidebox.com/v1.43/us/#{api_key}/search/movie/title/#{title}/fuzzy/" 
uri = URI(url)
response = Net::HTTP.get(uri)
search_results = JSON.parse(response)["results"][0]

# vars you will need from response
guidebox_id = 0
title = ""
release_year = 0
imdb = ""

# rottentomatoes id is for request to scrape RT site with Nokogiri 
rt_id = 0

#parse GET response to set movie variables
search_results.each_pair do |k, v|
	guidebox_id = v if k == "id"
	title = v if k == "title"
	release_year = v if k == "release_year"
	rt_id = v if k == "rottentomatoes"
	imdb = v if k == "imdb"
end

# DRY code by refactoring to use proc for API calls 
# def http_request(uri)
#   Net::HTTP.start(uri.host, uri.port) do |http|
#     yield(http, uri)
#   end
# end

# uri = URI 'http://localhost:4567/'

# http_request(uri) do |http, uri|
#   http.get(uri.path).body
# end

#use Nokogiri to scrape RT movie scores
rt_url = "https://www.rottentomatoes.com/m/#{rt_id}" 
page = Nokogiri::HTML(open(rt_url))   

all_ratings = page.css('.meter')

ratings = []
all_ratings.each do |s|
  ratings << s.text.gsub(/\D/,'')
end

#set critic score from Nokogiri scraping
all_critics, top_critics, audience = ratings[0], ratings[1], ratings[2]

#Paint gem readme: https://github.com/janlelis/paint
#set print color based on RT score
all_critics.to_i >= 60 ? (critic_color = "green") : (critic_color = "red")
top_critics.to_i >= 60 ? (top_critic_color = "green") : (top_critic_color = "red")
audience.to_i >= 60 ? (audience_color = "green") : (audience_color = "red")

#print movie title, year, and imdb link
puts Paint[title, :bright] 
puts release_year
puts "www.imdb.com/title/#{imdb}"
puts 

#print RT scores
puts Paint["Rottentomatoes", :bright]
puts "All Critics:  " + Paint["#{all_critics}%", critic_color, :bright]
puts "Top Critics:  " + Paint["#{top_critics}%", top_critic_color, :bright]
puts "Audience:  " + Paint["#{audience}%", audience_color, :bright]
puts 
puts Paint["Streaming Options", :bright]

#make GET request for streaming locations
url = "http://api-public.guidebox.com/v1.43/US/#{api_key}/movie/#{guidebox_id}?sources=all"
uri = URI(url)
response = Net::HTTP.get(uri)
complete_results = JSON.parse(response)

sources = []
links = []
prices = []

# parse results to find streaming options 
complete_results["purchase_web_sources"].each do |k, v|
	k.each do |k2, v2|
		sources << v2 if k2 == "display_name"
		links << v2 if k2 == "link"
		
		if k2 == "formats" 
			prices << v2[0].fetch("price")  
		end

	end
end

# print streaming options
i = 0
while i <= sources.count-1
	puts "Source: #{sources[i]}"
	puts "Link: #{links[i]}"
	puts "Price: $#{prices[i]}"
	puts " "
i += 1
end



