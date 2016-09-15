class School < ActiveRecord::Base
  belongs_to :account_executive

  def self.to_csv
    attributes = %w{zendesk_id name account_manager salesforce_id clarify_site_id school_id success_coach owns_core owns_core owns_ob owns_oc owns_om owns_or account_executive_id created_at updated_at}

    CSV.generate(headers: true) do |csv|
      csv << attributes

      all.each do |school|
        csv << attributes.map{ |attr| school.send(attr) }
      end
    end
  end

  def self.update_via_csv(schools_csv)
    schools = all
    # schools = first(20)
    schools_csv = parse_from_csv(schools_csv)
    combined = Array.new

    schools_csv.each_with_index do |school, index|
      # current_school = match_zendesk_school(school['SFDC 18 Digit Account ID'])
      current_school = School.where(salesforce_id: school['SFDC 18 Digit Account ID']).first
      if current_school

        # If the CSV has an Account Owner (which it always should!), search the AE database by the full_name which is what Salesforce uses
        # "Account Owner"=>"Lauren Collie"
        if school['Account Owner']
          t = current_school
          t.account_executive = AccountExecutive.find_by(full_name: school['Account Owner'])
          t.save
        end
        if school['Products Owned']
          # @products_owned = row['Products Owned']
          compare_products_owned(school['Products Owned'])
          t = current_school
          if @products_owned_hash
            t.owns_core = @products_owned_hash[:owns_core]
            t.owns_ob = @products_owned_hash[:owns_ob]
            t.owns_oc = @products_owned_hash[:owns_oc]
            t.owns_om = @products_owned_hash[:owns_om]
            t.owns_or = @products_owned_hash[:owns_or]
          end
          # binding.pry
          t.save
        end
        school['zendesk_school'] = current_school
        # binding.pry
      end
      combined.push(school)
      # combined << school
      # binding.pry
    end
    return combined
  end

  def self.match_zendesk_school(to_match)
    where(salesforce_id: to_match).first
  end

  def self.find_school(school)
    where(zendesk_id: school['id']).first
  end

  def self.match_ae(zendesk_ae)
    puts zendesk_ae
    account_executive = AccountExecutive.where(zendesk_name: zendesk_ae).first
    return account_executive
  end


  def self.parse_from_csv(csv_document)
    rows = []
    # Fix the encoding of the entire CSV contents before parsing
    csv_string = csv_document.file_contents.encode!("UTF-8", "iso-8859-1", invalid: :replace)
    CSV.parse(csv_string, headers: true) do |row|
      rows << row.to_hash
      # rows.push(row.to_hash)
    end
    rows
  end



  def self.import_from_zendesk(client)
    # need to pull from SchoolsController#new
    updated_schools = Array.new

    client.organizations.all! do |org|
      puts org['name']
      # See if the school exists already. If so, use existing Zendesk id and just save any updates
      existing_school = find_school(org)
      # if org['name'] == "Bryanston School"
      #   binding.pry
      # end
      if existing_school
        school = existing_school
      else
        school = School.new
        school.zendesk_id = org['id']
      end
      school.name = org['name']
      # school.account_manager = school['organization_fields']['account_manager']
      school.account_executive = match_ae(org['organization_fields']['account_manager'])
      school.salesforce_id = org['organization_fields']['salesforce_id']
      school.clarify_site_id = org['organization_fields']['clarify_site_id']
      school.school_id = org['organization_fields']['school_id']
      school.success_coach = org['organization_fields']['success_coach']
      school.owns_core = org['organization_fields']['core']
      school.owns_ob = org['organization_fields']['ob']
      school.owns_oc = org['organization_fields']['oc']
      school.owns_om = org['organization_fields']['om']
      school.owns_or = org['organization_fields']['or']
      school.save
      updated_schools << school
    end
    puts updated_schools.count
    return updated_schools
  end





  def self.update_zendesk(client)
    updated_schools = Array.new
    schools_old_info = Array.new
    school_count = School.count
    school_counter = 1

    School.find_in_batches(start: 0, batch_size: 199).with_index do |group, batch|
      group.each { |school|
        # @schools.push(school[:name])

        # this IF is for troubleshooting
        if school[:id] #> 2254
          # puts "Batch: #{batch} / Index: #{index}"
          # puts school[:name]
          # puts school[:zendesk_id]
          t = client.organizations.find(:id => school[:zendesk_id])
          old_info = {}
          old_info[:zendesk_id] = t[:id]
          old_info[:previous_core] = t[:organization_fields][:core]
          old_info[:previous_ob] = t[:organization_fields][:ob]
          old_info[:previous_oc] = t[:organization_fields][:oc]
          old_info[:previous_om] = t[:organization_fields][:om]
          old_info[:previous_or] = t[:organization_fields][:or]
          old_info[:previous_ae] = t[:organization_fields][:account_manager]
          old_info[:previous_ae_phone] = t[:organization_fields][:ae_phone_number]

          t[:organization_fields][:core] = school[:owns_core]
          t[:organization_fields][:ob] = school[:owns_ob]
          t[:organization_fields][:oc] = school[:owns_oc]
          t[:organization_fields][:om] = school[:owns_om]
          t[:organization_fields][:or] = school[:owns_or]
          # See if the method exists (only if there's an AE set)
          if school.account_executive.respond_to? :zendesk_name
            t[:organization_fields][:account_manager] = school.account_executive.zendesk_name
            if school.account_executive.respond_to? :phone
              t[:organization_fields][:ae_phone_number] = school.account_executive.phone
            else
              t[:organization_fields][:ae_phone_number] = ""
            end
          end
          t.save

          # check response first
          if t.response.respond_to? :status
            if t.response.status == 429
              binding.pry
              puts "Rate limited. Waiting to retry… Retry after: #{t.response.retry-after}"
              sleep 60
            end
          end


        end

        # todo: the index resets with the batch, so it needs to be adjusted to make it match the school count better... probably a counter variable that increments
        puts "#{school_counter} / #{school_count}   Updated #{school[:name]} \t (#{school[:zendesk_id]}) [#{school[:id]}] \t Batch: #{batch + 1}"
        school_counter += 1
        schools_old_info << old_info
        updated_schools << school
      }

      puts "Now sleep..."
      sleep(1)
    end


    return updated_schools, schools_old_info
  end


  def self.compare_products_owned(products_owned_raw)
    products_array = products_owned_raw.try(:split, '; ')

    @products_owned_hash = {owns_core: false, owns_ob: false, owns_oc: false, owns_om: false, owns_or: false}
    # binding.pry
    products_array.each_with_index do |row, i|
      case row
      when "onCore"
        puts "It's Core"
        @products_owned_hash[:owns_core] = true
      when "onBoard"
        puts "It's onBoard"
        @products_owned_hash[:owns_ob] = true
      when "onCampus"
        puts "It's onCampus"
        @products_owned_hash[:owns_oc] = true
      when "onMessage"
        puts "It's onMessage"
        @products_owned_hash[:owns_om] = true
      when "onRecord"
        puts "It's onRecord"
        @products_owned_hash[:owns_or] = true
      else
        # puts "No products matched"
      end
    end
  end






end
