#!/usr/bin/ruby

class Schools


  def self.hello_world
    puts "hello world"
  end


  def self.to_csv
    attributes = %w{zendesk_id name account_manager salesforce_id clarify_site_id school_id success_coach owns_core owns_core owns_ob owns_oc owns_om owns_or account_executive_id created_at updated_at}

    CSV.generate(headers: true) do |csv|
      csv << attributes

      all.each do |school|
        csv << attributes.map{ |attr| school.send(attr) }
      end
    end
  end


  def self.parse_from_csv(csv_document)
    # http://ruby-doc.org/stdlib-1.9.3/libdoc/csv/rdoc/CSV.html
    rows = []
    CSV.foreach(csv_document, headers: true) do |row|
      # Push the row as a hash into the rows array
      rows << row.to_hash
    end
    return rows
  end


  def self.fix_csm_name(full_name)
    # Substitute the space with underscore
    fixed_name = full_name.sub(" ", "_")
    fixed_name = fixed_name.downcase
    return fixed_name
  end

  # TODO:
  # need to have a method to clear out all the Zendesk CSM's before adding the new ones?



  def self.setup_csm(raw_import_array)
    csm_list = []
    raw_import_array.each do |school|
      # {"Account Name"=>"MacLachlan College", "Full Name"=>"Jonathan Wilkinson", "Team"=>"Support: GM Team 70", "SFDC 18 Digit Account ID"=>"001d000001HhcgsAAB", "Site ID"=>"60464"}

      # puts school
      school_name = school['Account Name']
      csm = fix_csm_name(school['Full Name'])
      sfdc_id = school['SFDC 18 Digit Account ID']
      # puts "School: #{school_name} \t CSM: #{csm} \t SFDC: #{sfdc_id}"

      # place new values into a new hash
      school = {name: school_name, csm: csm, sfdc_id: sfdc_id}

      # push the object into the csm_list array
      csm_list << school
    end
    return csm_list
  end


  def self.zd_get_orgs(client)
    orgs = Array.new

    client.organizations.all! do |org|
      school = {}
      school[:sfdc_id] = org['organization_fields']['salesforce_id']
      school[:zendesk_id] = org['id'].to_s
      school[:name] = org['name']
      orgs << school
    end

    return orgs
  end


  def self.update_zendesk(org_list, csm_list, client)
    counter = 0
    # Look through each of the source CSV that contains the CSM's
    csm_list.each_with_index do |csm, index|
      # for testing "001d00000228IKzAAM"
      # if csm[:sfdc_id] # == "001d00000228IKzAAM"
      # if index < 10
      if csm[:sfdc_id]

        # Find the matching school in Zendesk by the Salesforce ID
        # school = org_list.select{|org| org[:sfdc_id] == "001d00000228IKzAAM" }
        school = org_list.select{|org| org[:sfdc_id] == csm[:sfdc_id] }
        if !school.empty?
          # Returns an array, so show the first entry
          school = school.first

          # Find the school in Zendesk by the Zendesk ID
          t = client.organizations.find(:id => school[:zendesk_id])

          # Set the CSM/success_coach field to the CSM name
          t[:organization_fields][:success_coach] = csm[:csm]
          t.save

          puts "#{index}\t Updated: #{school[:name]} \t csm: #{csm[:csm]} \t id: #{school[:zendesk_id]}"
        else
          puts "---- Not Found in Zendesk: #{csm[:name]} ---- "
        end
      end

      if counter == 200
        puts "Rate limited. Waiting to retry… Retry after 60 seconds."
        sleep 60
        counter = 0
      else
        counter += 1
      end
      # check response first
      # if !t.response.empty?
      #   if t.response.status == 429
      #     binding.pry
      #     puts "Rate limited. Waiting to retry… Retry after: #{t.response.retry-after}"
      #     sleep 60
      #   end
      # end

    end
  end







end
