class CreateMaterials < ActiveRecord::Migration[8.0]
  def change
    create_table :materials do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.timestamps
    end
    add_index :materials, :code, unique: true

    create_table :zones do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.references :material, null: false, foreign_key: true
      t.decimal :area_m2, precision: 10, scale: 2
      # active（在管）/ merged（已并入其他库区）/ closed（关闭）
      t.string :status, null: false, default: "active"
      t.timestamptz :established_at, null: false
      t.timestamps
    end
    add_index :zones, :code, unique: true
    add_index :zones, :status

    # 库区边界的每一次变更都形成不可变版本
    create_table :zone_versions do |t|
      t.references :zone, null: false, foreign_key: true
      t.integer :version, null: false
      # created / boundary / merge / rename / close
      t.string :change_type, null: false
      # GeoJSON Polygon / 货架区间描述，变更前后的完整快照
      t.jsonb :boundary, null: false, default: {}
      t.references :related_zone, foreign_key: { to_table: :zones }
      t.string :changed_by
      t.text :change_reason
      t.timestamptz :effective_at, null: false
      t.timestamps
    end
    add_index :zone_versions, [:zone_id, :version], unique: true
    add_index :zone_versions, :effective_at
  end
end
