require_relative 'rerun.rb'
require 'sinatra'
require 'erb'
require 'cgi'

Weekdays = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat']

get '/' do
    erb :home
end

get '/preview' do
    if params[:url] == nil
        redirect to('/'), 302
    end

    backdate = 0
    begin
        backdate = Integer(params[:backdate])
        unless 0 <= backdate and backdate <= 28
            backdate = 0
        end
    rescue
        # no-op, backdate is already 0
    end

    schedule = sched_from(params)
    feed = Rerun.new(params[:url],
                     DateTime.now - backdate,
                     schedule)
    feed.shift_entries

    rss_url = 'http://localhost:4567/rerun?url=' +  CGI::escape(params[:url])
    rss_url += '&startDate=' + (DateTime.now - backdate).strftime('%F')
    schedule.chars {|c| rss_url += '&' + Weekdays[c.to_i]}
    erb :preview, :locals => {:items => feed.preview_feed,
                              :feed_url => params[:url],
                              :rerun_url => rss_url}
end

get '/rerun' do
    startDate = nil
    begin
        startDate = DateTime.parse(params[:startDate])
    rescue
        startDate = DateTime.now
    end

    feed = Rerun.new(params[:url], startDate, sched_from(params))
    feed.shift_entries
    return feed.to_xml
end

def sched_from(params)
    retstr = ''
    Weekdays.each_with_index do |day, i|
        if params.has_key?(day)
            retstr += String(i)
        end
    end
    return retstr
end
