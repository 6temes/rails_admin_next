# frozen_string_literal: true

module RailsAdminNext
  # View-facing adapter over a single page of records.
  #
  # Wraps either a GearedPagination::Page (ActiveRecord lists, via
  # .from_recordset) or a manually built Array (the PaperTrail audit log, whose
  # VersionProxy objects are not an ActiveRecord::Relation) and exposes only the
  # pagination contract the index/history views and the shared pager partial
  # consume. Counting is lazy so the count-free "limited" pager can render
  # prev/next without triggering a COUNT query.
  class PaginatedCollection
    include Enumerable

    attr_reader :current_page, :per_page

    def self.from_recordset(recordset, page_number, per_page)
      page = recordset.page(page_number)
      new page.records,
        current_page: page.number,
        per_page:,
        total_count: -> { recordset.records_count }
    end

    # total_count / total_pages may each be an Integer, nil, or a callable
    # returning one; callables are evaluated (and memoized) lazily on first read
    # so the count-free pager never triggers a COUNT query. total_pages defaults
    # to a value derived from total_count (see #total_pages).
    def initialize(records, current_page:, per_page:, total_count:, total_pages: nil)
      @records = records.to_a
      @current_page = current_page.to_i
      @per_page = per_page.to_i
      @total_count = total_count
      @total_pages = total_pages
    end

    def each(&)
      @records.each(&)
    end

    delegate :size, :length, :empty?, :first, :last, :to_a, :to_json, :as_json, to: :@records

    # A grouped relation makes the underlying COUNT return a Hash (one entry per
    # group); treat its length as the count so grouped queries paginate correctly
    # instead of letting Hash arithmetic raise.
    def total_count
      @total_count = @total_count.call if @total_count.respond_to?(:call)
      @total_count = @total_count.size if @total_count.is_a?(Hash)
      @total_count
    end

    # Derived from total_count when not supplied, so a grouped relation never
    # reaches GearedPagination's Hash-unaware page_count arithmetic.
    def total_pages
      @total_pages = @total_pages.call if @total_pages.respond_to?(:call)
      @total_pages = @total_pages.size if @total_pages.is_a?(Hash)
      @total_pages ||= [(total_count.to_f / per_page).ceil, 1].max
      @total_pages
    end

    def first_page?
      current_page <= 1
    end

    def last_page?
      current_page >= total_pages
    end

    def next_page
      current_page + 1 unless last_page?
    end

    # This page holds a full slice, so (without a COUNT) more records may
    # follow — drives the count-free "limited" pager's next link.
    def full_page?
      size >= per_page
    end
  end
end
