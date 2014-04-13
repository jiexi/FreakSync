class FreakSync
  #all arguments have expected ranges!
  constructor: (@fftSize = 256, @syncFreq = 16000, @heartBeat = 250, @resolution = 5, @heartBeatMult = 2) ->

    #setting up last fired timer
    d = new Date()
    @lastFired = d.getTime()
    @startTimer = d.getTime()
    @clear = 0
    @tick_count = 0
    @sync_count = 0

    @playedEntrance = false
    #setting up averaging
    ###
    @movingAverage = 0
    @alpha = 0.20
    @spike = 0.30
    ###
    @ignoreonce = true

    @freqPrev = 0

    @freqThreshold = 50 #typical spike is 100, consider it a spike if it goes past this

    #assuming samplerate of 44100
    @sampleRate = 44100

    #valid fft sizes must be a nonzero power of 2 <= 2048
    validFFTsizes = [2,4,8,16,32,64,128,256,512,1024,2048]

    if $.inArray(@fftSize, validFFTsizes) == -1
      console.log("Invalid FFT size: " + @fftSize)
      throw new Error("Invalid FFT size. Expected a nonzero power of 2.")

    #valid frequencies are from 20 to 22000 hz (just a guess)
    unless 20 < @syncFreq < 22000
      console.log("Invalid sync frequency: " + @syncFreq)
      throw new Error("Invalid sync frequency. Expected between 20 and 22000.")

    #valid heartBeat in ms >= 100ms
    unless @heartBeat >= 100
      console.log("Invalid heart beat: " + @heartBeat)
      throw new Error("Invalid heart beat. Expected above 100 ms.")

    #valid resolution in ms >= 5ms
    unless @resolution >= 5
      console.log("Invalid resolution: " + @resolution)
      throw new Error("Invalid resolution. Expected above 5 ms.")

    #valid resolution in ms >= 5ms
    unless @heartBeatMult >= 1
      console.log("Invalid heartbeat multiplier: " + @heartBeatMult)
      throw new Error("Invalid heartbeat multiplier. Expected at least 1.")


    #calculate target freqByteData element to monitor for spikes
    hzPerDivision = @sampleRate/@fftSize
    @freqElement = Math.floor(@syncFreq/hzPerDivision)

    #adjust for nonstandardized web audio 
    window.AudioContext = window.AudioContext || window.webkitAudioContext || window.mozAudioContext
    navigator.getUserMedia = navigator.getUserMedia || navigator.webkitGetUserMedia || navigator.mozGetUserMedia

    #create our context and generator
    @audioContext = new AudioContext()
    @oscillator = @audioContext.createOscillator()

    #ask user for microphone privledges
    navigator.getUserMedia {audio:true}, @gotStream, 
      (e) -> 
        alert 'Error attaching to microphone!'
        console.log(e)
        throw new Error("Failed to attach to microphone!")
    ###
    $("#btnSync").click ()=>
      @beat = false;
      @sync ()-> 
        increment = => 
          if @beat
            $('body').css('background-color', 'red');
            @beat = false
          else
            $('body').css('background-color', 'white');
            @beat = true
        @endrepeat = setInterval(increment,@heartBeat)
    ###

    $("#btnSync").click ()=>
      @sync (time)->
        if time % 10 == 0
          $("#center").text(time)
          $('body').css('background-color', '#ED733E')
        else
          $("#center").text(time)
          $('body').css('background-color', '#EDB63E')

    $("#btnReset").click ()=>
      $("#center").text("Press Spacebar")
      $('body').css('background-color', '#bdc3c7')
      @reset()

    $('body').keyup (e)=>
       if e.keyCode == 40
          #user has pressed enter
          $("#btnReset").click()

       if e.keyCode == 32
          #user has pressed space
          $("#btnSync").click()
       


  #reset syncing
  reset: () =>
    clearTimeout(@clocktimerrepeat)
    clearTimeout(@clocksyncrepeat)
    clearTimeout(@syncrepeat)
    @clear = 0
    @sync_count = 0
    @tick_count = 0
    @init_sync = false      

  #create an analyser after successfully attaching to microphone.
  gotStream: (stream) =>

    @inputPoint = @audioContext.createGain()

    #create audio node 
    @audioInput = @audioContext.createMediaStreamSource stream
    @audioInput.connect @inputPoint

    @analyserNode = @audioContext.createAnalyser()
    @analyserNode.fftSize = @fftSize
    @inputPoint.connect @analyserNode
    return


  #returns true if spike detected or false if none
  freqAnalyzer: =>
    freqByteData = new Uint8Array(@analyserNode.frequencyBinCount)
    @analyserNode.getByteFrequencyData freqByteData

    freqReceived = freqByteData[@freqElement]
    ###
    freqReceived = 0

    for i in [@freqElement-7..@freqElement+7]
      if freqByteData[i] > @freqThreshold
        freqReceived = freqByteData[i]
        break
    ###

    $("#center").text(freqReceived + "dB")

    change = Math.abs((freqReceived - @freqPrev))
    if freqReceived > @freqPrev
      max = freqReceived
    else
      max = @freqPrev

    if freqReceived > @freqPrev && freqReceived >= @freqThreshold && change/max > 0.01
      @increasing += 1
    else
      @increasing = 0
    ### 
    console.log(freqReceived)

    console.log(@increasing)
    ###
    @freqPrev = freqReceived

    if @increasing == 1
      return 1
    else
      return 0

  #signal for resolution time
  playFreq: =>
    @ignoreonce = true
    @oscillator.type = 1
    @oscillator.frequency.value = @syncFreq;
    @oscillator.connect @audioContext.destination
    
    try
     @oscillator.noteOn(0) if @oscillator.noteOn #call noteOn() if method exists
    catch e
      console.log e
      
    $("freqDisplay").val(@syncFreq + "Hz")

    setTimeout @stopFreq, 50


  #stop playing signal
  stopFreq: =>
    @oscillator.disconnect()

  #start a sync, and callback method when sync is complete
  sync: (callback = null) =>
    @callback = callback if callback != null

    #get current time and see if we are past our heartBeat
    d = new Date()
    new_timer = d.getTime()

    #it's time to signal out and ignore all other signals for this time
    if (new_timer - @lastFired) >= @heartBeat
      $("#status").text("Timer expired, signalling out!")
      @clear += 1
      if @clear % 2 == 0
        @playFreq()
      $("#count").text(@clear)
      @lastFired = new_timer
      @syncrepeat = setTimeout @sync, 25
      return

    
    #it's time to sample the mic for any spikes
    high = @freqAnalyzer()

    if @ignoreonce && high == 1
      @ignoreonce = false
      $("#status").text("Ignoring this signal (ours).")
    else if high == 1
      $("#status").text("Got signal, increment timer!")

      @lastFired -= @resolution #* high  
      @clear = 0
      #check if we signal now
      if (new_timer - @lastFired) >= @heartBeat
        $("#status").text("Pushed past timer limit, signalling out!")
        @playFreq()
        @lastFired = new_timer
        @syncrepeat = setTimeout @sync, 25
        return
      

    if @clear >= 9
      $("#status").text("Heartbeat synced. Starting clock sync!")
      @clear = 0
      @freqPrev = 0
      @clocksyncrepeat = setTimeout @clockSync, @heartBeat / 10
      return


    @syncrepeat = setTimeout @sync, 25

  #complete syncing of clocks #TODO Need to document this...
  clockSync: ()=>
    high = @freqAnalyzer()
    if high == 1 && @clear != 0
      $("#status").text("Got signal, restarting loop!")
      @clear = 0
      @tick_count = 1
      @clocksyncrepeat = setTimeout @clockSync, @heartBeat / 10
      return

    onheartbeat = @tick_count % 10 == 0

    if onheartbeat
      @clear += 1
      $("#count").text(@clear)
      $("#center").html("Syncing..")
      if @clear >= 9
        unless @playedEntrance
          $("#status").text("Announcing ourselves once, signalling out!")
          @playedEntrance = true
          @playFreq()
        if @clear >= 15
          $("#status").text("Clock is synced! HeartBeat counter shown above :)")
          @tick_count = 0
          d = new Date()
          @startTimer = d.getTime()          
          @clocktimerrepeat = setTimeout @clockTimer, @heartBeat * @heartBeatMult
          return
    else
      $("#center").html("Syncing...")

    @tick_count += 1
    @clocksyncrepeat = setTimeout @clockSync, @heartBeat / 10


  #starts counting heartbeats and gives callback current tick count
  clockTimer: ()=>
    @callback @tick_count
    d = new Date()
    new_timer = d.getTime()       
    
    currentBeat = (new_timer - @startTimer) % (@heartBeat * @heartBeatMult)
    @tick_count = Math.floor((new_timer - @startTimer) / (@heartBeat * @heartBeatMult))
    @clocktimerrepeat = setTimeout @clockTimer, @heartBeat * @heartBeatMult - @currentBeat

$ ->
  #need to do it like this because Rails does not allow passing directly to coffee script

  fftSize = parseInt $('#fftSize').val()
  syncFreq = parseInt $('#syncFreq').val()
  freaksync = new FreakSync(fftSize,syncFreq)
