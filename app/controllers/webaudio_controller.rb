class WebaudioController < ApplicationController
  def recorder
    params.permit(:syncFreq,:fftSize)
    
    @syncFreq = params["syncFreq"].to_i unless params["syncFreq"].nil?
    @syncFreq ||= 18000

    @fftSize = params["fftSize"].to_i unless params["fftSize"].nil?
    @fftSize ||= 256
  end
end
