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
        backdate = 0
    end

    schedule = sched_from(params)

    feedurl = safe_url(params[:url])

    feed = Rerun.new(feedurl, DateTime.now - backdate, schedule)

    rss_url = 'http://localhost:4567/rerun?url=' +  CGI::escape(feedurl)
    rss_url += '&startDate=' + (DateTime.now - backdate).strftime('%F')
    schedule.chars {|c| rss_url += '&' + Weekdays[c.to_i]}
    erb :preview, :locals => {:items => feed.preview_feed,
                              :feed_url => feedurl,
                              :rerun_url => rss_url}
end

get '/rerun' do
    startDate = nil
    begin
        startDate = DateTime.parse(params[:startDate])
    rescue
        startDate = DateTime.now
    end

    feed = Rerun.new(safe_url(params[:url]), startDate, sched_from(params))
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

def safe_url(url)
    # this seems to be a little heavy-handed, but I think it'll prevent the
    #   worst trouble from eg. directory traversal.
    returl = ''
    if [URI::HTTP, URI::HTTPS].include? URI.parse(url).class
        returl = url
    else
        returl = 'http://' + url
    end

    return returl
end
