require 'httparty'
require "ruby_zoho"

class ZohoCrm < RubyZoho
  include HTTParty

  def create_url(module_name, api_call)
    "https://crm.zoho.com/crm/private/xml/#{module_name}/#{api_call}"
  end

  def leads
    response = HTTParty.get(create_url('Leads', "getRecords"), :body =>
       { :newFormat => '1', :authtoken => @auth_token, :scope => 'crmapi' })
  end

  def lead=
    response = get(create_url('Leads', "getRecords"), :body =>
       {:newFormat => '1', :authtoken => @auth_token, :scope => 'crmapi', :xmlData => xml_data})
  end

end
