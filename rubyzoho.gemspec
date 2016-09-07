Gem::Specification.new do |s|
  s.name = 'rubyzoho'
  s.version = '0.7.0'

  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=
  s.authors = ['amalc']
  s.date = '2015-02-23'
  s.description = 'A set of Ruby classes supporting the ActiveRecord lifecycle for the Zoho CRM API.'
  s.email = 'amalc@github.com'
  s.extra_rdoc_files = %w(LICENSE.txt README.rdoc)
  s.files = %w(
    .coverall.yml .document .rspec .travis.yml Gemfile
    LICENSE.txt README.rdoc Rakefile lib/api_utils.rb lib/crm.rb lib/crud_methods.rb
    lib/ruby_zoho.rb lib/zoho_api.rb lib/zoho_api_field_utils.rb lib/zoho_api_finders.rb
    lib/zoho_crm_users.rb lib/zoho_crm_utils.rb rubyzoho.gemspec spec/api_utils_spec.rb
    spec/fixtures/sample.pdf spec/fixtures/sample_contact.xml spec/fixtures/sample_contact_search.xml
    spec/fixtures/sample_contacts.xml spec/fixtures/sample_contacts_list.xml
    spec/fixtures/sample_leads_list.xml spec/ruby_zoho_spec.rb spec/spec_helper.rb spec/zoho_api_spec.rb
  )
  s.homepage = 'http://github.com/amalc/rubyzoho'
  s.licenses = ['MIT']
  s.platform = Gem::Platform::RUBY
  s.require_paths = ['lib']
  s.required_ruby_version = '>= 1.9.3'
  s.summary = 'A set of Ruby classes supporting the ActiveRecord lifecycle for the Zoho API. Supports Rails and Devise.'

  s.add_runtime_dependency(%q<activemodel>, ['>= 3.0'])
  s.add_runtime_dependency(%q<httmultiparty>, ['>= 0.3'])
  s.add_runtime_dependency(%q<roxml>, ['>= 1.0'])
  s.add_runtime_dependency(%q<multipart-post>, ['>= 1.0'])
  s.add_runtime_dependency(%q<mime-types>, ['>= 2.6'])
  s.add_development_dependency(%q<bundler>, ['>= 1.2'])
  s.add_development_dependency(%q<holepicker>, ['>= 1.0'])
  s.add_development_dependency(%q<rdoc>, ['>= 3.12'])
  s.add_development_dependency(%q<rspec>, ['>= 2.12'])
  s.add_development_dependency(%q<vcr>, ['>= 1.0'])
  s.add_development_dependency(%q<webmock>, ['>= 1.0'])
  s.add_development_dependency(%q<xml-simple>, ['>= 1.1'])
end

