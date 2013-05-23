$:.unshift File.join('..', File.dirname(__FILE__), 'lib')

require 'httmultiparty'
require 'rexml/document'
require 'net/http/post/multipart'
require 'net/https'
require 'mime/types'
require 'ruby_zoho'
require 'yaml'
require 'api_utils'

module ZohoApi

  include ApiUtils

  class Crm
    NUMBER_OF_RECORDS_TO_GET = 200

    include HTTMultiParty

    @@module_fields = {}
    @@users = []

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
      row = element.add_element 'row', { 'no' => '1'}
      fields_values_hash.each_pair { |k, v| add_field(row, ApiUtils.symbol_to_string(k), v) }
      r = self.class.post(create_url(module_name, 'insertRecords'),
          :query => { :newFormat => 1, :authtoken => @auth_token,
                      :scope => 'crmapi', :xmlData => x },
          :headers => { 'Content-length' => '0' })
      check_for_errors(r)
      x_r = REXML::Document.new(r.body).elements.to_a('//recorddetail')
      to_hash(x_r, module_name)[0]
    end

    def add_field(row, field, value)
      r = (REXML::Element.new 'FL')
      adjust_tag_case(field)
      r.attributes['val'] = adjust_tag_case(field)
      r.add_text("#{value}")
      row.elements << r
      row
    end

    def adjust_tag_case(tag)
      return tag if tag == 'id'
      return tag.upcase if tag.downcase.rindex('id')
      u_tags = %w[SEMODULE]
      return tag.upcase if u_tags.index(tag.upcase)
      tag
    end

    def attach_file(module_name, record_id, file_path, file_name)
      mime_type = (MIME::Types.type_for(file_path)[0] || MIME::Types["application/octet-stream"][0])
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
      code =  REXML::XPath.first(x, '//code')
      raise(RuntimeError, "Zoho Error Code #{code.text}: #{REXML::XPath.first(x, '//message').text}.") unless
          code.nil? || ['4422', '5000'].index(code.text)
      return code.text unless code.nil?
      response.code
    end

    def clean_field_name?(field_name)
      return false if field_name.nil?
      r = field_name[/[0-9, a-z, A-Z, _]*/]
      field_name.size == r.size
    end

    def create_url(module_name, api_call)
      "https://crm.zoho.com/crm/private/xml/#{module_name}/#{api_call}"
    end

    def delete_record(module_name, record_id)
      post_action(module_name, record_id, 'deleteRecords')
    end

    def fields(module_name)
      return user_fields if module_name == 'Users'
      fields_from_record(module_name).nil? ? fields_from_api(module_name) : fields_from_record(module_name)
    end

    def fields_original(module_name)
      return nil if @@module_fields.nil?
      #return user_fields if module_name == 'Users'
      @@module_fields[module_name + '_original_name']
    end

    def fields_from_api(module_name)
      mod_name = ApiUtils.string_to_symbol(module_name)
      return @@module_fields[mod_name] unless @@module_fields[mod_name].nil?
      r = self.class.post(create_url(module_name, 'getFields'),
          :query => { :authtoken => @auth_token, :scope => 'crmapi' },
          :headers => { 'Content-length' => '0' })
      check_for_errors(r)
      update_module_fields(mod_name, module_name, r)
    end

    def fields_from_record(module_name)
      mod_name = ApiUtils.string_to_symbol(module_name)
      return @@module_fields[mod_name] unless @@module_fields[mod_name].nil?
      r = first(module_name)
      return nil if r.nil?
      @@module_fields[mod_name] = r.first.keys
      @@module_fields[mod_name]
    end

    def first(module_name)
      some(module_name, 1, 1)
    end

    def find_records(module_name, field, condition, value)
      sc_field = field == :id ? primary_key(module_name) : ApiUtils.symbol_to_string(field)
      return find_record_by_related_id(module_name, sc_field, value) if related_id?(module_name, sc_field)
      primary_key?(module_name, sc_field) == false ? find_record_by_field(module_name, sc_field, condition, value) :
          find_record_by_id(module_name, value)
    end

    def find_record_by_field(module_name, sc_field, condition, value)
      field = sc_field.rindex('id') ? sc_field.downcase : sc_field
      search_condition = '(' + field + '|' + condition + '|' + value + ')'
      r = self.class.get(create_url("#{module_name}", 'getSearchRecords'),
                         :query => {:newFormat => 1, :authtoken => @auth_token, :scope => 'crmapi',
                                    :selectColumns => 'All', :searchCondition => search_condition,
                                    :fromIndex => 1, :toIndex => NUMBER_OF_RECORDS_TO_GET})
      check_for_errors(r)
      x = REXML::Document.new(r.body).elements.to_a("/response/result/#{module_name}/row")
      to_hash(x, module_name)
    end

    def find_record_by_id(module_name, id)
      r = self.class.get(create_url("#{module_name}", 'getRecordById'),
         :query => { :newFormat => 1, :authtoken => @auth_token, :scope => 'crmapi',
                     :selectColumns => 'All', :id => id})
      raise(RuntimeError, 'Bad query', "#{module_name} #{id}") unless r.body.index('<error>').nil?
      check_for_errors(r)
      x = REXML::Document.new(r.body).elements.to_a("/response/result/#{module_name}/row")
      to_hash(x, module_name)
    end

    def find_record_by_related_id(module_name, sc_field, value)
      raise(RuntimeError, "[RubyZoho] Not a valid query field #{sc_field} for module #{module_name}") unless
          valid_related?(module_name, sc_field)
      field = sc_field.downcase
      r = self.class.get(create_url("#{module_name}", 'getSearchRecordsByPDC'),
         :query => { :newFormat => 1, :authtoken => @auth_token, :scope => 'crmapi',
             :selectColumns => 'All', :version => 2, :searchColumn => field,
             :searchValue => value})
      check_for_errors(r)
      x = REXML::Document.new(r.body).elements.to_a("/response/result/#{module_name}/row")
      to_hash(x, module_name)
    end

    def hashed_field_value_pairs(module_name, n, record)
      field_name = n.attribute('val').to_s.gsub('val=', '')
      if @ignore_fields == true
        return clean_field_name?(field_name) == true ?
            create_and_add_field_value_pair(field_name, module_name, n, record)
                : nil
      end
      create_and_add_field_value_pair(field_name, module_name, n, record)
    end

    def create_and_add_field_value_pair(field_name, module_name, n, record)
      k = ApiUtils.string_to_symbol(field_name)
      v = n.text == 'null' ? nil : n.text
      r = record.merge({k => v})
      r = r.merge({:id => v}) if primary_key?(module_name, k)
      r
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
      activity_keys = { 'Tasks' => :activityid, 'Events' => :activityid, 'Calls' => :activityid }
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

    def reflect_module_fields
      @modules.each { |m| fields(m) }
      @@module_fields
    end

    def related_records(parent_module, parent_record_id, related_module)
      r = self.class.get(create_url("#{related_module}", 'getRelatedRecords'),
         :query => { :newFormat => 1, :authtoken => @auth_token, :scope => 'crmapi',
                     :parentModule => parent_module, :id => parent_record_id})

      x = REXML::Document.new(r.body).elements.to_a("/response/result/#{parent_module}/row")
      check_for_errors(r)
    end

    def some(module_name, index = 1, number_of_records = nil)
      r = self.class.get(create_url(module_name, 'getRecords'),
        :query => { :newFormat => 2, :authtoken => @auth_token, :scope => 'crmapi',
          :fromIndex => index, :toIndex => number_of_records || NUMBER_OF_RECORDS_TO_GET })
      return nil unless r.response.code == '200'
      check_for_errors(r)
      x = REXML::Document.new(r.body).elements.to_a("/response/result/#{module_name}/row")
      to_hash(x, module_name)
    end

    def to_hash(xml_results, module_name)
      r = []
      xml_results.each do |e|
        record = {}
        record[:module_name] = module_name
        e.elements.to_a.each do |n|
          record = hashed_field_value_pairs(module_name, n, record)
        end
        r << record unless record.nil?
      end
      return nil if r == []
      r
    end

    def to_hash_with_id(xml_results, module_name)
      to_hash(xml_results, module_name)
    end

    def update_module_fields(mod_name, module_name, response)
      @@module_fields[mod_name] = []
      @@module_fields[(mod_name.to_s + '_original_name').to_sym] = []
      extract_fields_from_response(mod_name, module_name, response)
      return @@module_fields[mod_name] unless @@module_fields.nil?
      nil
    end

    def extract_fields_from_response(mod_name, module_name, response)
      x = REXML::Document.new(response.body)
      REXML::XPath.each(x, "/#{module_name}/section/FL/@dv") do |f|
        field = ApiUtils.string_to_symbol(f.to_s)
        @@module_fields[mod_name] << field if method_name?(field)
        @@module_fields[(mod_name.to_s + '_original_name').to_sym] << field
      end
      @@module_fields[mod_name] << ApiUtils.string_to_symbol(module_name.chop + 'id')
    end

    def update_record(module_name, id, fields_values_hash)
      x = REXML::Document.new
      contacts = x.add_element module_name
      row = contacts.add_element 'row', { 'no' => '1'}
      fields_values_hash.each_pair { |k, v| add_field(row, ApiUtils.symbol_to_string(k), v) }
      r = self.class.post(create_url(module_name, 'updateRecords'),
          :query => { :newFormat => 1, :authtoken => @auth_token,
                      :scope => 'crmapi', :id => id,
                      :xmlData => x },
          :headers => { 'Content-length' => '0' })
      check_for_errors(r)
      x_r = REXML::Document.new(r.body).elements.to_a('//recorddetail')
      to_hash_with_id(x_r, module_name)[0]
    end

    def user_fields
      @@module_fields[:users] = users[0].keys
    end

    def users(user_type = 'AllUsers')
      return @@users unless @@users == [] || user_type == 'Refresh'
      r = self.class.get(create_url('Users', 'getUsers'),
          :query => { :newFormat => 1, :authtoken => @auth_token, :scope => 'crmapi',
              :type => 'AllUsers' })
      check_for_errors(r)
      result = extract_users_from_xml_response(r)
      @@users = result
    end

    def extract_users_from_xml_response(response)
      x = REXML::Document.new(response.body).elements.to_a("/users")
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
        record.merge!({k.to_s.to_sym => v.to_string.match(/'(.*?)'/).to_s.gsub("'", '')})
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
