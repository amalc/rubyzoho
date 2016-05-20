$:.unshift File.join('..', File.dirname(__FILE__), 'lib')

require 'httmultiparty'
require 'rexml/document'
require 'net/http/post/multipart'
require 'net/https'
require 'mime/types'
require 'ruby_zoho'
require 'yaml'
require 'api_utils'
require 'zoho_api_field_utils'
require 'zoho_api_finders'

module ZohoApi


  include ApiUtils

  class Crm

    include HTTMultiParty
    include ZohoApiFieldUtils
    include ZohoApiFinders

    #debug_output $stderr

    attr_reader :auth_token, :module_fields

    def initialize(auth_token, modules, ignore_fields, fields = nil)
      @auth_token = auth_token
      @modules = %w(Accounts Contacts Events Leads Potentials Tasks Users).concat(modules).uniq
      @module_fields = fields.nil? ? reflect_module_fields : fields
      @ignore_fields = ignore_fields
    end

    def add_record(module_name, fields_values_hash)
      x = REXML::Document.new
      element = x.add_element module_name
      row = element.add_element 'row', {'no' => '1'}
      fields_values_hash.each_pair { |k, v| add_field(row, k, v, module_name) }
      r = self.class.post(create_url(module_name, 'insertRecords'),
                          :query => {:newFormat => 1, :authtoken => @auth_token,
                                     :scope => 'crmapi', :xmlData => x, :wfTrigger => 'true'},
                          :headers => {'Content-length' => '0'})
      check_for_errors(r)
      x_r = REXML::Document.new(r.body).elements.to_a('//recorddetail')
      to_hash(x_r, module_name)[0]
    end

    def attach_file(module_name, record_id, file_path, file_name)
      mime_type = (MIME::Types.type_for(file_path)[0] || MIME::Types['application/octet-stream'][0])
      url_path = create_url(module_name, "uploadFile?authtoken=#{@auth_token}&scope=crmapi&id=#{record_id}")
      url = URI.parse(create_url(module_name, url_path))
      io = UploadIO.new(file_path, mime_type, file_name)
      req = Net::HTTP::Post::Multipart.new url_path, 'content' => io
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      res = http.start do |h|
        h.request(req)
      end
      raise(RuntimeError, "[RubyZoho] Attach of file #{file_path} to module #{module_name} failed.") unless res.code == '200'
      res.code
    end

    def check_for_errors(response)
      raise(RuntimeError, "Web service call failed with #{response.code}") unless response.code == 200
      x = REXML::Document.new(response.body)

      # updateRelatedRecords returns two codes one in the status tag and another in a success tag, we want the
      # code under the success tag in this case
      code = REXML::XPath.first(x, '//success/code') || code = REXML::XPath.first(x, '//code')

      # 4422 code is no records returned, not really an error
      # TODO: find out what 5000 is
      # 4800 code is returned when building an association. i.e Adding a product to a lead. Also this doesn't return a message
      raise(RuntimeError, "Zoho Error Code #{code.text}: #{REXML::XPath.first(x, '//message').text}.") unless code.nil? || ['4422', '5000', '4800'].index(code.text)

      return code.text unless code.nil?
      response.code
    end

    def create_url(module_name, api_call)
      "https://crm.zoho.com/crm/private/xml/#{module_name}/#{api_call}"
    end

    def delete_record(module_name, record_id)
      post_action(module_name, record_id, 'deleteRecords')
    end

    def first(module_name)
      some(module_name, 1, 1)
    end

    def method_name?(n)
      return /[@$"]/ !~ n.inspect
    end

    def post_action(module_name, record_id, action_type)
      r = self.class.post(create_url(module_name, action_type),
                          :query => {:newFormat => 1, :authtoken => @auth_token,
                                     :scope => 'crmapi', :id => record_id},
                          :headers => {'Content-length' => '0'})
      raise('Adding contact failed', RuntimeError, r.response.body.to_s) unless r.response.code == '200'
      check_for_errors(r)
    end

    def primary_key(module_name)
      activity_keys = {'Tasks' => :activityid, 'Events' => :activityid, 'Calls' => :activityid}
      return activity_keys[module_name] unless activity_keys[module_name].nil?
      (module_name.downcase.chop + 'id').to_sym
    end

    def primary_key?(module_name, field_name)
      return nil if field_name.nil? || module_name.nil?
      fn = field_name.class == String ? field_name : field_name.to_s
      return true if fn == 'id'
      return true if %w[Calls Events Tasks].index(module_name) && fn.downcase == 'activityid'
      fn.downcase.gsub('id', '') == module_name.chop.downcase
    end

    def related_id?(module_name, field_name)
      field = field_name.to_s
      return false if field.rindex('id').nil?
      return false if %w[Calls Events Tasks].index(module_name) && field_name.downcase == 'activityid'
      field.downcase.gsub('id', '') != module_name.chop.downcase
    end

    def related_records(parent_module, parent_record_id, related_module)
      r = self.class.get(create_url("#{related_module}", 'getRelatedRecords'),
                         :query => {:newFormat => 1, :authtoken => @auth_token, :scope => 'crmapi',
                                    :parentModule => parent_module, :id => parent_record_id})

      x = REXML::Document.new(r.body).elements.to_a("/response/result/#{related_module}/row")
      check_for_errors(r)
      to_hash(x, related_module)
    end

    def download_file(parent_module, attachment_id)
      self.class.get(create_url("#{parent_module}", 'downloadFile'),
        :query => {:authtoken => @auth_token, :scope => 'crmapi', :id => attachment_id})
    end

    def some(module_name, index = 1, number_of_records = nil, sort_column = :id, sort_order = :asc, last_modified_time = nil)
      r = self.class.get(create_url(module_name, 'getRecords'),
                         :query => {:newFormat => 2, :authtoken => @auth_token, :scope => 'crmapi',
                                    :sortColumnString => sort_column, :sortOrderString => sort_order,
                                    :lastModifiedTime => last_modified_time,
                                    :fromIndex => index, :toIndex => index + (number_of_records || NUMBER_OF_RECORDS_TO_GET) - 1})
      return nil unless r.response.code == '200'
      check_for_errors(r)
      x = REXML::Document.new(r.body).elements.to_a("/response/result/#{module_name}/row")
      to_hash(x, module_name)
    end

    def update_related_records(parent_module, parent_record_id, related_module_fields)
      x = REXML::Document.new
      leads = x.add_element related_module_fields[:related_module]
      row = leads.add_element 'row', {'no' => '1'}
      related_module_fields[:xml_data].each_pair { |k, v| add_field(row, k, v, parent_module) }

      r = self.class.post(create_url("#{parent_module}", 'updateRelatedRecords'),
                          :query => {:newFormat => 1,
                                     :id => parent_record_id,
                                     :authtoken => @auth_token, :scope => 'crmapi',
                                     :relatedModule => related_module_fields[:related_module],
                                     :xmlData => x, :wfTrigger => 'true'},
                          :headers => {'Content-length' => '0'})

      check_for_errors(r)
    end

    def update_record(module_name, id, fields_values_hash)
      x = REXML::Document.new
      contacts = x.add_element module_name
      row = contacts.add_element 'row', {'no' => '1'}
      fields_values_hash.each_pair { |k, v| add_field(row, k, v, module_name) }
      r = self.class.post(create_url(module_name, 'updateRecords'),
                          :query => {:newFormat => 1, :authtoken => @auth_token,
                                     :scope => 'crmapi', :id => id,
                                     :xmlData => x, :wfTrigger => 'true'},
                          :headers => {'Content-length' => '0'})
      check_for_errors(r)
      x_r = REXML::Document.new(r.body).elements.to_a('//recorddetail')
      to_hash_with_id(x_r, module_name)[0]
    end

    def users(user_type = 'AllUsers')
      return @@users unless @@users == [] || user_type == 'Refresh'
      r = self.class.get(create_url('Users', 'getUsers'),
                         :query => {:newFormat => 1, :authtoken => @auth_token, :scope => 'crmapi',
                                    :type => 'AllUsers'})
      check_for_errors(r)
      result = extract_users_from_xml_response(r)
      @@users = result
    end

    def extract_users_from_xml_response(response)
      x = REXML::Document.new(response.body).elements.to_a('/users')
      result = []
      x.each do |e|
        e.elements.to_a.each do |node|
          record = extract_user_name_and_attribs(node)
          result << record
        end
      end
      result
    end

    def extract_user_name_and_attribs(node)
      record = {}
      record.merge!({:user_name => node.text})
      node.attributes.each_pair do |k, v|
        record.merge!({k.to_s.to_sym => v.to_string.match(/'(.*?)'/).to_s.gsub('\'', '')})
      end
      record
    end

    def valid_related?(module_name, field)
      return nil if field.downcase == 'smownerid'
      valid_relationships = {
          'Leads' => %w(email),
          'Accounts' => %w(accountid accountname),
          'Contacts' => %w(contactid accountid vendorid email),
          'Potentials' => %w(potentialid accountid campaignid contactid potentialname),
          'Campaigns' => %w(campaignid campaignname),
          'Cases' => %w(caseid productid accountid potentialid),
          'Solutions' => %w(solutionid productid),
          'Products' => %w(productid vendorid productname),
          'Purchase Order' => %w(purchaseorderid contactid vendorid),
          'Quotes' => %w(quoteid potentialid accountid contactid),
          'Sales Orders' => %w(salesorderid potentialid accountid contactid quoteid),
          'Invoices' => %w(invoiceid accountid salesorderid contactid),
          'Vendors' => %w(vendorid vendorname),
          'Tasks' => %w(taskid),
          'Events' => %w(eventid),
          'Notes' => %w(notesid)
      }
      valid_relationships[module_name].index(field.downcase)
    end

  end

end

