# frozen_string_literal: true

class User < ActiveRecord::Base
  attr_accessor :password

  serialize :roles, coder: YAML, type: Array

  def attr_accessible_role
    :custom_role
  end

  def roles_enum
    %i[admin user]
  end
end
