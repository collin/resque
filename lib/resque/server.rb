require 'sinatra/base'

require 'haml'
require 'sass'
require 'compass'

require 'resque'
require 'resque/version'

class Numeric
  def humanize
    to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1,")
  end
end

module Resque
  class Server < Sinatra::Base
    
    dir = File.dirname(File.expand_path(__FILE__))

    set :views,  "#{dir}/server/views"
    set :sass,   "#{dir}/server/sass"
    set :public, "#{dir}/server/public"
    set :static, true

    configure do
       Compass.configuration do |config|
          config.project_path = File.dirname(__FILE__)
          config.sass_dir = 'views'
        end

        set :haml, { :format => :html5 }
        set :sass, Compass.sass_engine_options
      end

    helpers do
      include Rack::Utils
      alias_method :h, :escape_html

      def current_section
        url request.path_info.sub('/','').split('/')[0].downcase
      end

      def current_page
        url request.path_info.sub('/','').downcase
      end

      def url(*path_parts)
        [ path_prefix, path_parts ].join("/").squeeze('/')
      end
      alias_method :u, :url

      def path_prefix
        request.env['SCRIPT_NAME']
      end

      def class_if_current(page = '')
        {:class => :current} if current_page.include? page.to_s
      end

      def tab(name)
        dname = name.to_s.downcase
        "<li #{class_if_current(dname)}><a href='#{url dname}'>#{name}</a></li>"
      end

      def tabs
        Resque::Server.tabs
      end

      def redis_get_size(key)
        case Resque.redis.type(key)
        when 'none'
          []
        when 'list'
          Resque.redis.llen(key).to_i
        when 'set'
          Resque.redis.scard(key).to_i
        when 'string'
          Resque.redis.get(key).length.to_i
        end
      end

      def redis_get_value_as_array(key)
        case Resque.redis.type(key)
        when 'none'
          []
        when 'list'
          Resque.redis.lrange(key, 0, 20)
        when 'set'
          Resque.redis.smembers(key)
        when 'string'
          [Resque.redis.get(key)]
        end
      end

      def show_args(args)
        Array(args).map { |a| a.inspect }.join("\n")
      end

      def partial?
        @partial
      end

      def partial(template, local_vars = {})
        @partial = true
        haml(template.to_sym, {:layout => false}, local_vars)
      ensure
        @partial = false
      end
      
    end

    def show(page, layout = true)
      begin
        haml page.to_sym, {:layout => layout}, :resque => Resque
      rescue Errno::ECONNREFUSED
        haml :error, {:layout => false}, :error => "Can't connect to Redis! (#{Resque.redis.server})"
      end
    end

    # to make things easier on ourselves
    get "/?" do
      redirect url(:overview)
    end

    %w( overview queues working workers pool key ).each do |page|
      get "/#{page}" do
        show page
      end

      get "/#{page}/:id" do
        show page
      end
    end
    
    delete "/queues/:id" do |id|
      queue = Resque::Queue.new(id)
      return "WontDeleteNonEmptyQueu" if queue.any?
      queue.delete
      "OK"
    end

    get "/failed" do
      if Resque::Failure.url
        redirect Resque::Failure.url
      else
        show :failed
      end
    end
    
    post "/failed/clear" do
      Resque::Failure.clear
      redirect url('failed')
    end

    post "/reschedule/:key" do
      Resque::FailureQueue.new(params[:key]).reschedule
      "OK"
    end

    post "/concurrency/:level" do |level|
      throw :halt, [404, "Not Found"] unless level[/\d*/]
      Resque.concurrency_level = level
      "OK"
    end

    get "/stats" do
      redirect url("/stats/resque")
    end

    get "/stats/:id" do
      show :stats
    end

    get "/stats/keys/:key" do
      show :stats
    end

    get "/stats.txt" do
      info = Resque.info

      stats = []
      stats << "resque.pending=#{info[:pending]}"
      stats << "resque.processed+=#{info[:processed]}"
      stats << "resque.failed+=#{info[:failed]}"
      stats << "resque.workers=#{info[:workers]}"
      stats << "resque.working=#{info[:working]}"

      Resque.queues.each do |queue|
        stats << "queues.#{queue}=#{Resque.size(queue)}"
      end

      content_type 'text/plain'
      stats.join "\n"
    end

    get '/screen.css' do
      content_type 'text/css', :charset => 'utf-8'
      sass :screen
    end

    def resque
      Resque
    end

    def self.tabs
      @tabs ||= ["Overview", "Working", "Failed", "Queues", "Workers", "Stats"]
    end
  end
end
