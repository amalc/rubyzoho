module ZohoApiFieldUtils

  @@module_fields = {}
  @@users = []

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
    return tag.upcase if tag.downcase.end_with?('id')
    u_tags = %w[SEMODULE]
    return tag.upcase if u_tags.index(tag.upcase)
    tag
  end

  def clean_field_name?(field_name)
    return false if field_name.nil?
    r = field_name[/[0-9, a-z, A-Z, _]*/]
    field_name.size == r.size
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

  def hashed_field_value_pairs(module_name, n, record)
    field_name = n.attribute('val').to_s.gsub('val=', '')
    if @ignore_fields == true
      return clean_field_name?(field_name) == true ?
          create_and_add_field_value_pair(field_name, module_name, n, record)
      : record
    end
    create_and_add_field_value_pair(field_name, module_name, n, record)
  end

  def create_and_add_field_value_pair(field_name, module_name, n, record)
    k = ApiUtils.string_to_symbol(field_name)
    v = n.text == 'null' ? nil : n.text
    r = record.merge({ k => v })
    r = r.merge({ :id => v }) if primary_key?(module_name, k)
    r
  end

  def reflect_module_fields
    @modules.each { |m| fields(m) }
    @@module_fields
  end

  def extract_fields_from_response(mod_name, module_name, response)
    x = REXML::Document.new(response.body)
    REXML::XPath.each(x, "/#{module_name}/section/FL/@dv") do |field|
      extract_field(field, mod_name)
    end
    @@module_fields[mod_name] << ApiUtils.string_to_symbol(module_name.chop + 'id')
  end

  def extract_field(f, mod_name)
    field = ApiUtils.string_to_symbol(f.to_s)
    @@module_fields[mod_name] << field if method_name?(field)
    @@module_fields[(mod_name.to_s + '_original_name').to_sym] << field
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

  def user_fields
    @@module_fields[:users] = users[0].keys
  end

end