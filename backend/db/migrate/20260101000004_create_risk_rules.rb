class CreateRiskRules < ActiveRecord::Migration[8.0]
  def change
    create_table :risk_rules do |t|
      t.integer :version, null: false
      t.string :name, null: false
      # 绑定材质的规则；nil 表示全库默认规则
      t.references :material, foreign_key: true
      boolean_clause = { null: false, default: false }
      t.boolean :is_default, **boolean_clause

      # 阈值快照，例如:
      # {temp:{min:14,max:24,critical_min:10,critical_max:30},
      #  humi:{min:45,max:60,critical_min:35,critical_max:70},
      #  dew_proximity_c:2.0}
      t.jsonb :thresholds, null: false, default: {}

      # 检测器参数，例如:
      # {sustained_minutes:30, missing_gap_minutes:60,
      #  drift_window_hours:24, drift_slope_c_per_day:0.8, drift_peer_diff_c:1.5}
      t.jsonb :detectors, null: false, default: {}

      # draft / active / superseded
      t.string :status, null: false, default: "draft"
      t.text :change_summary
      t.string :created_by
      t.timestamptz :activated_at
      t.timestamptz :superseded_at
      t.timestamps
    end
    add_index :risk_rules, :version, unique: true
    add_index :risk_rules, [:material_id, :status]
    add_index :risk_rules, :status
  end
end
