require 'config_for'

module ApiConfig
  def config_for(file)
    ConfigFor.load_config!('config', file, environment)
  end

  def environment
    ENV["RACK_ENV"] || 'development' # sinatra sets environment this way too
  end
end