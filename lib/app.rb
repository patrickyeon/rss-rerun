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

    feed = Rerun.new(params[:url],
                     DateTime.parse(params[:startDate]),
                     sched_from(params))
    feed.shift_entries

    rss_url = 'http://localhost:4567/rerun?url=' +  CGI::escape(params[:url])
    rss_url += '&startDate=' + (DateTime.now - 9).rfc822
    erb :preview, :locals => {:items => feed.preview_feed,
                              :feed_url => params[:url],
                              :rerun_url => rss_url}
end

get '/rerun' do
    feed = Rerun.new(params[:url],
                     DateTime.parse(params[:startDate]),
                     '0123')
                     #sched_from(params))
    feed.shift_entries
    feed.to_xml
end

def sched_from(params)
    retstr = ''
    ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'].each_with_index do |day, i|
        if params.has_key?(day)
            retstr += String(i)
        end
    end
    retstr
end
