class CommentsChannel < ApplicationCable::Channel
  def follow(data)
    stop_all_streams
    stream_from "movies:#{data['movie_id'].to_i}:comments"
  end

  def unfollow
    stop_all_streams
  end
end
