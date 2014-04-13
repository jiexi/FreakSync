var FreakSync,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

FreakSync = (function() {
  function FreakSync(fftSize, syncFreq, heartBeat, resolution, heartBeatMult) {
    var d, hzPerDivision, validFFTsizes, _ref;
    this.fftSize = fftSize != null ? fftSize : 256;
    this.syncFreq = syncFreq != null ? syncFreq : 16000;
    this.heartBeat = heartBeat != null ? heartBeat : 250;
    this.resolution = resolution != null ? resolution : 5;
    this.heartBeatMult = heartBeatMult != null ? heartBeatMult : 2;
    this.clockTimer = __bind(this.clockTimer, this);
    this.clockSync = __bind(this.clockSync, this);
    this.sync = __bind(this.sync, this);
    this.stopFreq = __bind(this.stopFreq, this);
    this.playFreq = __bind(this.playFreq, this);
    this.freqAnalyzer = __bind(this.freqAnalyzer, this);
    this.gotStream = __bind(this.gotStream, this);
    this.reset = __bind(this.reset, this);
    d = new Date();
    this.lastFired = d.getTime();
    this.startTimer = d.getTime();
    this.clear = 0;
    this.tick_count = 0;
    this.sync_count = 0;
    this.playedEntrance = false;

    /*
    @movingAverage = 0
    @alpha = 0.20
    @spike = 0.30
     */
    this.ignoreonce = true;
    this.freqPrev = 0;
    this.freqThreshold = 80;
    this.sampleRate = 44100;
    validFFTsizes = [2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048];
    if ($.inArray(this.fftSize, validFFTsizes) === -1) {
      console.log("Invalid FFT size: " + this.fftSize);
      throw new Error("Invalid FFT size. Expected a nonzero power of 2.");
    }
    if (!((20 < (_ref = this.syncFreq) && _ref < 22000))) {
      console.log("Invalid sync frequency: " + this.syncFreq);
      throw new Error("Invalid sync frequency. Expected between 20 and 22000.");
    }
    if (!(this.heartBeat >= 100)) {
      console.log("Invalid heart beat: " + this.heartBeat);
      throw new Error("Invalid heart beat. Expected above 100 ms.");
    }
    if (!(this.resolution >= 5)) {
      console.log("Invalid resolution: " + this.resolution);
      throw new Error("Invalid resolution. Expected above 5 ms.");
    }
    if (!(this.heartBeatMult >= 1)) {
      console.log("Invalid heartbeat multiplier: " + this.heartBeatMult);
      throw new Error("Invalid heartbeat multiplier. Expected at least 1.");
    }
    hzPerDivision = this.sampleRate / this.fftSize;
    this.freqElement = Math.floor(this.syncFreq / hzPerDivision);
    window.AudioContext = window.AudioContext || window.webkitAudioContext || window.mozAudioContext;
    navigator.getUserMedia = navigator.getUserMedia || navigator.webkitGetUserMedia || navigator.mozGetUserMedia;
    this.audioContext = new AudioContext();
    this.oscillator = this.audioContext.createOscillator();
    navigator.getUserMedia({
      audio: true
    }, this.gotStream, function(e) {
      alert('Error attaching to microphone!');
      console.log(e);
      throw new Error("Failed to attach to microphone!");
    });

  FreakSync.prototype.reset = function() {
    clearTimeout(this.clocktimerrepeat);
    clearTimeout(this.clocksyncrepeat);
    clearTimeout(this.syncrepeat);
    this.clear = 0;
    this.sync_count = 0;
    this.tick_count = 0;
    return this.init_sync = false;
  };

  FreakSync.prototype.gotStream = function(stream) {
    this.inputPoint = this.audioContext.createGain();
    this.audioInput = this.audioContext.createMediaStreamSource(stream);
    this.audioInput.connect(this.inputPoint);
    this.analyserNode = this.audioContext.createAnalyser();
    this.analyserNode.fftSize = this.fftSize;
    this.inputPoint.connect(this.analyserNode);
  };

  FreakSync.prototype.freqAnalyzer = function() {
    var change, freqByteData, freqReceived, max;
    freqByteData = new Uint8Array(this.analyserNode.frequencyBinCount);
    this.analyserNode.getByteFrequencyData(freqByteData);
    freqReceived = freqByteData[this.freqElement];

    change = Math.abs(freqReceived - this.freqPrev);
    if (freqReceived > this.freqPrev) {
      max = freqReceived;
    } else {
      max = this.freqPrev;
    }
    if (freqReceived > this.freqPrev && freqReceived >= this.freqThreshold && change / max > 0.01) {
      this.increasing += 1;
    } else {
      this.increasing = 0;
    }

    this.freqPrev = freqReceived;
    if (this.increasing === 1) {
      return 1;
    } else {
      return 0;
    }
  };

  FreakSync.prototype.playFreq = function() {
    var e;
    this.ignoreonce = true;
    this.oscillator.type = 1;
    this.oscillator.frequency.value = this.syncFreq;
    this.oscillator.connect(this.audioContext.destination);
    try {
      if (this.oscillator.noteOn) {
        this.oscillator.noteOn(0);
      }
    } catch (_error) {
      e = _error;
      console.log(e);
    }
    return setTimeout(this.stopFreq, 50);
  };

  FreakSync.prototype.stopFreq = function() {
    return this.oscillator.disconnect();
  };

  FreakSync.prototype.sync = function(callback) {
    var d, high, new_timer;
    if (callback == null) {
      callback = null;
    }
    if (callback !== null) {
      this.callback = callback;
    }
    d = new Date();
    new_timer = d.getTime();
    if ((new_timer - this.lastFired) >= this.heartBeat) {
      this.clear += 1;
      if (this.clear % 2 === 0) {
        this.playFreq();
      }
      this.lastFired = new_timer;
      this.syncrepeat = setTimeout(this.sync, 25);
      return;
    }
    high = this.freqAnalyzer();
    if (this.ignoreonce && high === 1) {
      this.ignoreonce = false;
    } else if (high === 1) {
      this.lastFired -= this.resolution;
      this.clear = 0;
      if ((new_timer - this.lastFired) >= this.heartBeat) {
        this.playFreq();
        this.lastFired = new_timer;
        this.syncrepeat = setTimeout(this.sync, 25);
        return;
      }
    }
    if (this.clear >= 9) {
      this.clear = 0;
      this.freqPrev = 0;
      this.clocksyncrepeat = setTimeout(this.clockSync, this.heartBeat / 10);
      return;
    }
    return this.syncrepeat = setTimeout(this.sync, 25);
  };

  FreakSync.prototype.clockSync = function() {
    var d, high, onheartbeat;
    high = this.freqAnalyzer();
    if (high === 1 && this.clear !== 0) {
      this.clear = 0;
      this.tick_count = 1;
      this.clocksyncrepeat = setTimeout(this.clockSync, this.heartBeat / 10);
      return;
    }
    onheartbeat = this.tick_count % 10 === 0;
    if (onheartbeat) {
      this.clear += 1;
      if (this.clear >= 9) {
        if (!this.playedEntrance) {
          this.playedEntrance = true;
          this.playFreq();
        }
        if (this.clear >= 19) {
          this.tick_count = 0;
          d = new Date();
          this.startTimer = d.getTime();
          this.clocktimerrepeat = setTimeout(this.clockTimer, this.heartBeat * this.heartBeatMult);
          return;
        }
      }
    } else {
    }
    this.tick_count += 1;
    return this.clocksyncrepeat = setTimeout(this.clockSync, this.heartBeat / 10);
  };

  FreakSync.prototype.clockTimer = function() {
    var currentBeat, d, new_timer;
    this.callback(this.tick_count);
    d = new Date();
    new_timer = d.getTime();
    currentBeat = (new_timer - this.startTimer) % (this.heartBeat * this.heartBeatMult);
    this.tick_count = Math.floor((new_timer - this.startTimer) / (this.heartBeat * this.heartBeatMult));
    return this.clocktimerrepeat = setTimeout(this.clockTimer, this.heartBeat * this.heartBeatMult - this.currentBeat);
  };

  return FreakSync;

})();
