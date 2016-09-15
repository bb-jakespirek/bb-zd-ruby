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

end
