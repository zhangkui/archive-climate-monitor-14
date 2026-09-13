class IngestController < ApplicationController
  # POST /api/ingest
  # { "sensor_code": "S-T01", "readings": [
  #     {"observed_at":"...","temp_c":22.1,"humi_pct":55.2,"battery_pct":88} ] }
  def create
    result = Risk::IngestService.ingest!(ingest_params.to_unsafe_h.deep_symbolize_keys)
    render json: {
      accepted: result.accepted, rejected: result.rejected, errors: result.errors
    }, status: :created
  end

  # POST /api/device-events
  # { "sensor_code":"S-T01","event_kind":"offline","occurred_at":"...","note":"..." }
  def device_event
    sensor = Sensor.find_by!(code: params.require(:sensor_code))
    event = DeviceEvent.create!(
      sensor: sensor,
      event_kind: params.require(:event_kind),
      occurred_at: params[:occurred_at] ? Time.iso8601(params[:occurred_at]) : Time.current,
      payload: params[:payload]&.to_unsafe_h || {},
      note: params[:note]
    )

    if %w[offline fault].include?(event.event_kind)
      sensor.update!(status: "offline")
    elsif event.event_kind == "online"
      sensor.update!(status: "active")
    end

    Risk.audit!(category: "system", action: "device_event:#{event.event_kind}",
                auditable: sensor, after_data: event.payload,
                note: event.note)

    head :created
  end

  private

  def ingest_params
    params.permit(:sensor_code, readings: [
      :observed_at, :temp_c, :humi_pct, :dew_point_c, :battery_pct
    ])
  end
end
