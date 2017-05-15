(
// MIDI/SynthDef setup
MIDIClient.init;
m = MIDIOut(0);
m.latency_(0.157);
Server.local.options.numOutputBusChannels = 2;

// SYNTHS

SynthDef(\zero, {
  Out.ar(0, Silent.ar() * Line.ar(1, 1, 0.00001, doneAction: 2));
}).add;

~hat_808 = Buffer.readChannel(s, thisProcess.nowExecutingPath.dirname++"/Sounds/808hat.wav", channels: [0]);
SynthDef(\hat_808, {
  arg vol=0.4;
  var sig;
  sig = Pan2.ar(PlayBuf.ar(1, ~hat_808.bufnum, doneAction: 2));
  Out.ar(0, sig * vol);
}).add;

SynthDef(\kick_folder_player, {
  arg dur = 1, staccato_factor = 1.0, buf= ~hat_808.bufnum, volume = 1, hpf_freq=20000, lpf_freq=40, tempoclock=TempoClock.new;
  var sig, env, hpf, lpf;
  sig = Pan2.ar(PlayBuf.ar(1, buf));
  sig = Compander.ar(sig, sig, 0.3);
  sig = BPeakEQ.ar(sig, [30, 90], 1, 3.4);
  env = EnvGen.kr(Env([1, 1, 0], [dur * staccato_factor, 0.05]), doneAction: 2);
  sig = sig * env;
  sig = HPF.ar(sig, hpf_freq, 1, 0);
  sig = LPF.ar(sig, lpf_freq, 1, 0);
  Out.ar(0, (sig * 0.53) * volume);
}).add;

SynthDef(\snare_folder_player, {
  arg buf= ~hat_808.bufnum, volume = 1;
  var sig;
  sig = Pan2.ar(PlayBuf.ar(1, buf, doneAction: 2));
  sig = Compander.ar(sig, sig, 0.3);
  sig = BPeakEQ.ar(sig, [30, 90], 1, 3.4);
  Out.ar(0, (sig * 0.53) * volume);
}).add;

SynthDef(\perc_folder_player, {
  arg buf= ~hat_808.bufnum, volume = 1;
  var sig;
  sig = Pan2.ar(PlayBuf.ar(1, buf, doneAction: 2), pos: Rand(-0.4, 0.4));
  sig = Compander.ar(sig, sig, 0.2);
  sig = BPeakEQ.ar(sig, [30, 90], 1, 3.4);
  Out.ar(0, (sig * 0.53) * volume);
}).add;

SynthDef(\anchor_folder_player, {
  arg buf= ~hat_808.bufnum, volume = 1;
  var sig;
  sig = PlayBuf.ar(1, buf, doneAction: 2);
  sig = Compander.ar(sig, sig, 0.2);
  sig = BPeakEQ.ar(sig, [30, 90], 1, 3.4);
  Out.ar(0, (sig * 0.38) * volume);
}).add;

// VARIABLES
~possible_durations = [0.200, 0.400, 0.100, 0.500, 0.300, 0.150, 0.050, 0.025];
~selected_durations = [0.2, 0.1];
~possible_notes = [72, 71, 70, 69, 68, 67, 66, 65, 64, 63, 62, 61, 60, 59, 58, 57, 56, 55, 54, 53, 52, 51, 50, 49, 48, 47, 46, 45, 44, 43, 42];
~notes = [60];
~loop_length_cutoff = 1.6;
~kick_synth = PatternProxy(\kick_folder_player);
~snare_synth = PatternProxy(\snare_folder_player);
~perc_synth = PatternProxy(\perc_folder_player);
~anchor_synth = PatternProxy(\anchor_folder_player);
~kick_volume = PatternProxy(Pseq([1], inf));
~snare_volume = PatternProxy(Pseq([1], inf));
~perc_volume = PatternProxy(Pseq([0], inf));
~anchor_volume = PatternProxy(Pseq([0], inf));
~drum_pattern = PatternProxy(Pxrand([0], inf));
~snare_buf_pattern = PatternProxy(Pxrand([0], inf));
~kick_staccato_pattern = PatternProxy(Pxrand([1], inf));
~kick_hpf_pattern = PatternProxy(Pseq([40], inf));
~kick_lpf_pattern = PatternProxy(Pseq([20000], inf));
~anchor_buf = PatternProxy(Prand([0], inf));
~perc_pattern = PatternProxy(Pxrand([0], inf));
~perc_durations = PatternProxy(Prand([0.1, 0.2], inf));
~anchor_pattern = PatternProxy(Pseq([0.4], inf));
~anchor_durations = [0.8, 0.4, 0.2, 0.1];
~synth_legato = PatternProxy(Pseq([1], inf));
~chord_mode = false;
~rhythm_display = nil;
~midi_type.source = Pseq([\midi], inf);

// TEMPOCLOCK
t = TempoClock(60/60);

~change_rhythm = {
  ~rhythmMaker.value;
  ~pattern.source = Pseq(~rhythm, inf);
   w.name_(~rhythm.asString);
  ~snare_pattern.source = Pseq([~rhythm[0], ~rhythm[1..(~rhythm.size-1)].collect { |c| Rest(c); }].flatten, inf);
};

// MAIN WINDOW
w = Window.new("DERIVATIVE WORKS", Rect(0, 0, 1080, 580)).background_(Color.rand).front;
Button(w, Rect(0, 0, 20, 20)).states_([["r", Color.white, Color.red]]).action_({ s.record; }).font_(Font("Monaco", 14));
Button(w, Rect(20, 20, 80, 30)).states_([["start", Color.white, Color.red]]).action_({ ~midipattern.play(t); ~clappattern.play(t); ~kickpattern.play(t); ~percpattern.play(t); ~anchorpattern.play(t); }).font_(Font("Monaco", 14));
Button(w, Rect(120, 20, 80, 30)).states_([["stop", Color.white, Color.red]]).action_({ ~midipattern.pause(t); ~clappattern.pause(t); ~kickpattern.pause(t); ~hatpattern.pause(t); ~percpattern.pause(t); ~anchorpattern.pause(t); }).font_(Font("Monaco", 14));
Button(w, Rect(20, 70, 300, 30)).font_(Font("Monaco", 14)).states_([["CHANGE", Color.white, Color.rand]]).action_({
  ~change_rhythm.value;
});

// SOUND SELECTA
~find_folders = {
  arg path;
  PathName.new(path).pathMatch.collect({ arg item, i; PathName.new(item).folderName.asString; });
};

~readBuffersFromFolder = { |path|
  PathName.new(path).files.collect { |file| Buffer.readChannel(s, file.fullPath, channels: [0]) }.collect { |buffer| buffer.bufnum };
};

~kick_folders = ~find_folders.value(thisProcess.nowExecutingPath.dirname++"/Sounds/KICKS/*");
~snare_folders = ~find_folders.value(thisProcess.nowExecutingPath.dirname++"/Sounds/SNARES/*");
~perc_folders = ~find_folders.value(thisProcess.nowExecutingPath.dirname++"/Sounds/PERC/*");
~anchor_folders = ~find_folders.value(thisProcess.nowExecutingPath.dirname++"/Sounds/ANCHORS/*");

Button(w, Rect(420, 0, 60, 25)).states_([["xrand", Color.white, Color.rand]]).action_({
 ~drum_pattern.source = Pxrand(~drum_buffers, inf);
}).font_(Font("Monaco", 12));

Button(w, Rect(480, 0, 60, 25)).states_([["seq", Color.white, Color.rand]]).action_({
 ~drum_pattern.source = Pseq(~drum_buffers, inf);
}).font_(Font("Monaco", 12));

// DRUM CHANGERS
StaticText(w, Rect(420, 20, 120, 30)).string_("kick").font_(Font("Monaco", 14, true)).stringColor_(Color.white).align_(\center);
~kicks_selector = ListView(w, Rect(420, 50, 120, 220)).items_(~kick_folders).background_(Color.green).font_(Font("Monaco", 14)).selection_(nil).selectionAction_({
  ~selected_drum_folder = ~kick_folders[~kicks_selector.selection.value][0];
  ~drum_buffers = ~readBuffersFromFolder.value(thisProcess.nowExecutingPath.dirname++"/Sounds/KICKS/"++~selected_drum_folder);
  ~drum_pattern.source = Pxrand(~drum_buffers, inf);
  ~kick_synth.source = \kick_folder_player;
});
~kicks_selector.value_(0);

Button(w, Rect(420, 280, 120, 25)).states_([["kick on", Color.white, Color.rand]]).action_({
 ~kick_synth.source = \kick_folder_player; ~kickpattern.play(t, quant: Quant(1));
}).font_(Font("Monaco", 12));

Button(w, Rect(420, 315, 120, 25)).states_([["kick off", Color.white, Color.rand]]).action_({
  ~kickpattern.stop(t);
}).font_(Font("Monaco", 12));


~kick_legato_spec = ControlSpec(0, 1, \linear, 0.01, 1);
~kick_legato_slider = Slider(w, Rect(540, 50, 20, 220)).value_(1).step_(0.01).action_({
  ~kick_legato_slider_value = ~kick_legato_spec.map(~kick_legato_slider.value);
  ~kick_staccato_pattern.source = Pseq([~kick_legato_slider_value], inf);
});

~drum_volume_spec = ControlSpec(0, 1, \lin, 0.01);
~kick_volume_slider = Slider(w, Rect(430, 350, 100, 120)).knobColor_(Color.rand).value_(1).step_(0.001).action_({
  ~kick_volume_slider_value = ~drum_volume_spec.map(~kick_volume_slider.value);
  ~kick_volume.source = Pseq([~kick_volume_slider_value], inf);
});

~kick_hpf_spec = ControlSpec(40, 2000, \lin, 5);
~kick_hpf_slider = Slider(w, Rect(430, 480, 50, 80)).knobColor_(Color.rand).value_(0).step_(0.001).action_({
  ~kick_hpf_slider_value = ~kick_hpf_spec.map(~kick_hpf_slider.value);
  ~kick_hpf_pattern.source = Pseq([~kick_hpf_slider_value], inf);
});
StaticText(w, Rect(430, 560, 50, 20)).string_("hpf").font_(Font("Monaco", 14, true)).stringColor_(Color.white).align_(\center);

~kick_lpf_spec = ControlSpec(40, 20000, \lin, 5);
~kick_lpf_slider = Slider(w, Rect(480, 480, 50, 80)).knobColor_(Color.rand).value_(1).step_(0.001).action_({
  ~kick_lpf_slider_value = ~kick_lpf_spec.map(~kick_lpf_slider.value);
  ~kick_lpf_pattern.source = Pseq([~kick_lpf_slider_value], inf);
});
StaticText(w, Rect(480, 560, 50, 20)).string_("lpf").font_(Font("Monaco", 14, true)).stringColor_(Color.white).align_(\center);

StaticText(w, Rect(560, 20, 120, 30)).string_("snare").font_(Font("Monaco", 14, true)).stringColor_(Color.white).align_(\center);
~snares_selector = ListView(w, Rect(560, 50, 120, 220)).items_(~snare_folders).background_(Color.green).font_(Font("Monaco", 14)).selection_(nil).selectionAction_({
  ~selected_snare_folder = ~snare_folders[~snares_selector.selection.value][0];
  ~snare_buffers = ~readBuffersFromFolder.value(thisProcess.nowExecutingPath.dirname++"/Sounds/SNARES/"++~selected_snare_folder);
  ~snare_buf_pattern.source = Pxrand(~snare_buffers, inf);
  ~snare_synth.source = \snare_folder_player;
});
~snares_selector.value_(0);

Button(w, Rect(560, 280, 120, 25)).states_([["snare on", Color.white, Color.rand]]).action_({
 ~snare_synth.source = \snare_folder_player; ~clappattern.play(t, quant: Quant(1));
}).font_(Font("Monaco", 12));

Button(w, Rect(560, 315, 120, 25)).states_([["snare off", Color.white, Color.rand]]).action_({
  ~clappattern.stop(t);
}).font_(Font("Monaco", 12));

~snare_volume_slider = Slider(w, Rect(570, 350, 100, 120)).knobColor_(Color.rand).value_(1).step_(0.001).action_({
  ~snare_volume_slider_value = ~drum_volume_spec.map(~snare_volume_slider.value);
  ~snare_volume.source = Pseq([~snare_volume_slider_value], inf);
});

StaticText(w, Rect(700, 20, 120, 30)).string_("perc").font_(Font("Monaco", 14, true)).stringColor_(Color.white).align_(\center);
~perc_selector = ListView(w, Rect(700, 50, 120, 220)).items_(~perc_folders).background_(Color.green).font_(Font("Monaco", 14)).selection_(nil).selectionAction_({
  ~selected_perc_folder = ~perc_folders[~perc_selector.selection.value][0];
  ~perc_buffers = ~readBuffersFromFolder.value(thisProcess.nowExecutingPath.dirname++"/Sounds/PERC/"++~selected_perc_folder);
  ~perc_pattern.source = Pxrand(~perc_buffers, inf);
});
~perc_selector.value_(0);

~perc_complexity_spec = ControlSpec(0, 4, \linear, 1);
~perc_complexity_slider = Slider(w, Rect(830, 50, 40, 220)).knobColor_(Color.rand).value_(0.5).step_(0.01).action_({
  ~perc_slider_value = ~perc_complexity_spec.map(~perc_complexity_slider.value);
  ~perc_durs = case
  { ~perc_slider_value.value <= 1.0 } { [0.4, 0.6, 0.8] }
  { ~perc_slider_value.value <= 2.0 } { [0.2, 0.3, 0.4, 0.8] }
  { ~perc_slider_value.value <= 3.0 } { [0.1, 0.2, 0.4] }
  { ~perc_slider_value.value > 3.0 } { [0.1, 0.2] };

  ~perc_durations.source = Prand(~perc_durs, inf);
});

Button(w, Rect(700, 280, 120, 25)).states_([["perc on", Color.white, Color.rand]]).action_({
 ~perc_synth.source = \perc_folder_player; ~percpattern.play(t, quant: Quant(1));
}).font_(Font("Monaco", 12));

Button(w, Rect(700, 315, 120, 25)).states_([["perc off", Color.white, Color.rand]]).action_({
  ~percpattern.stop(t);
}).font_(Font("Monaco", 12));

~perc_volume_slider = Slider(w, Rect(710, 350, 100, 120)).knobColor_(Color.rand).value_(0).step_(0.001).action_({
  ~perc_volume_slider_value = ~drum_volume_spec.map(~perc_volume_slider.value);
  ~perc_volume.source = Pseq([~perc_volume_slider_value], inf);
});

StaticText(w, Rect(880, 20, 120, 30)).string_("anchor").font_(Font("Monaco", 14, true)).stringColor_(Color.white).align_(\center);
~anchor_selector = ListView(w, Rect(880, 50, 120, 220)).items_(~anchor_folders).background_(Color.green).font_(Font("Monaco", 14)).selection_(nil).selectionAction_({
  ~selected_anchor_folder = ~anchor_folders[~anchor_selector.selection.value][0];
  ~anchor_buffers = ~readBuffersFromFolder.value(thisProcess.nowExecutingPath.dirname++"/Sounds/ANCHORS/"++~selected_anchor_folder);
  ~anchor_buf.source = Prand(~anchor_buffers, inf);
});
~anchor_selector.value_(0);

Button(w, Rect(880, 280, 120, 25)).states_([["anchor on", Color.white, Color.rand]]).action_({
 ~anchorpattern.play(t, quant: Quant(1));
}).font_(Font("Monaco", 12));

Button(w, Rect(880, 315, 120, 25)).states_([["anchor off", Color.white, Color.rand]]).action_({
  ~anchorpattern.stop(t);
}).font_(Font("Monaco", 12));

~anchor_volume_slider = Slider(w, Rect(890, 350, 100, 120)).knobColor_(Color.rand).value_(0).step_(0.001).action_({
  ~anchor_volume_slider_value = ~drum_volume_spec.map(~anchor_volume_slider.value);
  ~anchor_volume.source = Pseq([~anchor_volume_slider_value], inf);
});

~anchor_duration_selector = ListView(w, Rect(1010, 50, 50, 160)).items_(~anchor_durations).background_(Color.green).font_(Font("Monaco", 14)).selection_(1).selectionMode_(\single).selectionAction_({
  ~anchor_pattern.source = Pseq(~anchor_durations[~anchor_duration_selector.selection], inf);
});

// TEMPO
~tempo_spec = ControlSpec(10, 100, \linear, 0.01);
StaticText(w, Rect(320, 20, 100, 30)).string_("tempo").font_(Font("Monaco", 14, true)).stringColor_(Color.white).align_(\center);
~tempo_display = StaticText(w, Rect(320, 230, 100, 30)).string_(~tempo_spec.map(0.5)).font_(Font("Monaco", 14, true)).stringColor_(Color.white).align_(\center);
~tempo_slider = Slider(w, Rect(350, 50, 40, 180)).knobColor_(Color.rand).value_(0.5).step_(0.01).action_({
  ~tempo_value = ~tempo_spec.map(~tempo_slider.value);
  ~tempo_display.string_(~tempo_value.asString);
  t.tempo_(~tempo_value/60);
});

~legato_spec = ControlSpec(0.1, 1, \linear, 0.1);
StaticText(w, Rect(330, 260, 80, 30)).string_("legato").font_(Font("Monaco", 14, true)).stringColor_(Color.white).align_(\center);
~legato_slider = Slider(w, Rect(350, 290, 40, 180)).knobColor_(Color.rand).value_(1).step_(0.01).action_({
  ~legato_value = ~legato_spec.map(~legato_slider.value);
  ~synth_legato.source = Pseq([~legato_value], inf);
});

StaticText(w, Rect(20, 110, 120, 30)).string_("loop length").font_(Font("Monaco", 14, true)).stringColor_(Color.white).align_(\center);
StaticText(w, Rect(180, 110, 120, 30)).string_("durations").font_(Font("Monaco", 14, true)).stringColor_(Color.white).align_(\center);
~phraselengthbox = NumberBox(w, Rect(20, 140, 120, 30)).value_(1.6).clipLo_(0.2).step_(0.05).scroll_step_(0.05).align_(\center).font_(Font("Monaco", 16, true)).action_({ arg num; ~loop_length_cutoff = num.value; });

~durations_selector = ListView(w, Rect(180, 140, 120, 160)).items_(~possible_durations).background_(Color.green).font_(Font("Monaco", 14)).selection_([0, 1, 2]).selectionMode_(\multi).selectionAction_({
  if(~durations_selector.selection == [], {
    ~selected_durations = [0.2];
    }, {
      ~selected_durations = [];
      ~durations_selector.selection.do({ |n|
        ~selected_durations = ~selected_durations.add(~possible_durations[n.value]);
      });
  });
});

// CONTROL~
Button(w, Rect(180, 350, 120, 25)).states_([["hats on", Color.white, Color.rand]]).action_({
  ~hatpattern.play(t, quant: Quant(1));
}).font_(Font("Monaco", 12));

Button(w, Rect(180, 380, 120, 25)).states_([["hats off", Color.white, Color.rand]]).action_({
  ~hatpattern.stop(t);
}).font_(Font("Monaco", 12));

StaticText(w, Rect(20, 170, 120, 30)).string_("notes").font_(Font("Monaco", 14, true)).stringColor_(Color.white).align_(\center);
~note_selector = ListView(w, Rect(20, 200, 120, 220)).items_(~possible_notes).background_(Color.green).font_(Font("Monaco", 12)).selection_([0]).selectionMode_(\multi).selectionAction_({
  if(~note_selector.selection == [], {
    ~notes = [60];
    }, {
      ~notes = [];
      ~note_selector.selection.do({ |n|
        ~notes = ~notes.add(~possible_notes[n.value]);
      });
    if(~chord_mode == false, {
      ~midinotes.source = Pseq(~notes, inf);
    }, {
      ~midinotes.source = Pseq([~notes], inf);
    });
  });
});

Button(w, Rect(20, 430, 80, 30)).states_([["ARP", Color.white, Color.rand]]).action_({
  ~midi_type.source = Pseq([\midi], inf);
  ~chord_mode = false; ~midinotes.source = Pseq(~notes, inf);
}).font_(Font("Monaco", 14));

Button(w, Rect(110, 430, 80, 30)).states_([["CHORD", Color.white, Color.rand]]).action_({
  ~midi_type.source = Pseq([\midi], inf);
  ~chord_mode = true; ~midinotes.source = Pseq([~notes], inf);
}).font_(Font("Monaco", 14));

Button(w, Rect(200, 430, 80, 30)).states_([["NONE", Color.white, Color.rand]]).action_({
  ~midi_type.source = Pseq([\zero], inf);
}).font_(Font("Monaco", 14));

~midi_instrument = PatternProxy(Pseq([\zero], inf));
~midi_type = PatternProxy(Pseq([\midi], inf));

StaticText(w, Rect(20, 470, 300, 30)).string_("manual pattern (array)").font_(Font("Monaco", 12, true)).stringColor_(Color.white).align_(\left);

~manual_pattern = TextField(w, Rect(20, 500, 300, 30)).background_(Color.green).font_(Font("Monaco", 12, true));

Button(w, Rect(340, 500, 80, 30)).states_([["engage", Color.white, Color.rand]]).action_({
  ~rhythm = ~manual_pattern.value.interpret;
  ~pattern.source = Pseq(~rhythm, inf);
  w.name_(~rhythm.asString);
  ~snare_pattern.source = Pseq([~rhythm[0], ~rhythm[1..(~rhythm.size-1)].collect { |c| Rest(c); }].flatten, inf);
}).font_(Font("Monaco", 12));

// RHYTHM MAKER

~rhythmMaker = {
  ~rhythm = [];
  ~rhythmCounter = 0;
  while( { ~rhythmCounter < ~loop_length_cutoff }, {
    ~time = ~selected_durations.choose;
    ~rhythmCounter = ~rhythmCounter + ~time;
    ~rhythm = ~rhythm.add(~time);
  });
  ~rhythm_overspill = (~rhythm.inject(0, _+_) - ~loop_length_cutoff).round(0.01);
  if(~rhythm_overspill > 0, { e = ~rhythm[~rhythm.size-1]; ~rhythm.put(~rhythm.size-1, e - ~rhythm_overspill); });
  ~rhythm_display = ~rhythm;
  ~rhythm.postln;
};

~rhythmMaker.value;
~pattern = PatternProxy(Pseq([1.6], inf));
~midinotes = PatternProxy(Pseq([60], inf));
~snare_pattern = PatternProxy(Pseq([~rhythm[0], ~rhythm[1..(~rhythm.size-1)].collect { |c| Rest(c); }].flatten, inf));

// MUSIC PATTERNS

~midipattern = Pdef(\midipatt,
  Pbind(
    \instrument, ~midi_instrument,
    \type, ~midi_type,
    \midicmd, \noteOn,
    \midiout, m,
    \chan, [0, 1],
    \midinote, ~midinotes,
    \legato, ~synth_legato,
    \dur, ~pattern,
    \addAction, 3
  )
).play(t);
~midipattern.stop;

~clappattern = Pdef(\clappatt,
  Pbind(
    \instrument, ~snare_synth,
    \buf, ~snare_buf_pattern,
    \dur, ~snare_pattern,
    \volume, ~snare_volume,
  )
).play(t);
~clappattern.stop;

~kickpattern = Pdef(\kickpatt,
  Pbind(
    \instrument, ~kick_synth,
    \buf, ~drum_pattern,
    \dur, ~pattern,
    \volume, ~kick_volume,
    \staccato_factor, ~kick_staccato_pattern,
    \hpf_freq, ~kick_hpf_pattern,
    \lpf_freq, ~kick_lpf_pattern,
    \tempoclock, t,
  )
).play(t);
~kickpattern.stop;

~percpattern = Pdef(\percpatt,
  Pbind(
    \instrument, ~perc_synth,
    \buf, ~perc_pattern,
    \dur, ~perc_durations,
    \volume, ~perc_volume,
  )
).play(t);
~percpattern.stop;

~hatpattern = Pdef(\traphat,
  Pbind(
    \instrument, \hat_808,
    \dur, Prand([
      Pseq([0.1], 4),
      Pseq([0.05], 8),
      Pseq([0.2, 0.1, 0.2, 0.1], 1),
    ], inf
    ),
    \vol, 0.3
  )
).play(t);
~hatpattern.stop;

~anchorpattern = Pdef(\anchor,
  Pbind(
    \instrument, ~anchor_synth,
    \buf, ~anchor_buf,
    \dur, ~anchor_pattern,
    \volume, ~anchor_volume,
  )
).play(t);
~anchorpattern.stop;
)