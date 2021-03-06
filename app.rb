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

  post '/add' do
    return "unautorized." if params["token"] != ENV["SLACK_LOG_PAYLOAD_TOKEN"]

    # analyze params
    team = params["team_domain"]
    user = params["user_name"]
    text = params["text"][0..140]

    add_item(team, user, text)

    "#{text} was added."
  end

  post '/clear' do
    return "unautorized." if params["token"] != ENV["SLACK_CLEAR_PAYLOAD_TOKEN"]

    # analyze params
    team = params["team_domain"]
    user = params["user_name"]

    # retrieve & orginize data
    daily_log = generate_log(team, user)

    # remove records
    clear(team, user)

    "#{daily_log}\n\nWork log is clean. Have a nice day! :bowtie:"
  end

  get '/list' do
    return "unautorized." if params["token"] != ENV["SLACK_LIST_PAYLOAD_TOKEN"]

    # analyze params
    team = params["team_domain"]
    user = params["user_name"]

    generate_log(team, user)
  end

  def clear(team, user)
    keys = "#{team}:#{user}:slack-logger:*"
    $redis = Redis.new(url: ENV["REDIS_URL"])
    $redis.keys(keys).each { |key| $redis.del key }
  end

  def add_item(team, user, text)
    redis_key = "#{team}:#{user}:slack-logger:#{text}"

    $redis = Redis.new(url: ENV["REDIS_URL"])
    $redis.set redis_key, "0"
  end

  def generate_log(team, user)
    $redis = Redis.new(url: ENV["REDIS_URL"])
    data = $redis.keys("#{team}:#{user}:*")
    by_category = sort_by_category data
    report = daily_log_formatter by_category
    report.empty? ? "You worklog is empty! :bowtie:" : report
  end

  def sort_by_category(tasks_log)
    tasks = {}
    tasks_log.each do |task|
      split = task.split(":")
      tasks["#{split[2]}"] = [] if tasks["#{split[2]}"].nil?
      tasks["#{split[2]}"] << split[3]
    end
    tasks
  end

  def daily_log_formatter(log_by_category)
    report = ""
    sources = log_by_category.keys
    sources.each do |source|
      tasks = log_by_category["#{source}"]
      report << "#{source}:\n"
      tasks.each {|t| report << "\t#{t}\n"}
      report << "\n"
    end
    report
  end
end