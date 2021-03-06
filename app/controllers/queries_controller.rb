require 'bunny'
class QueriesController < ApplicationController
  include QueriesHelper
  before_action :authenticate_user!

  def show
    @query = Query.find_by_id(params[:id])
    if @query.blank?
      redirect_to queries_path, alert: "Query non trovata"
    end
    map_movies(@query)
    last_queries
  end

  def new
    @query = Query.new
    last_movie
  end

  def create
    @query = Query.new(query_params)
    query_in_db = Query.where("lower(query) = ?", @query.query.downcase).first
    if !query_in_db.blank?
      redirect_to query_in_db, notice: 'Query già presente'
    else
      # Make query to api => set of movie
      @query = search_query(@query)
      @query.query.downcase!
      if !@query.movies.blank? && !@query.errors.any? && @query.save
        conn = Bunny.new ENV['CLOUDAMQP_URL']
        conn.start
        ch = conn.create_channel
        x = ch.fanout("movies_update")
        x.publish("#{current_user.id}")
        ch.close
        conn.close
        redirect_to @query, notice: 'Una nuova query è stata aggiunta al database'
      else
        last_movie
        flash.now[:alert] = "Nessun film trovato con questo titolo"
        render :new
      end
    end
  end

  private

  def query_params
    params.require(:query).permit(:query)
  end

  def map_movies(query)
      @movie_ids = query.movies[1, query.movies.length-2]
      @movie_ids = @movie_ids.split(", ")
      @movie_ids = @movie_ids.map{|m| m.to_i}
      @movies = Movie.where("api_id IN (?)", @movie_ids)
  end

  def last_movie
    @movies = Movie.last(30).reverse
    last_queries
  end

  def last_queries
    @queries = Query.last(50).reverse
  end

end
