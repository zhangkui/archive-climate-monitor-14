class CreateAuditEvents < ActiveRecord::Migration[8.0]
  def change
    # 只增不改的审计流水：异常确认、规则调整、设备替换、库区边界变更……
    create_table :audit_events do |t|
      # anomaly_confirmation / rule_change / device_replacement / zone_change / system
      t.string :category, null: false
      t.string :action, null: false

      t.string :actor_name
      t.string :auditable_type
      t.bigint :auditable_id

      t.jsonb :before_data, null: false, default: {}
      t.jsonb :after_data, null: false, default: {}
      t.text :note
      t.string :request_id
      t.timestamptz :occurred_at, null: false
      t.timestamps
    end

    add_index :audit_events, :category
    add_index :audit_events, [:auditable_type, :auditable_id]
    add_index :audit_events, :occurred_at

    # 审计表禁止 UPDATE/DELETE（触发器兜底，防止越权改写）
    execute <<~SQL
      CREATE OR REPLACE FUNCTION audit_events_append_only() RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION 'audit_events 为只追加流水，禁止 %', TG_OP
          USING ERRCODE = 'insufficient_privilege';
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER trg_audit_no_update
        BEFORE UPDATE ON audit_events
        FOR EACH ROW EXECUTE FUNCTION audit_events_append_only();
      CREATE TRIGGER trg_audit_no_delete
        BEFORE DELETE ON audit_events
        FOR EACH ROW EXECUTE FUNCTION audit_events_append_only();
    SQL
  end
end
