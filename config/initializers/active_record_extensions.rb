# frozen_string_literal: true

# The on_load(:active_record) block is class_eval'd in ActiveRecord::Base's
# context, so these definitions land directly on ActiveRecord::Base.
ActiveSupport.on_load(:active_record) do
  def self.rails_admin_next(&)
    RailsAdminNext.config(self, &)
  end

  def rails_admin_default_object_label_method
    new_record? ? "new #{self.class}" : "#{self.class} ##{id}"
  end

  def safe_send(value)
    if has_attribute?(value)
      read_attribute(value)
    else
      send(value)
    end
  end
end
