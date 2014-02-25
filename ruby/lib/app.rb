require_relative 'rerun.rb'
require 'sinatra'
require 'erb'
require 'cgi'

get '/' do
    feed = Rerun.new(params[:url], DateTime.now - 9)
    feed.shift_entries

    rss_url = 'http://localhost:4567/rerun.rss?url=' +  CGI::escape(params[:url])
    rss_url += '&startTime=' + (DateTime.now - 9).rfc822
    erb :preview, :locals => {:items => feed.preview_feed,
                              :feed_url => params[:url],
                              :rerun_url => rss_url}
end

get '/rerun.rss' do
    feed = Rerun.new(params[:url], DateTime.parse(params[:startTime]))
    feed.shift_entries
    feed.to_xml
end
