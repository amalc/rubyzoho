$:.unshift File.join('..', File.dirname(__FILE__), 'lib')

require 'httmultiparty'
require 'rexml/document'
require 'net/http/post/multipart'
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

    #debug_output $stderr

    attr_reader :auth_token, :module_fields

    def initialize(auth_token, modules)
      @auth_token = auth_token
      @modules = modules
      @module_fields = reflect_module_fields
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
      raise('Adding record failed', RuntimeError, r.response.body.to_s) unless r.response.code == '200'
      r.response.code
    end

    def add_field(row, field, value)
      r = (REXML::Element.new 'FL')
      r.attributes['val'] = field
      r.add_text(value)
      row.elements << r
      row
    end

    def attach_file(module_name, record_id, file_path)
      r = self.class.post(create_url(module_name, 'uploadFile'),
          :query => { :newFormat => 1, :authtoken => @auth_token,
            :scope => 'crmapi',
            :id => record_id, :content => File.open(file_path) },
          :headers => { 'Content-length' => '0' })
      pp r.code
      pp r.body
      raise(RuntimeError, 'Attaching file failed.', r.body.to_s) unless r.response.code == '200'
      r.code
    end

    def add_file(module_name, record_id, file_path)
      url = URI.parse(create_url(module_name, 'uploadFile'))
      r = nil
      pp record_id
      mime_type = (MIME::Types.type_for(file_path)[0] || MIME::Types["application/octet-stream"][0])
      f = File.open(file_path)
      req = Net::HTTP::Post::Multipart.new url.path,
      { 'authtoken' => '@auth_token', 'scope' => 'crmapi',
        'id' => record_id,
        'content' => UploadIO.new(f, mime_type, File.basename(file_path)) }
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      pp req.to_hash
      r = http.start { |http| http.request(req) }
      pp r.body.to_s
      (r.nil? or r.body.nil? or r.body.empty?) ? nil : REXML::Document.new(r.body).to_s
    end

    def to_byte_array(num)
      result = []
      begin
        result << (num & 0xff)
        num >>= 8
      end until (num == 0 || num == -1) && (result.last[7] == num[7])
      result.reverse
    end

    def check_for_errors(response)
      return
      raise(RuntimeError, 'Exceeded API calls.') unless response.body.to_s.index('You crossed your API search limit').nil?
      response
    end

    def create_url(module_name, api_call)
      "https://crm.zoho.com/crm/private/xml/#{module_name}/#{api_call}"
    end

    def delete_record(module_name, record_id)
      r = self.class.post(create_url(module_name, 'deleteRecords'),
        :query => { :newFormat => 1, :authtoken => @auth_token,
          :scope => 'crmapi', :id => record_id },
        :headers => { 'Content-length' => '0' })
      raise('Adding contact failed', RuntimeError, r.response.body.to_s) unless r.response.code == '200'
      check_for_errors(r)
    end

    def fields(module_name)
      mod_name = ApiUtils.string_to_symbol(module_name)
      return @@module_fields[mod_name] unless @@module_fields[mod_name].nil?
      r = self.class.post(create_url(module_name, 'getFields'),
          :query => { :authtoken => @auth_token, :scope => 'crmapi' },
          :headers => { 'Content-length' => '0' })
      @@module_fields[mod_name] = []
      x = REXML::Document.new(r.body)
      REXML::XPath.each(x, "/#{module_name}/section/FL/@dv") do |f|
        field = ApiUtils.string_to_symbol(f.to_s)
        @@module_fields[mod_name] << field if method_name?(field)
      end
      raise('Getting fields failed', RuntimeError, module_name) unless r.response.code == '200'
      check_for_errors(r)
      @@module_fields[mod_name] << ApiUtils.string_to_symbol(module_name.chop + 'id')
      @@module_fields
    end

    def first(module_name)
      some(module_name, 1, 1)
    end

    def find_records(module_name, field, condition, value)
      sc_field = ApiUtils.symbol_to_string(field)
      sc_field.rindex('id').nil? ? find_record_by_field(module_name, sc_field, condition, value) :
          find_record_by_id(module_name, value)
    end

    def find_record_by_field(module_name, sc_field, condition, value)
      search_condition = '(' + sc_field + '|' + condition + '|' + value + ')'
      r = self.class.get(create_url("#{module_name}", 'getSearchRecords'),
                         :query => {:newFormat => 1, :authtoken => @auth_token, :scope => 'crmapi',
                                    :selectColumns => 'All', :searchCondition => search_condition,
                                    :fromIndex => 1, :toIndex => NUMBER_OF_RECORDS_TO_GET})
      raise(RuntimeError, 'Bad query', "#{sc_field} #{condition} #{value}") unless r.body.index('<error>').nil?
      check_for_errors(r)
      x = REXML::Document.new(r.body).elements.to_a("/response/result/#{module_name}/row")
      to_hash(x)
    end

    def find_record_by_id(module_name, id)
      r = self.class.get(create_url("#{module_name}", 'getRecordById'),
         :query => { :newFormat => 1, :authtoken => @auth_token, :scope => 'crmapi',
                     :selectColumns => 'All', :id => id})
      raise(RuntimeError, 'Bad query', "#{module_name} #{id}") unless r.body.index('<error>').nil?
      check_for_errors(r)
      x = REXML::Document.new(r.body).elements.to_a("/response/result/#{module_name}/row")
      to_hash(x)
    end

    def method_name?(n)
      return /[@$"]/ !~ n.inspect
    end

    def reflect_module_fields
      @modules.each { |m| fields(m) }
      @@module_fields
    end

    def related_records(module_name, id)
      r = self.class.get(create_url("#{module_name}", 'getRelatedRecords'),
         :query => { :newFormat => 1, :authtoken => @auth_token, :scope => 'crmapi',
                     :parentModule => module_name, :id => id})
      raise(RuntimeError, 'Bad query for related records', module_name) unless r.body.index('<error>').nil?
      check_for_errors(r)
      x = REXML::Document.new(r.body).elements.to_a("/response/result/#{module_name}/row")
      puts "====="
      pp x.each { |i| i.to_s }
    end

    def some(module_name, index = 1, number_of_records = nil)
      r = self.class.get(create_url(module_name, 'getRecords'),
        :query => { :newFormat => 1, :authtoken => @auth_token, :scope => 'crmapi',
          :fromIndex => index, :toIndex => number_of_records || NUMBER_OF_RECORDS_TO_GET })
      return nil unless r.response.code == '200'
      check_for_errors(r)
      x = REXML::Document.new(r.body).elements.to_a("/response/result/#{module_name}/row")
      to_hash(x)
    end

    def to_hash(xml_results)
      r = []
      xml_results.each do |e|
        record = {}
        e.elements.to_a.each do |n|
          k = ApiUtils.string_to_symbol(n.attribute('val').to_s.gsub('val=', ''))
          v = n.text == 'null' ? nil : n.text
          record.merge!({ k => v })
        end
        r << record
      end
      return nil if r == []
      r
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
      raise('Updating record failed', RuntimeError, r.response.body.to_s) unless r.response.code == '200'
      r.response.code
    end

  end

end
