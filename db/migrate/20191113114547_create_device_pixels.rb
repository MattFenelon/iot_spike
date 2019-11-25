# frozen_string_literal: true

class CreateDevicePixels < ActiveRecord::Migration[6.0]
  def change
    create_table :device_pixels do |t|
      t.string :thing_name, null: false
      t.text :thing_arn, null: false
      t.text :thing_id, null: false

      t.timestamps
    end
  end
end
