#!/usr/bin/ruby
# $LOAD_PATH << File.dirname(__FILE__)

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

end
