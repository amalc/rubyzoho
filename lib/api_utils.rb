require 'rexml/document'

module ApiUtils

  def self.camelize_with_space(str)
    new_str = str.split('_').map do |w|
      if w == 'of'
        w
      else
        w.capitalize
      end
    end
    new_str.join(' ')
  end

  def self.string_to_method_name(s)
    s.gsub(' ', '_').downcase
  end

  def self.string_to_symbol(s)
    s.gsub!(/[()%]*/, '')
    s.gsub(' ', '_').downcase.to_sym
  end

  def self.symbol_to_string(sym)
    sym.class == Symbol ? self.camelize_with_space(sym.to_s) : self.camelize_with_space(sym)
  end

end
