require_relative 'rerun.rb'
require 'sinatra'
require 'erb'

get '/' do
    'foobar'
end

get '/rerun' do
    feed = Rerun.new(params[:url], DateTime.now - 9)
    feed.shift_entries

    erb :preview, :locals => {:items => feed.preview_feed,
                              :feed_url => params[:url]}
end
