# frozen_string_literal: true

class FluxDashboard < ApplicationRecord
  self.table_name = "dashboards"
  belongs_to :project
  has_many :widgets, foreign_key: "dashboard_id", dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :project_id }

  scope :default_first, -> { order(is_default: :desc, created_at: :asc) }
  scope :public_only, -> { where(is_public: true) }

  before_validation :generate_slug, on: :create

  def to_param
    slug
  end

  def make_default!
    transaction do
      project.flux_dashboards.update_all(is_default: false)
      update!(is_default: true)
    end
  end

  private

  def generate_slug
    return if slug.present?
    return unless name.present?

    base_slug = name.parameterize
    self.slug = base_slug

    counter = 1
    while project.flux_dashboards.exists?(slug: slug)
      self.slug = "#{base_slug}-#{counter}"
      counter += 1
    end
  end
end
