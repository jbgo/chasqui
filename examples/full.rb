# file: admin/config/initializers/chasqui.rb
Chasqui.configure do |config|
  config.channel = 'com.example.admin'
  config.redis = ENV.fetch('REDIS_URL')
end

# file: admin/app/controllers/video_controller.rb
class VideosController < ApplicationController

  def upload
    video = Video.find params[:id]

    if video.upload params[:file]
      Chasqui.publish 'video.upload', video.id
      redirect_to upload_complete_url,
    else
      redirect_to video_url, alert: "Upload failed."
    end
  end

end

# file: transcoder/config/initializers/chasqui.rb
Chasqui.configure do |config|
  config.publish 'com.example.transcoder'
  config.redis ENV.fetch('REDIS_URL')
  config.workers :sidekiq # or :resque
end

# file: transcoder/app/subscribers/video_subscriber.rb
Chasqui.subscribe queue: 'transcoder.video', channel: 'com.example.admin' do
  on 'video.upload' do |video_id|
    begin
      Transcorder.transcode video_url(video_id)
      Chasqui.publish 'video.complete', video_id
    rescue => ex
      Chasqui.publish 'video.error', video_id, ex.message
      raise
    end
  end
end

# file: admin/app/subscribers/video_subscriber.rb
Chasqui.subscribe queue: 'admin.events', channel: 'com.example.transcoder' do

  on 'transcoder.video.complete' do |video_id|
    video = Video.find video_id
    VideoMailer.transcode_complete(video).deliver
  end

  on 'transcoder.video.error' do |video_id, error|
    video = Video.find video_id
    VideoMailer.transcode_error(video, error).deliver
  end

end
