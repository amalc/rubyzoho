require 'yaml'
require 'ruby_zoho'

class ZohoApiConfiguration

  def initialize(config_file_path)
    raise('Zoho configuration file not found', RuntimeError, config_file_path) unless
        File.exist?(config_file_path)
    YAML.load(config_file_path)
  end



end