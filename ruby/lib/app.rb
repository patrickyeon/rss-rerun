require_relative 'rerun.rb'
require 'sinatra'
require 'erb'
require 'cgi'

get '/' do
    erb :home
end

get '/preview' do
    if params[:url] == nil
        redirect to('/'), 302
    end

    feed = Rerun.new(params[:url], params[:startDate], params[:schedule] || '0')
    feed.shift_entries

    rss_url = 'http://localhost:4567/rerun?url=' +  CGI::escape(params[:url])
    rss_url += '&startTime=' + (DateTime.now - 9).rfc822
    erb :preview, :locals => {:items => feed.preview_feed,
                              :feed_url => params[:url],
                              :rerun_url => rss_url}
end

get '/rerun' do
    feed = Rerun.new(params[:url], DateTime.parse(params[:startTime]))
    feed.shift_entries
    feed.to_xml
end
