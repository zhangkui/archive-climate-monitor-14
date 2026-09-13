class CreateRiskEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :risk_events do |t|
      # sustained_threshold（连续超阈值）/ drift（传感器漂移）
      # missing（缺测）/ boundary_transition（库区边界变更）
      t.string :event_type, null: false
      # info / warning / critical
      t.string :severity, null: false
      # open / confirmed / resolved / dismissed / false_positive
      t.string :status, null: false, default: "open"

      t.references :sensor, foreign_key: true
      t.references :zone, null: false, foreign_key: true

      # 事件计算时所用规则的不可变引用（即使规则日后被取代）。
      # boundary_transition 属运营事件、非规则推导，故允许为空。
      t.references :risk_rule, foreign_key: true
      t.integer :risk_rule_version

      t.string :metric             # temp_c / humi_pct / dew_margin_c / availability
      t.decimal :peak_value, precision: 8, scale: 2
      # 进行中事件的最新进展（不属于“历史结论”，允许更新）
      t.decimal :latest_value, precision: 8, scale: 2
      t.timestamptz :latest_seen_at

      t.timestamptz :started_at, null: false
      t.timestamptz :ended_at
      t.timestamptz :detected_at, null: false
      t.timestamptz :confirmed_at
      t.string :confirmed_by
      # auto_recovered / manual / device_replaced / boundary_adjusted
      t.string :resolution
      t.text :resolution_note

      # 冻结的计算证据：样本点、斜率、同伴对比、阈值快照等
      t.jsonb :evidence, null: false, default: {}
      t.string :dedup_key, null: false

      t.timestamps
    end

    add_index :risk_events, :dedup_key, unique: true
    add_index :risk_events, [:zone_id, :status]
    add_index :risk_events, [:sensor_id, :status]
    add_index :risk_events, [:event_type, :status]
    add_index :risk_events, :started_at

    # 数据库层兜底：结论字段一旦写入即冻结——
    # 规则版本更新、重新扫描都不能覆盖既往判定；
    # 只放行状态流转与处置字段（status/confirmed_by/ended_at/peak 进展等）。
    execute <<~SQL
      CREATE OR REPLACE FUNCTION freeze_risk_event_history() RETURNS trigger AS $$
      BEGIN
        IF NEW.event_type        IS DISTINCT FROM OLD.event_type
        OR NEW.severity          IS DISTINCT FROM OLD.severity
        OR NEW.risk_rule_id      IS DISTINCT FROM OLD.risk_rule_id
        OR COALESCE(NEW.risk_rule_version,-1) IS DISTINCT FROM COALESCE(OLD.risk_rule_version,-1)
        OR NEW.started_at        IS DISTINCT FROM OLD.started_at
        OR NEW.metric            IS DISTINCT FROM OLD.metric
        OR NEW.zone_id           IS DISTINCT FROM OLD.zone_id
        OR NEW.sensor_id         IS DISTINCT FROM OLD.sensor_id
        OR NEW.evidence::text    IS DISTINCT FROM OLD.evidence::text
        OR NEW.dedup_key         IS DISTINCT FROM OLD.dedup_key THEN
          RAISE EXCEPTION 'risk_event 历史结论字段不可修改 (event_id=%)', OLD.id
            USING ERRCODE = 'check_violation';
        END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER trg_freeze_risk_event_history
        BEFORE UPDATE ON risk_events
        FOR EACH ROW EXECUTE FUNCTION freeze_risk_event_history();
    SQL
  end
end
