require 'sinatra'
require 'redis-objects'
require 'json'

class Metric
  include Redis::Objects
  sorted_set :stat
  def initialize k
    @id = k
  end
  def id; @id; end
  def up k
    self.stat.incr(k)
  end
  def dn k
    self.stat.decr(k)
  end
  def to_h
    self.stat.members(with_scores: true).to_h
  end
end

configure do
  set :port, 8081
  set :bind, '0.0.0.0'
  set :views, 'views/'
  set :public_folder, 'public/'
end

before do
  Metric.new(:referer).up request.referer
  Metric.new(:agent).up request.user_agent
  Metric.new(:route).up request.path_info
  Redis.new.publish "App.#{request.request_method}", "#{request.fullpath} #{params}"
end

get '/' do
  erb :index
end
get '/call' do
  erb :call
end
not_found do
  h = {
    method: request.request_method,
    host: request.host,
    port: request.port,
    path: request.path_info,
    referer: request.referer,
    agent: request.user_agent,
    params: params
  }
  t = Time.now.utc.to_i
  Redis::Set.new("404s") << t
  Redis::HashKey.new("404")[t] = JSON.generate(h)
  Redis.new.publish "404.#{t}", JSON.generate(h)
end
