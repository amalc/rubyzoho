require 'zoho_api_configuration'

class RubyZoho

  attr_reader :auth_token

  def initialize(config_file_path)
    @z_api = ZohoApiConfiguration.new(config_file_path)
    raise('Authorization token not found.', RuntimeError, config_file_path) if @z_api.auth_token.nil?
    @auth_token = @z_api.auth_token
  end

end
