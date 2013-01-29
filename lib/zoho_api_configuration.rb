require 'yaml'
require '../lib/ruby_zoho'

class ZohoApiConfiguration

  attr_reader :auth_token, :config_file_path

  def initialize(config_file_path)
  end

  def params
    @params
  end

end