$:.unshift File.join('..', File.dirname(__FILE__), 'lib')

require 'httmultiparty'
require 'rexml/document'
require 'ruby_zoho'
require 'yaml'
require 'api_utils'

module ZohoApi

  include ApiUtils

  class Crm
    NUMBER_OF_RECORDS_TO_GET = 200

    include HTTMultiParty

    debug_output $stderr

    attr_reader :auth_token, :module_fields

    def initialize(auth_token, modules)
      @auth_token = auth_token
      @modules = modules
      @module_fields = reflect_module_fields
    end

    def add_record(module_name, fields_values_hash)
      x = REXML::Document.new
      contacts = x.add_element module_name
      row = contacts.add_element 'row', { 'no' => '1'}
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
      pp module_name
      pp record_id
      bytes = File.open(file_path, "rb") { |file| file.read }
      byte_array = bytes.each_byte { |b| to_byte_array(b) }
      pp bytes.size
      pp byte_array.size
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
      record = first(module_name)
      record[0].keys
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
                         :query => {:newFormat => 2, :authtoken => @auth_token, :scope => 'crmapi',
                                    :selectColumns => 'All', :searchCondition => search_condition,
                                    :fromIndex => 1, :toIndex => NUMBER_OF_RECORDS_TO_GET})
      raise(RuntimeError, 'Bad query', "#{sc_field} #{condition} #{value}") unless r.body.index('<error>').nil?
      check_for_errors(r)
      x = REXML::Document.new(r.body).elements.to_a("/response/result/#{module_name}/row")
      to_hash(x)
    end

    def find_record_by_id(module_name, id)
      r = self.class.get(create_url("#{module_name}", 'getRecordById'),
         :query => { :newFormat => 2, :authtoken => @auth_token, :scope => 'crmapi',
                     :selectColumns => 'All', :id => id})
      raise(RuntimeError, 'Bad query', "#{sc_field} #{condition} #{value}") unless r.body.index('<error>').nil?
      check_for_errors(r)
      x = REXML::Document.new(r.body).elements.to_a("/response/result/#{module_name}/row")
      to_hash(x)
    end

    def reflect_module_fields
      module_names = @modules
      module_fields = {}
      module_names.each { |n| module_fields.merge!({ ApiUtils.string_to_symbol(n) => fields(n) }) }
      module_fields
    end

    def some(module_name, index = 1, number_of_records = nil)
      r = self.class.get(create_url(module_name, 'getRecords'),
        :query => { :newFormat => 2, :authtoken => @auth_token, :scope => 'crmapi',
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
