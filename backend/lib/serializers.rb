# 纯函数式序列化器，避免引入额外 gem
module Serializers
  module_function

  def material(m)
    return nil unless m
    { id: m.id, code: m.code, name: m.name, description: m.description }
  end

  def zone(z, current_version: nil)
    cv = current_version || z.current_version
    {
      id: z.id, code: z.code, name: z.name, status: z.status,
      area_m2: z.area_m2&.to_f,
      established_at: z.established_at&.iso8601,
      material: material(z.material),
      boundary_version: cv&.version,
      boundary: cv&.boundary,
      created_at: z.created_at&.iso8601
    }
  end

  def zone_version(v)
    { id: v.id, version: v.version, change_type: v.change_type,
      boundary: v.boundary, related_zone_id: v.related_zone_id,
      changed_by: v.changed_by, change_reason: v.change_reason,
      effective_at: v.effective_at.iso8601 }
  end

  def sensor(s, zone: nil)
    z = zone || s.current_zone
    { id: s.id, code: s.code, name: s.name,
      sensor_type: s.sensor_type, manufacturer: s.manufacturer,
      model: s.model, firmware_version: s.firmware_version,
      status: s.status, commissioned_on: s.commissioned_on&.iso8601,
      current_zone: z ? { id: z.id, code: z.code, name: z.name } : nil }
  end

  def rule(r)
    { id: r.id, version: r.version, name: r.name,
      material: material(r.material), is_default: r.is_default,
      thresholds: r.thresholds, detectors: r.detectors,
      status: r.status, change_summary: r.change_summary,
      created_by: r.created_by,
      activated_at: r.activated_at&.iso8601,
      superseded_at: r.superseded_at&.iso8601,
      created_at: r.created_at&.iso8601 }
  end

  def event(e)
    { id: e.id, event_type: e.event_type, severity: e.severity,
      status: e.status,
      zone: { id: e.zone_id, code: e.zone&.code, name: e.zone&.name },
      sensor: e.sensor ? {
        id: e.sensor_id, code: e.sensor.code, name: e.sensor.name
      } : nil,
      risk_rule_id: e.risk_rule_id, risk_rule_version: e.risk_rule_version,
      metric: e.metric, peak_value: e.peak_value&.to_f,
      latest_value: e.latest_value&.to_f,
      latest_seen_at: e.latest_seen_at&.iso8601,
      started_at: e.started_at.iso8601, ended_at: e.ended_at&.iso8601,
      detected_at: e.detected_at.iso8601,
      confirmed_at: e.confirmed_at&.iso8601, confirmed_by: e.confirmed_by,
      resolution: e.resolution, resolution_note: e.resolution_note,
      evidence: e.evidence }
  end

  def audit(a)
    { id: a.id, category: a.category, action: a.action,
      actor_name: a.actor_name,
      auditable_type: a.auditable_type, auditable_id: a.auditable_id,
      before_data: a.before_data, after_data: a.after_data,
      note: a.note, request_id: a.request_id,
      occurred_at: a.occurred_at.iso8601 }
  end

  def report(r)
    { id: r.id, kind: r.kind, status: r.status,
      zone_id: r.zone_id,
      period_from: r.period_from.iso8601, period_to: r.period_to.iso8601,
      object_key: r.object_key, size_bytes: r.size_bytes,
      content_type: r.content_type, created_by: r.created_by,
      error_message: r.error_message,
      generated_at: r.generated_at&.iso8601,
      created_at: r.created_at.iso8601 }
  end
end
