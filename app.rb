require 'sinatra'
require 'redis'

configure do
  set :port, 8081
  set :bind, '0.0.0.0'
  set :views, 'views/'
  set :public_folder, 'public/'
end

before do
  @metrics[:referer].up request.referer
  @metrics[:agent].up request.user_agent
  @metrics[:route].up request.path_info
  Redis.new.publish "App.#{request.request_method}", "#{request.fullpath} #{params}"
end

get '/' do
  erb :index
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
