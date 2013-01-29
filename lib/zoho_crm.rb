require 'httparty'
require "ruby_zoho"

class ZohoCrm < RubyZoho
  include HTTParty

  # debug_output $stderr

  def create_url(module_name, api_call)
    "https://crm.ruby_zoho.com/crm/private/xml/#{module_name}/#{api_call}"
  end

  def contacts
    r = self.class.get(create_url('Contacts', "getRecords"),
      :query => { :newFormat => 1, :authtoken => @auth_token, :scope => 'crmapi' })
    return r.body if r.response.code == "200"
    nil
  end

  def leads
    r = self.class.get(create_url('Leads', "getRecords"),
      :query => { :newFormat => 1, :authtoken => @auth_token, :scope => 'crmapi' })
    return r.body if r.response.code == "200"
    nil
  end

  def lead=
    response = get(create_url('Leads', "getRecords"), :body =>
       {:newFormat => '1', :authtoken => @auth_token, :scope => 'crmapi', :xmlData => xml_data})
  end

end
