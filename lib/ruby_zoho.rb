require 'zoho_api_configuration'

class RubyZoho

  def initialize(config_file_path)
    ZohoApiConfiguration.new(config_file_path)
  end

end
