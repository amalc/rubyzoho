$:.unshift File.join('..', File.dirname(__FILE__), 'lib')

require 'spec_helper'
require 'zoho_api'
require 'vcr'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/vcr'
  c.hook_into :webmock
  c.default_cassette_options = {:record => :all}
  # c.debug_logger = File.open('log/vcr_debug.log', 'w')
end


describe RubyZoho::Crm do
  # Reset this to zero when running with VCR
  SLEEP_INTERVAL = 15

  before(:all) do
    VCR.use_cassette 'zoho/initialization' do
      base_path = File.join(File.dirname(__FILE__), 'fixtures')
      @sample_pdf = File.join(base_path, 'sample.pdf')
      RubyZoho.configure do |config|
        config.api_key = ENV['ZOHO_API_KEY'].strip
        config.crm_modules = %w(Quotes)
        config.cache_fields = true
      end
      r = RubyZoho::Crm::Contact.find_by_last_name('Smithereens')
      r.each { |m| RubyZoho::Crm::Contact.delete(m.contactid) } unless r.nil?
      r = RubyZoho::Crm::Contact.find_by_email('raj@portra.com')
      r.each { |contact| RubyZoho::Crm::Contact.delete(contact.contactid) } unless r.nil?
    end
  end

  it 'should add accessors using a list of names' do
    VCR.use_cassette 'zoho/accessors_names' do
      c = RubyZoho::Crm::Contact.new
      c.first_name = 'Raj'
      c.first_name.should eq('Raj')
      c.email = 'raj@portra.com'
      c.email.should eq('raj@portra.com')
      c.module_name.should eq('Contacts')
    end
  end

  it 'should attach a file to an account' do
    VCR.use_cassette 'zoho/attach_file_to_account' do
      r = RubyZoho::Crm::Account.all.first
      r.attach_file(@sample_pdf, '1_' + File.basename(@sample_pdf)).should eq('200')
    end
  end

  it 'should attach a file to a contact' do
    VCR.use_cassette 'zoho/attach_file_to_contact' do
      r = RubyZoho::Crm::Contact.all.first
      r.attach_file(@sample_pdf, File.basename(@sample_pdf)).should eq('200')
    end
  end

  it 'should attach a file to a lead' do
    VCR.use_cassette 'zoho/attach_file_to_lead' do
      r = RubyZoho::Crm::Lead.all.first
      r.attach_file(@sample_pdf, File.basename(@sample_pdf)).should eq('200')
    end
  end

  it 'should attach a file to a potential' do
    VCR.use_cassette 'zoho/attach_file_to_potential' do
      r = RubyZoho::Crm::Potential.all.first
      r.attach_file(@sample_pdf, File.basename(@sample_pdf)).should eq('200')
    end
  end

  it 'should attach a file to a task' do
    VCR.use_cassette 'zoho/attach_file_to_task' do
      r = RubyZoho::Crm::Task.all.first
      r.attach_file(@sample_pdf, File.basename(@sample_pdf)).should eq('200')
    end
  end

  it 'should concatenate a related object and save it' do
    VCR.use_cassette 'zoho/concatenate_related_object' do
      subject = '[DELETE THIS] New subject as of 112233'
      a = RubyZoho::Crm::Account.all.last
      #noinspection RubyArgCount
      a << RubyZoho::Crm::Task.new(
          :subject => subject,
          :description => 'Nothing',
          :status => 'Not Started',
          :priority => 'High',
          :send_notification_email => 'False',
          :due_date => '2014-02-16 16:00:00',
          :start_datetime => Time.now.to_s[1, 19],
          :end_datetime => '2014-02-16 16:00:00'
      )
      r = RubyZoho::Crm::Task.find_by_subject(subject)
      r.first.relatedtoid.should eq(a.accountid)
    end
  end

  it 'should determine if a method is a module' do
    VCR.use_cassette 'zoho/determine_module' do
      good_methods = [:contact, :contacts, 'contacts', 'lead', 'leads', :potentials, :quotes]
      good_methods.map { |m| RubyZoho::Crm.method_is_module?(m).should_not eq(nil) }
    end
  end

  it 'should find a contact by email or last name' do
    VCR.use_cassette 'zoho/find_by_email_or_name' do
      r = RubyZoho::Crm::Contact.find_by_email('bob@smith.com')
      r.each { |m| RubyZoho::Crm::Contact.delete(m.contactid) } unless r.nil?
      until RubyZoho::Crm::Contact.find_by_email('bob@smith.com').nil?
        sleep(SLEEP_INTERVAL)
      end unless r.nil?
      1.upto(3) do
        c = RubyZoho::Crm::Contact.new(
            :first_name => 'Bob',
            :last_name => 'Smithereens',
            :email => 'bob@smith.com')
        c.save
      end
      r = RubyZoho::Crm::Contact.find_by_email('bob@smith.com')
      while r.nil?
        sleep(SLEEP_INTERVAL)
        r = RubyZoho::Crm::Contact.find_by_email('bob@smith.com')
      end
      r.should_not eq(nil)
      r.count.should eq(3)
      r.each { |m| m.email.should eq('bob@smith.com') }
      r = RubyZoho::Crm::Contact.find_by_last_name('Smithereens')
      r.should_not eq(nil)
      r.map { |c| c.last_name }.count.should eq(3)
      r.first.last_name.should eq('Smithereens')
      r.each { |m| RubyZoho::Crm::Contact.delete(m.id) }
    end
  end

  it 'should find a contact by ID' do
    VCR.use_cassette 'zoho/find_contact_by_id' do
      contacts = RubyZoho::Crm::Contact.all
      id = contacts.first.id
      c = RubyZoho::Crm::Contact.find_by_contactid(id)
      c.first.contactid.should eq(id)
      c.first.last_name.should eq(contacts.first.last_name)
      c.first.email.should eq(contacts.first.email)
    end
  end

  it 'should find a lead by ID' do
    VCR.use_cassette 'zoho/find_lead_by_id' do
      leads = RubyZoho::Crm::Lead.all
      lead_id = leads.first.id
      l = RubyZoho::Crm::Lead.find_by_leadid(lead_id)
      l.first.leadid.should eq(lead_id)
    end
  end

  it 'should find a user by email address' do
    VCR.use_cassette 'zoho/find_user_by_email' do
      users = RubyZoho::Crm::CRMUser.all
      r = RubyZoho::Crm::CRMUser.find_by_email(users.first.email)
      r.first.email.should eq(users.first.email)
    end
  end

  it 'should get a list of attr_writers for accounts' do
    VCR.use_cassette 'zoho/list_attr_writers' do
      c = RubyZoho::Crm::Account.new
      c.attr_writers.count.should be >= 18
    end
  end

  it 'should get a list of attr_writers for contacts' do
    VCR.use_cassette 'zoho/list_attr_writers_for_contacts' do
      c = RubyZoho::Crm::Contact.new
      c.attr_writers.count.should be >= 10
    end
  end

  it 'should get a list of attr_writers for leads' do
    VCR.use_cassette 'zoho/list_attr_writers_for_leads' do
      c = RubyZoho::Crm::Lead.new
      c.attr_writers.count.should be >= 16
    end
  end

  it 'should get a list of attr_writers for potentials' do
    VCR.use_cassette 'zoho/list_attr_writers_for_potentials' do
      c = RubyZoho::Crm::Potential.new
      c.attr_writers.count.should be >= 14
    end
  end

  it 'should get a list of attr_writers for tasks' do
    VCR.use_cassette 'zoho/list_attr_writers_for_taskss' do
      c = RubyZoho::Crm::Task.new
      c.attr_writers.count.should be >= 14
    end
  end

  it 'should get a list of attr_writers for quotes' do
    VCR.use_cassette 'zoho/list_attr_writers_for_quotes' do
      c = RubyZoho::Crm::Quote.new
      c.attr_writers.count.should be >= 18 unless c.nil?
    end
  end

  it 'should get a list of accounts' do
    VCR.use_cassette 'zoho/list_of_accounts' do
      r = RubyZoho::Crm::Account.all
      r.count.should be > 1
      r.map { |account| account.class.should eq(RubyZoho::Crm::Account) }
    end
  end

  it 'should get a list of calls' do
    VCR.use_cassette 'zoho/list_of_calls' do
      r = RubyZoho::Crm::Call.all
      unless r.nil?
        r.map { |e| e.class.should eq(RubyZoho::Crm::Call) }
        r.map { |e| e.id.should eq(e.activityid) }
      end
    end
  end

  it 'should get a list of contacts' do
    VCR.use_cassette 'zoho/list_of_contacts' do
      r = RubyZoho::Crm::Contact.all
      r.count.should be > 1
      r.map { |e| e.class.should eq(RubyZoho::Crm::Contact) }
      r.map { |e| e.id.should eq(e.contactid) }
    end
  end

  it 'should get a list of events' do
    pending
    VCR.use_cassette 'zoho/list_of_events' do
      r = RubyZoho::Crm::Event.all
      r.map { |event| event.class.should eq(RubyZoho::Crm::Event) } unless r.nil?
      r.map { |e| e.id.should eq(e.eventid) }
      true.should eq(false)
    end
  end

  it 'should get a list of potentials' do
    VCR.use_cassette 'zoho/list_of_potentials' do
      r = RubyZoho::Crm::Potential.all
      r.count.should be > 1
      r.map { |potential| potential.class.should eq(RubyZoho::Crm::Potential) }
      r.map { |e| e.id.should eq(e.potentialid) }
    end
  end

  it 'should get a list of quotes' do
    pending
    VCR.use_cassette 'zoho/list_of_quotes' do
      r = RubyZoho::Crm::Quote.all
      r.count.should be >= 1
      r.map { |quote| quote.class.should eq(RubyZoho::Crm::Quote) }
      r.map { |e| e.id.should eq(e.quoteid) }
    end
  end

  it 'should get a list of tasks' do
    VCR.use_cassette 'zoho/list_of_tasks' do
      r = RubyZoho::Crm::Task.all
      r.map { |task| task.class.should eq(RubyZoho::Crm::Task) } unless r.nil?
      r.map { |e| e.id.should eq(e.activityid) }
    end
  end

  it 'should get a list of users' do
    VCR.use_cassette 'zoho/list_of_users' do
      r = RubyZoho::Crm::CRMUser.all
      r.count.should be >= 1
    end
  end

  it 'should save a contact record' do
    VCR.use_cassette 'zoho/save_contact' do
      c = RubyZoho::Crm::Contact.new(
          :first_name => 'Raj',
          :last_name => 'Portra',
          :email => 'raj@portra.com')
      c.save
      sleep(30)
      r = RubyZoho::Crm::Contact.find_by_email('raj@portra.com')
      while r.nil?
        sleep(SLEEP_INTERVAL)
        r = RubyZoho::Crm::Contact.find_by_email('raj@portra.com')
      end
      r.first.email.should eq('raj@portra.com')
      r.each { |contact| RubyZoho::Crm::Contact.delete(contact.contactid) }
    end
  end

  it 'should save a lead record' do
    VCR.use_cassette 'zoho/save_lead' do
      l = RubyZoho::Crm::Lead.new(
          :first_name => 'Raj',
          :last_name => 'Portra',
          :email => 'raj@portra.com',
          :no_of_employees => 12345
					)
      l.save
      r = RubyZoho::Crm::Lead.find_by_email('raj@portra.com')
      r.should_not eq(nil)
      r.first.email.should eq(l.email)
      r.first.no_of_employees.should eq(l.no_of_employees.to_s)
      r.each { |c| RubyZoho::Crm::Lead.delete(c.id) }
    end
  end

  it 'should save and retrieve an account record with a custom field' do
    VCR.use_cassette 'zoho/save_account_custom_field' do
      accounts = RubyZoho::Crm::Account.all
      a = accounts.first
      if defined?(a.par_lifetime_to_dat)
        RubyZoho::Crm::Account.update(
            :id => a.id,
            :par_lifetime_to_date => '$1000000'
        )
        a2 = RubyZoho::Crm::Account.find(a.accountid)
        a2.first.test_custom.should eq('1000000')
      end
    end
  end

  it 'should save and retrieve a lead record with a custom field' do
    VCR.use_cassette 'zoho/save_lead_custom_field' do
      l = RubyZoho::Crm::Lead.first
      if defined?(l.test_label)
        RubyZoho::Crm::Lead.update(
            :id => l.id,
            :test_label => '$101',
            :test_integer => 1
        )
        l2 = RubyZoho::Crm::Lead.find(l.id)
        l2.first.test_label.should eq('$101')
        l2.first.test_integer.should eq('1')
      end
    end
  end

  it 'should save and retrieve a potential record' do
    VCR.use_cassette 'zoho/potential_record' do
      accounts = RubyZoho::Crm::Account.all
      h = {
          :potential_name => 'A very big potential INDEED!!!!!!!!!!!!!',
          :accountid => accounts.first.accountid,
          :account_name => accounts.first.account_name,
          :closing_date => '1/1/2014',
          :type => 'New Business',
          :stage => 'Needs Analysis'}
      r = RubyZoho::Crm::Potential.find_by_potential_name(h[:potential_name])
      r.each { |c| RubyZoho::Crm::Potential.delete(c.potentialid) } unless r.nil?
      p = RubyZoho::Crm::Potential.new(h)
      p.save
      r = RubyZoho::Crm::Potential.find_by_potential_name(p.potential_name)
      while r.nil? do
        sleep(SLEEP_INTERVAL)
        r = RubyZoho::Crm::Potential.find_by_potential_name(p.potential_name)
      end
      r.first.potential_name.should eq(h[:potential_name])
      potential = RubyZoho::Crm::Potential.find(r.first.potentialid)
      potential.first.potentialid.should eq(r.first.potentialid)
      p_by_account_id = RubyZoho::Crm::Potential.find_by_accountid(accounts.first.accountid)
      p_found = p_by_account_id.map { |pn| pn if pn.potential_name == h[:potential_name] }.compact
      p_found.first.potentialid.should eq(r.first.potentialid)
      r.each { |c| RubyZoho::Crm::Potential.delete(c.potentialid) }
    end
  end

  it 'should save and retrieve a task record' do
    VCR.use_cassette 'zoho/task_record' do
      accounts = RubyZoho::Crm::Account.all
      h = {
          :subject => 'Test Task',
          :due_date => Date.today.to_s + '23:59',
          :semodule => 'Accounts',
          :relatedtoid => accounts.first.accountid,
          :related_to => accounts.first.account_name,
          :priority => 'Low'}
      r = RubyZoho::Crm::Task.find_by_subject(h[:subject])
      r.each { |t| RubyZoho::Crm::Task.delete(t.activityid) } unless r.nil?
      t = RubyZoho::Crm::Task.new(h)
      t.save
      r = RubyZoho::Crm::Task.find_by_subject(h[:subject])
      while r.nil?
        sleep(SLEEP_INTERVAL)
        r = RubyZoho::Crm::Task.find_by_subject(h[:subject])
      end
      r.first.subject.should eq(h[:subject])
      tasks = RubyZoho::Crm::Task.find_by_activityid(r.first.activityid)
      tasks.first.activityid.should eq(r.first.activityid)
      r.each { |c| RubyZoho::Crm::Task.delete(c.activityid) }
    end
  end

  it 'should save an task record related to an account' do
    VCR.use_cassette 'zoho/task_related_to_account' do
      a = RubyZoho::Crm::Account.all.first
      e = RubyZoho::Crm::Task.new(
          :task_owner => a.account_owner,
          :subject => "Task should be related to #{a.account_name} #{Time.now}",
          :description => 'Nothing',
          :smownerid => "#{a.smownerid}",
          :status => 'Not Started',
          :priority => 'High',
          :send_notification_email => 'False',
          :due_date => '2014-02-16 16:00:00',
          :start_datetime => Time.now.to_s[1, 19],
          :end_datetime => '2014-02-16 16:00:00',
          :related_to => "#{a.account_name}",
          :seid => "#{a.accountid}",
          :semodule => 'Accounts'
      )
      r_expected = e.save
      r = RubyZoho::Crm::Task.find_by_activityid(r_expected.id)
      r.first.subject[0..20].should eq(r_expected.subject[0..20])
    end
  end

  it 'should get tasks by user' do
    pending
    VCR.use_cassette 'zoho/tasks_by_owner' do
      task_owner = RubyZoho::Crm::Task.first.task_owner
      tasks = RubyZoho::Crm::Task.find_by_task_owner(task_owner)
      tasks.should_not eq(nil)
      tasks.map { |t| RubyZoho::Crm::Task.delete(t.activityid) } unless tasks.nil?
      true.should eq(false)
    end
  end

  it 'should sort contact records' do
    VCR.use_cassette 'zoho/sort_contacts' do
      r = RubyZoho::Crm::Contact.all
      sorted = r.sort { |a, b| a.last_name <=> b.last_name }
      sorted.collect { |c| c.last_name }.should_not eq(nil)
    end
  end

  it 'should update a lead record' do
    VCR.use_cassette 'zoho/update_lead' do
      r_changed = RubyZoho::Crm::Lead.find_by_email('changed_rajj@portra.com')
      r_changed.each { |c| RubyZoho::Crm::Lead.delete(c.leadid) } unless r_changed.nil?
      l = RubyZoho::Crm::Lead.new(
          :first_name => 'Raj',
          :last_name => 'Portra',
          :email => 'raj@portra.com')
      l.save
      r = RubyZoho::Crm::Lead.find_by_email('raj@portra.com')
      while r.nil?
        sleep(SLEEP_INTERVAL)
        r = RubyZoho::Crm::Lead.find_by_email('raj@portra.com')
      end
      RubyZoho::Crm::Lead.update(
          :id => r.first.leadid,
          :email => 'changed_rajj@portra.com'
      )
      r_changed = RubyZoho::Crm::Lead.find_by_email('changed_rajj@portra.com')
      while r_changed.nil?
        sleep(SLEEP_INTERVAL)
        r_changed = RubyZoho::Crm::Lead.find_by_email('changed_rajj@portra.com')
      end
      r.first.leadid.should eq(r_changed.first.leadid)
      r.each { |c| RubyZoho::Crm::Lead.delete(c.leadid) }
      r_changed.each { |c| RubyZoho::Crm::Lead.delete(c.leadid) }
    end
  end

  it 'should validate a field name' do
    VCR.use_cassette 'zoho/validate_field' do
      good_names = ['This is OK', 'OK_to_use', 'field()']
      bad_names = ['This %#{@} is not']
      good_names.map { |f| RubyZoho::Crm.method_name?(ApiUtils.string_to_symbol(f)).should_not eq(false) }
      bad_names.map { |f| RubyZoho::Crm.method_name?(ApiUtils.string_to_symbol(f)).should eq(false) }
    end
  end

end
