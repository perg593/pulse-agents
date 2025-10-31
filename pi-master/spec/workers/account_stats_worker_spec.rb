# frozen_string_literal: true
require 'spec_helper'
# TODO: Debug an InfluxDB's authentication issue on CI https://gitlab.ekohe.com/ekohe/pulseinsights/pi/-/jobs/221682
=begin
describe AccountStatsWorker do
  it 'fills the account_stats table using data from InfluxDB' do
    account = create(:account)
    account_stat = account.account_stat
    expect(account_stat.calls_count).to eq 0

    influx_client = InfluxDBClient.new
    points = [{ series: 'pi', tags: { account_id: account.identifier, endpoint: 'serve' }, values: { count: 10 } }]
    influx_client.influxdb.write_points points

    described_class.new.perform
    expect(account_stat.reload.calls_count).to eq 10
  end
end
=end
