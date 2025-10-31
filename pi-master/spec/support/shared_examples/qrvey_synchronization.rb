# frozen_string_literal: true

shared_examples "Qrvey Synchronization callbacks" do
  def trigger_record
    NotImplementedError 'Please implement "trigger_record" method that returns a metadata record to destroy to trigger the hooks'
  end

  describe '#destroy_also_on_qrvey' do
    it 'enqueues a FullDeleteWorker job after the trigger record gets destroyed' do
      trigger_record.destroy
      expect(Qrvey::FullDeleteWorker).to have_enqueued_sidekiq_job(trigger_record.class.to_s, trigger_record.id)
    end
  end
end
