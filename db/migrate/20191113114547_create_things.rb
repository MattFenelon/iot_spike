# frozen_string_literal: true

class CreateThings < ActiveRecord::Migration[6.0]
  def change
    create_table :things do |t|
      t.string :thing_name, null: false
      t.text :thing_arn, null: false
      t.text :thing_id, null: false

      t.text :certificate_arn, null: false
      t.text :certificate_id, null: false
      t.text :certificate_pem, null: false
      t.text :key_pair_public_key, null: false
      t.text :key_pair_private_key, null: false

      t.timestamps
    end
  end
end
