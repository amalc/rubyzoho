module ZohoApiFinders
  NUMBER_OF_RECORDS_TO_GET = 200

  def find_records(module_name, field, condition, value)
    sc_field = field == :id ? primary_key(module_name) : ApiUtils.symbol_to_string(field)
    related_id?(module_name, sc_field)
    return find_record_by_related_id(module_name, sc_field, value) if related_id?(module_name, sc_field)
    primary_key?(module_name, sc_field) == false ? find_record_by_field(module_name, sc_field, condition, value) :
        find_record_by_id(module_name, value)
  end

  def find_record_by_field(module_name, sc_field, condition, value)
    field = sc_field.rindex('id') ? sc_field.downcase : sc_field
    search_condition = "(#{field}:#{value})"
    r = self.class.get(create_url("#{module_name}", 'searchRecords'),
                       :query => { :newFormat => 1, :authtoken => @auth_token, :scope => 'crmapi',
                                   :selectColumns => 'All', :criteria => search_condition,
                                   :fromIndex => 1, :toIndex => NUMBER_OF_RECORDS_TO_GET })
    check_for_errors(r)
    x = REXML::Document.new(r.body).elements.to_a("/response/result/#{module_name}/row")
    to_hash(x, module_name)
  end

  def find_record_by_id(module_name, id)
    r = self.class.get(create_url("#{module_name}", 'getRecordById'),
                       :query => { :newFormat => 1, :authtoken => @auth_token, :scope => 'crmapi',
                                   :selectColumns => 'All', :id => id })
    raise(RuntimeError, 'Bad query', "#{module_name} #{id}") unless r.body.index('<error>').nil?
    check_for_errors(r)
    x = REXML::Document.new(r.body).elements.to_a("/response/result/#{module_name}/row")
    to_hash(x, module_name)
  end

  def find_record_by_related_id(module_name, sc_field, value, from_index=1, to_index=NUMBER_OF_RECORDS_TO_GET)
    raise(RuntimeError, "[RubyZoho] Not a valid query field #{sc_field} for module #{module_name}") unless valid_related?(module_name, sc_field)
    field = sc_field.downcase
    r = self.class.get(create_url("#{module_name}", 'getSearchRecordsByPDC'),
                       :query => { :newFormat => 1, :authtoken => @auth_token, :scope => 'crmapi',
                                   :selectColumns => 'All', :version => 2, :searchColumn => field,
                                   :searchValue => value,
                                   :fromIndex => from_index, :toIndex => to_index })
    check_for_errors(r)
    x = REXML::Document.new(r.body).elements.to_a("/response/result/#{module_name}/row")
    to_hash(x, module_name)
  end

end
