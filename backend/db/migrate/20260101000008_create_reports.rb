class CreateReports < ActiveRecord::Migration[8.0]
  def change
    create_table :reports do |t|
      # zone_risk / event_export
      t.string :kind, null: false
      # pending / running / done / failed
      t.string :status, null: false, default: "pending"
      t.references :zone, foreign_key: true
      t.timestamptz :period_from, null: false
      t.timestamptz :period_to, null: false
      t.string :object_key        # MinIO 对象键
      t.bigint :size_bytes
      t.string :content_type
      t.string :created_by
      t.text :error_message
      t.timestamptz :generated_at
      t.timestamps
    end
    add_index :reports, [:kind, :status]
  end
end
