$:.unshift File.join('..', File.dirname(__FILE__), 'lib')

require 'spec_helper'
require 'zoho_api'
require 'xmlsimple'
require 'yaml'

describe ZohoApi do

  def add_dummy_contact
    c = {:first_name => 'BobDifficultToMatch', :last_name => 'SmithDifficultToMatch',
         :email => 'bob@smith.com'}
    @zoho.add_record('Contacts', c)
  end

  def delete_dummy_contact
    c = @zoho.find_records(
        'Contacts', :email, '=', 'bob@smith.com')
    @zoho.delete_record('Contacts', c[0][:contactid]) unless c == []
  end

  def init_api(api_key, base_path, modules)
    if File.exists?(File.join(base_path, 'fields.snapshot'))
      fields = YAML.load(File.read(File.join(base_path, 'fields.snapshot')))
      zoho = ZohoApi::Crm.new(api_key, modules, fields)
    else
      zoho = ZohoApi::Crm.new(api_key, modules)
      fields = zoho.module_fields
      File.open(File.join(base_path, 'fields.snapshot'), 'wb') { |file| file.write(fields.to_yaml) }
    end
    zoho
  end

  before(:all) do
    base_path = File.join(File.dirname(__FILE__), 'fixtures')
    @sample_pdf = File.join(base_path, 'sample.pdf')
    modules = ['Accounts', 'Contacts', 'Events', 'Leads', 'Tasks', 'Potentials']
    @zoho = init_api(ENV['ZOHO_API_KEY'].strip, base_path, modules)
    @h_smith = { :first_name => 'Robert',
          :last_name => 'Smith',
          :email => 'rsmith@smithereens.com',
          :department => 'Waste Collection and Management',
          :phone => '13452129087',
          :mobile => '12341238790'
    }
    contacts = @zoho.find_records('Contacts', :email, '=', @h_smith[:email])
    contacts.each { |c| @zoho.delete_record('Contacts', c[:contactid]) } unless contacts.nil?
  end

  it 'should add a new contact' do
    @zoho.add_record('Contacts', @h_smith)
    contacts = @zoho.find_records('Contacts', :email, '=', @h_smith[:email])
    @zoho.delete_record('Contacts', contacts[0][:contactid])
    contacts.should_not eq(nil)
    contacts.count.should eq(1)
  end
  
  it 'should add a new event' do
    pending
    pp @zoho.fields_from_api('Events')
    pp @zoho.fields_from_record('Events')
    pp @zoho.some('Events')
    h = { :subject => 'Test Event',
          :start_datetime => '2014-02-16 16:00:00',
          :end_datetime => '2014-02-16 18:00:00'
    }
    @zoho.add_record('Events', h)
    events = @zoho.some('Events')
    pp events
    #@zoho.delete_record('Contacts', contacts[0][:contactid])
    events.should_not eq(nil)
    events.count.should eq(1)
  end

  it 'should attach a file to a contact record' do
    @zoho.add_record('Contacts', @h_smith)
    contacts = @zoho.find_records('Contacts', :email, '=', @h_smith[:email])
    @zoho.attach_file('Contacts', contacts[0][:contactid], @sample_pdf, File.basename(@sample_pdf))
    @zoho.delete_record('Contacts', contacts[0][:contactid])
  end

  it 'should attach a file to a potential record' do
    pending
    potential = @zoho.first('Potentials').first
    @zoho.attach_file('Potentials', potential[:potentialid], @sample_pdf, File.basename(@sample_pdf))
  end

  it 'should delete a contact record with id' do
    add_dummy_contact
    c = @zoho.find_records('Contacts', :email, '=', 'bob@smith.com')
    @zoho.delete_record('Contacts', c[0][:contactid])
  end

  it 'should find by module and field for columns' do
    add_dummy_contact
    r = @zoho.find_records('Contacts', :email, '=', 'bob@smith.com')
    r[0][:email].should eq('bob@smith.com')
    delete_dummy_contact
  end

  it 'should find by module and id' do
    add_dummy_contact
    r = @zoho.find_records('Contacts', :email, '=', 'bob@smith.com')
    r[0][:email].should eq('bob@smith.com')
    id = r[0][:contactid]
    c = @zoho.find_record_by_id('Contacts', id)
    c[0][:contactid].should eq(id)
    delete_dummy_contact
  end

  it 'should find by a potential by name,  id and related id' do
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
    potentials.map { |r| @zoho.delete_record('Potentials', r[:potentialid])} unless potentials.nil?

    @zoho.add_record('Potentials', p)
    p1 = @zoho.find_records('Potentials', :potential_name, '=', p[:potential_name])
    p1.should_not eq(nil)

    p2 = @zoho.find_records('Potentials', :potentialid, '=', p1.first[:potentialid])
    p2.first[:potentialid].should eq(p1.first[:potentialid])

    p_related = @zoho.find_records('Potentials', :accountid, '=', p[:accountid])
    p_related.first[:accountid].should eq(p[:accountid])

    potentials = @zoho.find_records('Potentials', :potential_name, '=', p[:potential_name])
    potentials.map { |r| @zoho.delete_record('Potentials', r[:potentialid])} unless potentials.nil?
  end

  it 'should get a list of fields for a module' do
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

  it 'should get a list of user fields' do
    r = @zoho.user_fields
    r.count.should be >= 7
  end

  it 'should get a list of local and remote fields' do
    pending
    @zoho.fields('Accounts')
    pp r = @zoho.fields_original('Accounts')
    r.count.should >= 10
  end

  it 'should retrieve records by module name' do
    r = @zoho.some('Contacts')
    r.should_not eq(nil)
    r.count.should be >= 1
  end

  it 'should return related records by module and id' do
    pending
    r = @zoho.some('Accounts').first
    pp r
    related = @zoho.related_records('Accounts', r[:accountid], 'Attachments')
  end

  it 'should return calls' do
    pending
    r = @zoho.some('Calls').first
    r.should_not eq(nil)
  end

  it 'should return events' do
    pending
    r = @zoho.some('Events').first
    r.should_not eq(nil)
  end

  it 'should return tasks' do
    r = @zoho.some('Tasks').first
    r.should_not eq(nil)
  end

  it 'should return users' do
    r = @zoho.users
    r.should_not eq(nil)
  end

  it 'should test for a primary key' do
    @zoho.primary_key?('Accounts', 'accountid').should eq(true)
    @zoho.primary_key?('Accounts', 'potentialid').should eq(false)
    @zoho.primary_key?('Accounts', 'Potential Name').should eq(false)
    @zoho.primary_key?('Accounts', 'Account Name').should eq(false)
    @zoho.primary_key?('Accounts', 'account_name').should eq(false)
  end

  it 'should test for a related id' do
    @zoho.related_id?('Potentials', 'Account Name').should eq(false)
    @zoho.related_id?('Potentials', 'Accountid').should eq(true)
  end

  it 'should test for a valid related field' do
    @zoho.valid_related?('Accounts', 'accountid').should_not eq(nil)
    @zoho.valid_related?('Notes', 'notesid').should_not eq(nil)
    @zoho.valid_related?('Accounts', 'email').should eq(nil)
  end

  it 'should do a full CRUD lifecycle on tasks' do
    pending
    mod_name = 'Tasks'
    fields = @zoho.fields(mod_name)
    fields.count >= 10
    fields.index(:task_owner).should_not eq(nil)
    @zoho.add_record(mod_name, {:task_owner => 'Task Owner', :subject => 'Test Task', :due_date => '2100/1/1'})
    r = @zoho.find_record_by_field('Tasks', 'Subject', '=', 'Test Task')
    r.should_not eq(nil)
    r.map { |t| @zoho.delete_record('Tasks', t[:activityid]) }
  end

  it 'should update fields from a record' do
    @zoho.module_fields.count.should be >= 7
  end

  it 'should update a contact' do
    @zoho.add_record('Contacts', @h_smith)
    contact = @zoho.find_records('Contacts', :email, '=', @h_smith[:email])
    h_changed = { :email => 'robert.smith@smithereens.com' }
    @zoho.update_record('Contacts', contact[0][:contactid], h_changed)
    changed_contact = @zoho.find_records('Contacts', :email, '=', h_changed[:email])
    changed_contact[0][:email].should eq(h_changed[:email])
    @zoho.delete_record('Contacts', contact[0][:contactid])
  end

  it 'should validate that a field name is clean' do
    pp @zoho.clean_field_name?('Name')
    pp @zoho.clean_field_name?('Name (All Upper)')
  end

end
