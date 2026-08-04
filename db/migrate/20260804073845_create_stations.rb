class CreateStations < ActiveRecord::Migration[8.1]
  def change
    create_table :stations do |t|
      t.string :external_id
      t.string :name, null: false
      t.string :address

      t.decimal :latitude,
                precision: 10,
                scale: 7,
                null: false

      t.decimal :longitude,
                precision: 10,
                scale: 7,
                null: false

      t.boolean :favorite,
                default: false,
                null: false

      t.string :source,
               default: "manual",
               null: false

      t.timestamps
    end

    add_index :stations, :external_id, unique: true
  end
end