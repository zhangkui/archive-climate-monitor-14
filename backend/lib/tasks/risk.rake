namespace :risk do
  desc "执行一轮全库风险扫描"
  task sweep: :environment do
    result = Risk::Sweep.run!
    puts JSON.pretty_generate(result.to_h)
  end

  desc "持续生成模拟测点（演示用）：INTERVAL 秒一轮，Ctrl-C 停止"
  task simulate: :environment do
    interval = ENV.fetch("INTERVAL", 60).to_i
    generator = Demo::Simulator.new
    trap("INT") { exit 0 }
    loop do
      n = generator.tick!
      puts "#{Time.current.iso8601} ingested=#{n}"
      sleep interval
    end
  end

  desc "立即触发一轮风险扫描（绕过调度）"
  task scan_once: :environment do
    RiskSweepJob.perform_async
    puts "enqueued RiskSweepJob"
  end
end
