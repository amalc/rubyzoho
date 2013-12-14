module ZohoCrmUtils

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods

    def create_accessor(klass, names)
      names.each do |name|
        n = name.class == Symbol ? name.to_s : name
        n.gsub!(/[()]*/, '')
        raise(RuntimeError, "Bad field name: #{name}") unless method_name?(n)
        create_getter(klass, n)
        create_setter(klass, n)
      end
      names
    end

    def create_getter(klass, *names)
      names.each do |name|
        klass.send(:define_method, "#{name}") { instance_variable_get("@#{name}") }
      end
    end

    def create_setter(klass, *names)
      names.each do |name|
        klass.send(:define_method, "#{name}=") { |val| instance_variable_set("@#{name}", val) }
      end
    end

    def method_name?(n)
      name = n.class == String ? ApiUtils.string_to_symbol(n) : n
      return /[@$"]/ !~ name.inspect
    end

    def method_is_module?(str_or_sym)
      return nil if str_or_sym.nil?
      s = str_or_sym.class == String ? str_or_sym : ApiUtils.symbol_to_string(str_or_sym)
      possible_module = s[s.length - 1].downcase == 's' ? s : s + 's'
      i = RubyZoho.configuration.crm_modules.index(possible_module.capitalize)
      return str_or_sym unless i.nil?
      nil
    end

  end

  def create_accessor(klass, names)
    names.each do |name|
      n = name.class == Symbol ? name.to_s : name
      n.gsub!(/[()]*/, '')
      raise(RuntimeError, "Bad field name: #{name}") unless self.class.method_name?(n)
      self.class.create_getter(klass, n)
      self.class.create_setter(klass, n)
    end
    names
  end

  def update_or_create_attrs(object_attribute_hash)
    retry_counter = object_attribute_hash.count
    begin
      object_attribute_hash.map { |(k, v)| public_send("#{k}=", v) }
    rescue NoMethodError => e
      m = e.message.slice(/`(.*?)=/)
      create_accessor(self.class, [m.gsub(/[`()]*/, '').chop]) unless m.nil?
      retry_counter -= 1
      retry if retry_counter > 0
    end
  end

  def attr_writers
    self.methods.grep(/\w=$/)
  end

  def run_create_accessor(klass, meth)
    method = meth.to_s.chop.to_sym
    RubyZoho::Crm.create_accessor(klass, [method])
    nil
  end

end