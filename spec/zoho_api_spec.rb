$:.unshift File.join('..', File.dirname(__FILE__), 'lib')

require 'spec_helper'
#noinspection RubyResolve
require 'zoho_api'
require 'xmlsimple'
require 'yaml'
require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/vcr'
  c.hook_into :webmock
  c.default_cassette_options = {:record => :all}
  # c.debug_logger = File.open('log/vcr_debug.log', 'w')
end

describe ZohoApi do
  # Reset this to zero when running with VCR
  SLEEP_INTERVAL = 15

  def add_dummy_contact
    VCR.use_cassette 'api_response/add_dummy_contact' do
      c = {:first_name => 'BobDifficultToMatch', :last_name => 'SmithDifficultToMatch',
           :email => 'bob@smith.com'}
      @zoho.add_record('Contacts', c)
      sleep(SLEEP_INTERVAL * 2)
    end
  end

  def delete_dummy_contact
    VCR.use_cassette 'api_response/delete_dummy_contact' do
      c = @zoho.find_records(
          'Contacts', :email, '=', 'bob@smith.com')
      @zoho.delete_record('Contacts', c[0][:contactid]) unless c == []
      sleep(30)
    end
  end

  def init_api(api_key, base_path, modules)
    zoho = nil
    VCR.use_cassette 'api_response/init_api' do
      ignore_fields = true
      if File.exists?(File.join(base_path, 'fields.snapshot'))
        #noinspection RubyResolve
        fields = YAML.load(File.read(File.join(base_path, 'fields.snapshot')))
        zoho = ZohoApi::Crm.new(api_key, modules, ignore_fields, fields)
      else
        zoho = ZohoApi::Crm.new(api_key, modules, ignore_fields)
        fields = zoho.module_fields
        File.open(File.join(base_path, 'fields.snapshot'), 'wb') { |file| file.write(fields.to_yaml) }
      end
    end
    zoho
  end

  before(:all) do
    VCR.use_cassette('api_response/initialization') do
      base_path = File.join(File.dirname(__FILE__), 'fixtures')
      @sample_pdf = File.join(base_path, 'sample.pdf')
      modules = %w(Accounts Contacts Events Leads Tasks Potentials)
      @zoho = init_api(ENV['ZOHO_API_KEY'].strip, base_path, modules)
      @h_smith = {:first_name => 'Robert',
                  :last_name => 'Smith',
                  :email => 'rsmith@smithereens.com',
                  :department => 'Waste Collection and Management',
                  :phone => '13452129087',
                  :mobile => '12341238790'
      }
      contacts = @zoho.find_records('Contacts', :email, '=', @h_smith[:email])
      contacts.each { |c| @zoho.delete_record('Contacts', c[:contactid]) } unless contacts.nil?
    end
  end

  it 'should add a new contact' do
    VCR.use_cassette 'api_response/add_contact' do
      @zoho.add_record('Contacts', @h_smith)
      contacts = @zoho.find_records('Contacts', :email, '=', @h_smith[:email])
      while contacts.nil?
        sleep(SLEEP_INTERVAL)
        contacts = @zoho.find_records('Contacts', :email, '=', @h_smith[:email])
      end
      contacts.should_not eq(nil)
      @zoho.delete_record('Contacts', contacts[0][:contactid])
      # contacts.count.should eq(1)
    end
  end
  
  it 'should add a new event' do
    pending
    VCR.use_cassette 'api_response/add_event' do
      @zoho.fields_from_api('Events')
      @zoho.fields_from_record('Events')
      @zoho.some('Events')
      h = {:subject => 'Test Event',
           :start_datetime => '2014-02-16 16:00:00',
           :end_datetime => '2014-02-16 18:00:00'
      }
      @zoho.add_record('Events', h)
      events = @zoho.some('Events')
      events
      #@zoho.delete_record('Contacts', contacts[0][:contactid])
      events.should_not eq(nil)
      events.count.should eq(1)
    end
  end

  it 'should attach a file to a contact record' do
    VCR.use_cassette 'api_response/add_file_to_contact' do
      @zoho.add_record('Contacts', @h_smith)
      contacts = @zoho.find_records('Contacts', :email, '=', @h_smith[:email])
      while contacts.nil?
        sleep(SLEEP_INTERVAL)
        contacts = @zoho.find_records('Contacts', :email, '=', @h_smith[:email])
      end
      @zoho.attach_file('Contacts', contacts[0][:contactid], @sample_pdf, File.basename(@sample_pdf))
      @zoho.delete_record('Contacts', contacts[0][:contactid])
    end
  end

  it 'should attach a file to a potential record' do
    pending
    VCR.use_cassette 'api_response/add_file_to_potential' do
      potential = @zoho.first('Potentials').first
      @zoho.attach_file('Potentials', potential[:potentialid], @sample_pdf, File.basename(@sample_pdf))
      true.should eq(false)
    end
  end

  it 'should delete a contact record with id' do
    VCR.use_cassette 'api_response/delete_contact_with_id' do
      add_dummy_contact
      c = @zoho.find_records('Contacts', :email, '=', 'bob@smith.com')
      while c.nil? do
        sleep(SLEEP_INTERVAL)
        c = @zoho.find_records('Contacts', :email, '=', 'bob@smith.com')
      end
      @zoho.delete_record('Contacts', c[0][:contactid])
    end
  end

  it 'should find by module and field for columns' do
    VCR.use_cassette 'api_response/find_by_module_and_field' do
      add_dummy_contact
      r = @zoho.find_records('Contacts', :email, '=', 'bob@smith.com')
      r[0][:email].should eq('bob@smith.com')
      delete_dummy_contact
    end
  end

  it 'should find by module and id' do
    VCR.use_cassette 'api_response/find_by_module_and_id' do
      add_dummy_contact
      r = @zoho.find_records('Contacts', :email, '=', 'bob@smith.com')
      r[0][:email].should eq('bob@smith.com')
      id = r[0][:contactid]
      c = @zoho.find_record_by_id('Contacts', id)
      c[0][:contactid].should eq(id)
      delete_dummy_contact
    end
  end

  it 'should find by a potential by name,  id and related id' do
    VCR.use_cassette 'api_response' do
      accounts = @zoho.some('Accounts')
      p = {
          :potential_name => 'A very big potential INDEED!!!!!!!!!!!!!',
          :accountid => accounts.first[:accountid],
          :account_name => accounts.first[:account_name],
          :closing_date => '1/1/2014',
          :type => 'New Business',
          :stage => 'Needs Analysis'
      }
      potentials = @zoho.find_records('Potentials', :potential_name, '=', p[:potential_name])
      potentials.map { |r| @zoho.delete_record('Potentials', r[:potentialid]) } unless potentials.nil?

      @zoho.add_record('Potentials', p)
      p1 = @zoho.find_records('Potentials', :potential_name, '=', p[:potential_name])
      while p1.nil?
        sleep(SLEEP_INTERVAL)
        p1 = @zoho.find_records('Potentials', :potential_name, '=', p[:potential_name])
      end
      p1.should_not eq(nil)

      p2 = @zoho.find_records('Potentials', :potentialid, '=', p1.first[:potentialid])
      p2.first[:potentialid].should eq(p1.first[:potentialid])

      p_related = @zoho.find_records('Potentials', :accountid, '=', p[:accountid])
      p_related.first[:accountid].should eq(p[:accountid])

      potentials = @zoho.find_records('Potentials', :potential_name, '=', p[:potential_name])
      potentials.map { |r| @zoho.delete_record('Potentials', r[:potentialid]) } unless potentials.nil?
    end
  end

  it 'should get a list of fields for a module' do
    VCR.use_cassette 'api_response/list_of_fields' do
      r = @zoho.fields('Accounts')
      r.count.should >= 10
      r = @zoho.fields('Contacts')
      r.count.should be >= 10
      r = @zoho.fields('Events')
      r.count.should >= 10
      r = @zoho.fields('Leads')
      r.count.should be >= 10
      r = @zoho.fields('Potentials')
      r.count.should be >= 10
      r = @zoho.fields('Tasks')
      r.count.should >= 10
      r = @zoho.fields('Users')
      r.count.should >= 7
    end
  end

  it 'should get a list of user fields' do
    VCR.use_cassette 'api_response/user_fields' do
      r = @zoho.user_fields
      r.count.should be >= 7
    end
  end

  it 'should get a list of local and remote fields' do
    pending
    VCR.use_cassette 'api_response/remote_fields' do
      @zoho.fields('Accounts')
      r = @zoho.fields_original('Accounts')
      r.count.should >= 10
    end
  end

  it 'should retrieve records by module name' do
    VCR.use_cassette 'api_response/records_by_module_name' do
      r = @zoho.some('Contacts')
      r.should_not eq(nil)
      r.count.should be >= 1
    end
  end

  it 'should return related records by module and id' do
    pending
    VCR.use_cassette 'api_response/records_by_module_and_id' do
      r = @zoho.some('Accounts').first
      true.should eq(false)
      #related = @zoho.related_records('Accounts', r[:accountid], 'Attachments')
    end
  end

  it 'should return calls' do
    pending
    VCR.use_cassette 'api_response/calls' do
      r = @zoho.some('Calls').first
      r.should_not eq(nil)
    end
  end

  it 'should return events' do
    pending
    VCR.use_cassette 'api_response/events' do
      r = @zoho.some('Events').first
      r.should_not eq(nil)
    end
  end

  it 'should return tasks' do
    VCR.use_cassette 'api_response/tasks' do
      r = @zoho.some('Tasks').first
      r.should_not eq(nil)
    end
  end

  it 'should return users' do
    VCR.use_cassette 'api_response/users' do
      r = @zoho.users
      r.should_not eq(nil)
    end
  end

  it 'should test for a primary key' do
    VCR.use_cassette 'api_response/primary_key' do
      @zoho.primary_key?('Accounts', 'accountid').should eq(true)
      @zoho.primary_key?('Accounts', 'potentialid').should eq(false)
      @zoho.primary_key?('Accounts', 'Potential Name').should eq(false)
      @zoho.primary_key?('Accounts', 'Account Name').should eq(false)
      @zoho.primary_key?('Accounts', 'account_name').should eq(false)
    end
  end

  it 'should test for a related id' do
    VCR.use_cassette 'api_response/related_id' do
      @zoho.related_id?('Potentials', 'Account Name').should eq(false)
      @zoho.related_id?('Potentials', 'Accountid').should eq(true)
    end
  end

  it 'should test for a valid related field' do
    VCR.use_cassette 'api_response/valid_related_id' do
      @zoho.valid_related?('Accounts', 'accountid').should_not eq(nil)
      @zoho.valid_related?('Notes', 'notesid').should_not eq(nil)
      @zoho.valid_related?('Accounts', 'email').should eq(nil)
    end
  end

  it 'should do a full CRUD lifecycle on tasks' do
    VCR.use_cassette 'api_response/full_crud_lifecycle' do
      mod_name = 'Tasks'
      fields = @zoho.fields(mod_name)
      fields.count >= 10
      fields.index(:task_owner).should_not eq(nil)
      @zoho.add_record(mod_name, {:task_owner => 'Task Owner', :subject => 'Test Task', :due_date => '2100/1/1'})
      r = @zoho.find_record_by_field('Tasks', 'Subject', '=', 'Test Task')
      while r.nil?
        sleep(SLEEP_INTERVAL)
        r = @zoho.find_record_by_field('Tasks', 'Subject', '=', 'Test Task')
      end
      r.should_not eq(nil)
      r.map { |t| @zoho.delete_record('Tasks', t[:activityid]) }
    end
  end

  it 'should update fields from a record/update_fields_from_record' do
    VCR.use_cassette 'api_response' do
      @zoho.module_fields.count.should be >= 7
    end
  end

  it 'should update a contact' do
    VCR.use_cassette 'api_response/update_contact' do
      @zoho.add_record('Contacts', @h_smith)
      contact = @zoho.find_records('Contacts', :email, '=', @h_smith[:email])
      while contact.nil?
        sleep(SLEEP_INTERVAL)
        contact = @zoho.find_records('Contacts', :email, '=', @h_smith[:email])
      end
      h_changed = {:email => 'robert.smith@smithereens.com'}
      @zoho.update_record('Contacts', contact[0][:contactid], h_changed)
      changed_contact = @zoho.find_records('Contacts', :email, '=', h_changed[:email])
      while changed_contact.nil?
        sleep(SLEEP_INTERVAL)
        changed_contact = @zoho.find_records('Contacts', :email, '=', h_changed[:email])
      end
      changed_contact[0][:email].should eq(h_changed[:email])
      @zoho.delete_record('Contacts', contact[0][:contactid])
    end
  end

  it 'should validate that a field name is clean' do
    VCR.use_cassette 'api_response/clean_field_name' do
      @zoho.clean_field_name?(nil).should eq(false)
      @zoho.clean_field_name?('Name').should eq(true)
      @zoho.clean_field_name?('Full_Name').should eq(true)
      @zoho.clean_field_name?('Name (All Upper)').should eq(false)
    end
  end

  it 'should relate contact with a product' do
    pending
    VCR.use_cassette 'api_response/relate_contact_with_product' do
      contact = @zoho.add_record('Contacts', @h_smith)
      product = @zoho.add_record('Products', {product_name: 'Watches'})

      related_module_params = {related_module: 'Contacts', xml_data: {contactid: contact[:id]}}
      r = @zoho.update_related_records('Products', product[:id], related_module_params)
      r.should eq('4800')

      r = @zoho.related_records('Products', product[:id], 'Contacts')
      r.should eq(200)

      @zoho.delete_record('Contacts', contact[:id])
      @zoho.delete_record('Products', product[:id])
    end
  end

end
