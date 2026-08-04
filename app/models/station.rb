class Station < ApplicationRecord
  validates :name, presence: true

  validates :latitude,
            presence: true,
            numericality: {
              greater_than_or_equal_to: -90,
              less_than_or_equal_to: 90
            }

  validates :longitude,
            presence: true,
            numericality: {
              greater_than_or_equal_to: -180,
              less_than_or_equal_to: 180
            }

  validates :external_id,
            uniqueness: true,
            allow_blank: true
end