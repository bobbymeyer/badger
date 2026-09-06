namespace :badger do
  desc "Plant a small, real library of badges. Idempotent. FONT=name picks the font."
  task seed: :environment do
    Badger::Seeds.plant(**{ font: ENV["FONT"] }.compact)
    puts "#{Badger::Badge.count} badges."
  end

  desc "Whether the type sidecar can run: interpreter and packages"
  task doctor: :environment do
    report = Badger.doctor
    puts report.map { |k, v| "#{k}: #{v.inspect}" }
    abort "missing: #{report['missing'].join(', ')}" unless report["ok"]
  end
end
