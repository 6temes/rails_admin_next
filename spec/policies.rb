# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def show?
    user.roles.include? :admin
  end

  def destroy?
    false
  end

  def history?
    user.roles.include? :admin
  end

  def show_in_app?
    user.roles.include? :admin
  end

  def dashboard?
    user.roles.include? :admin
  end

  def index?
    false
  end

  def new?
    user.roles.include? :admin
  end
  alias_method :create?, :new?

  def edit?
    user.roles.include? :admin
  end
  alias_method :update?, :edit?

  def export?
    user.roles.include? :admin
  end

  def rails_admin_index?
    true
  end
end

class PlayerPolicy < ApplicationPolicy
  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      user.roles.include?(:manage_player) ? scope.all : scope.where(retired: false)
    end
  end

  def new?
    user.roles.include?(:manage_player) ||
      (user.roles.include?(:create_player) && (!record.is_a?(Player) || record.suspended))
  end
  alias_method :create?, :new?

  def edit?
    active_player_role?(:update_player)
  end
  alias_method :update?, :edit?

  def destroy?
    active_player_role?(:destroy_player)
  end

  def history?
    active_player_role?(:history_player)
  end

  def show_in_app?
    active_player_role?(:show_in_app_player)
  end

  def index?
    user.roles.include? :admin
  end

  def attributes_for(action)
    if action == :new && user.roles.include?(:create_player) && !user.roles.include?(:manage_player)
      {suspended: true}
    else
      {}
    end
  end

  private

  # The class stands in for "some player" when a list-level link is checked.
  def active_player_role?(role)
    user.roles.include?(:manage_player) ||
      (user.roles.include?(role) && (!record.is_a?(Player) || !record.retired))
  end
end

class FanshipPolicy < ApplicationPolicy
  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      user.roles.include?(:read_fanship) ? scope.where(since: nil) : scope.none
    end
  end

  def index?
    user.roles.include? :admin
  end
end
