class SensorsController < ApplicationController
  # GET /api/sensors
  def index
    sensors = Sensor.includes(:sensor_assignments).order(:code)
    zones = Zone.where(id: sensors.map { |s| s.sensor_assignments.max_by(&:valid_from)&.zone_id }.compact)
                .index_by(&:id)
    render json: sensors.map { |s|
      current_asn = s.sensor_assignments
        .select { |a| a.valid_to.nil? }
        .max_by(&:valid_from)
      Serializers.sensor(s, zone: current_asn && zones[current_asn.zone_id])
    }
  end

  # POST /api/sensors
  def create
    sensor = Sensor.create!(sensor_params)
    if params[:zone_id]
      SensorAssignment.create!(
        sensor: sensor, zone_id: params.require(:zone_id),
        location_desc: params[:location_desc], valid_from: Time.current
      )
    end
    Risk.audit!(category: "device_replacement", action: "create",
                actor_name: actor_name, auditable: sensor,
                after_data: sensor.attributes, note: "设备建档")
    render json: Serializers.sensor(sensor.reload), status: :created
  end

  # PATCH /api/sensors/:id —— 改名/固件/状态
  def update
    sensor = Sensor.find(params[:id])
    before = sensor.attributes.slice("name", "status", "firmware_version")
    sensor.update!(sensor_params)
    Risk.audit!(category: "device_replacement", action: "update",
                actor_name: actor_name, auditable: sensor,
                before_data: before, after_data: sensor.attributes.slice(*before.keys))
    render json: Serializers.sensor(sensor)
  end

  # POST /api/sensors/:id/replace
  # body: { code:"S-T11", name:"...", manufacturer:"...", model:"...",
  #         sensor_type:"combi", zone_id: 3, note:"校准漂移超标替换" }
  def replace
    old = Sensor.find(params[:id])
    attrs = params.permit(:code, :name, :sensor_type, :manufacturer,
                          :model, :firmware_version).to_h.symbolize_keys
    %i[code name sensor_type].each do |k|
      raise ArgumentError, "缺少必填字段 #{k}" if attrs[k].blank?
    end

    zone = params[:zone_id] ? Zone.find(params[:zone_id]) : nil
    new_sensor = Risk::DeviceService.replace!(
      old_sensor: old, new_attributes: attrs, zone: zone,
      actor_name: actor_name, note: params[:note].to_s
    )
    render json: Serializers.sensor(new_sensor.reload), status: :created
  end

  private

  def sensor_params
    params.permit(:code, :name, :sensor_type, :manufacturer, :model,
                  :firmware_version, :status, :commissioned_on)
  end
end
