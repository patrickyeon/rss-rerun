require_relative 'rerun.rb'
require_relative 'feed.rb'
require_relative 'chrono.rb'
require_relative 'store.rb'
require 'sinatra'
require 'erb'
require 'cgi'

Weekdays = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat']
DEBUG = true

configure do
    unless DEBUG
        disable :show_exceptions
    end
end

get '/' do
    erb :home
end

get '/preview' do
    if params[:url] == nil
        redirect to('/'), 302
    end

    feedurl = safe_url(params[:url])
    unless whitelisted?(feedurl)
        return erb :request, :locals => {:feed_url => feedurl}
    end

    backdate = 0
    begin
        backdate = Integer(params[:backdate])
        # arbitrarily, limit how long ago the feed can start
        unless 0 <= backdate and backdate <= 28
            backdate = 0
        end
    rescue
        backdate = 0
    end

    schedule = sched_from(params)

    begin
        feed = Timeout::timeout(35) {
            # timeout arbitrarily chosen
            archive = Archive.new(S3Store.new(ENV['AMAZON_ACCESS_KEY_ID'],
                                              ENV['AMAZON_SECRET_ACCESS_KEY'],
                                              ENV['AMAZON_S3_BUCKET']))
            origfeed = Feed.new(feedurl, archive)
            Rerun.new(origfeed, Chrono.now - backdate, schedule)
        }
    rescue Exception => e
        if DEBUG
            raise e
        end
        # error out, made for timeouts but will also get triggered for eg. 404
        # TODO something should really be done about a status code
        return erb :timeout, :locals => {:feed_url => feedurl}
    end

    rss_url = 'rerun?url=' +  CGI::escape(feedurl)
    rss_url += '&startDate=' + (Chrono.now - backdate).strftime('%F')
    schedule.chars {|c| rss_url += '&' + Weekdays[c.to_i]}
    if params.has_key?('archive')
        rss_url += '&archive'
    end
    erb :preview, :locals => {:items => feed.preview_feed,
                              :feed_url => feedurl,
                              :rerun_url => rss_url}
end

get '/rerun' do
    feedurl = safe_url(params[:url])
    unless whitelisted?(feedurl)
        return erb :request, :locals => {:feed_url => feedurl}
    end

    startDate = nil
    begin
        startDate = DateTime.parse(params[:startDate])
    rescue
        startDate = Chrono.now
    end

    begin
        feed = Timeout::timeout(35) {
            archive = Archive.new(S3Store.new(ENV['AMAZON_ACCESS_KEY_ID'],
                                              ENV['AMAZON_SECRET_ACCESS_KEY'],
                                              ENV['AMAZON_S3_BUCKET']))
            origfeed = Feed.new(feedurl, archive)
            Rerun.new(origfeed, startDate, sched_from(params))
        }
    rescue Exception => e
        if DEBUG
            raise e
        end
        # TODO seeing as this is expected to be a feed, I think it would be more
        #   appropriate to signal a temporary error status
        #   Just setting status to 404 triggers the not_found page, which is not
        #   what I want to do
        return erb :timeout, :locals => {:feed_url => params[:url]}
    end

    return feed.to_xml
end

get '/magic_req' do
    require 'pg'
    db = nil
    db = PG.connect(:host     => ENV['POSTGRES_HOST'],
                    :port     => 5432,
                    :dbname   => ENV['POSTGRES_DB_NAME'],
                    :user     => ENV['POSTGRES_USER'],
                    :password => ENV['POSTGRES_PASS'])
    db.exec_params("INSERT INTO requests (email, url, type, tstamp, noisy)
                    VALUES ($1, $2, $3, 'now', $4)",
                   [params[:contact], params['request_url'], 'archive',
                    params.has_key?('more_info')])
    db.close

    erb :magic
end

not_found do
    status 404
    erb :fourohfour
end

error do
    erb :error, :locals => {:exception => env['sinatra.error'],
                            :url => request.url}
end

def sched_from(params)
    # map the http GET args like '&mon=&tue=&thu=' to a string of ints, 0=Sun
    retstr = ''
    Weekdays.each_with_index do |day, i|
        if params.has_key?(day)
            retstr += i.to_s
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

def whitelisted?(url)
    # for now it's just the amp hour
    return /^http:\/\/(www.)?theamphour.com\/feed\/?$/.match(url) != nil
end
