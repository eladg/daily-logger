# load environment
require 'dotenv'
require 'pry'
require 'json'
require 'redis'
Dotenv.load

# sinatra & global dependancies
require 'sinatra'

class ExceptionHandling
  def initialize(app)
    @app = app
  end
 
  def call(env)
    begin
      @app.call env
    rescue => ex
      env['rack.errors'].puts ex
      env['rack.errors'].puts ex.backtrace.join("\n")
      env['rack.errors'].flush 
      
      hash = { message: ex.to_s, app_backtrace: app_backtrace(ex)}
      
      # log
      # pm_to_user hash

      [500, {'Content-Type' => 'application/json'}, [ex.to_s]]
    end
  end

  def pm_to_user(hash)
    # unimplemented
  end

  def app_backtrace(ex)
    ex.backtrace.select { |path| path[/rvm|rbenv|\/app\/vendor\/bundle/].nil? }
  end
end

class SlackLogger < Sinatra::Application
  set :environment, :production

  set :root,                File.dirname(__FILE__)
  set :public_folder,       Proc.new { File.join(root, "app", "public") }
  set :views,               Proc.new { File.join(root, "app", "templates") }
  set :static,              true

  # disable errors because we are handling them ourselves
  set :dump_errors,         false
  set :raise_errors,        true
  set :show_exceptions,     false

  configure :development do
    # maybe sometime in the future
  end

  helpers do
    include Rack::Utils
    alias_method :h, :escape_html
  end

  post '/log' do
    $redis = Redis.new(url: ENV["HEROKU_REDIS_MAROON_URL"])
    $redis.set "last_params", params.to_json
  end

  # get '/pry' do
  #   puts "prying>>>"
  #   binding.pry
  #   puts "<<<prying"
  # end

end