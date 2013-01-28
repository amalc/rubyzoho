require 'yaml'
require 'ruby_zoho'

class ZohoApiConfiguration

  attr_reader :config_file_path

  def initialize(config_file_path)
    @config_file_path = config_file_path
    raise('Zoho configuration file not found', RuntimeError, config_file_path) unless
        File.exist?(config_file_path)
    @params = YAML.load(File.open(config_file_path))
  end

  def params
    @params
  end

end